import AVFoundation
import CoreGraphics
import Foundation
import Observation
#if canImport(UIKit)
import UIKit
#endif

/// The primary entry point of ASCamera.
///
/// `Camera` is a `@MainActor`, `@Observable` facade over an internal capture engine. It exposes a
/// small, safe, concurrency-friendly API for previewing and recording video, while keeping all
/// AVFoundation details private. It can be driven from a SwiftUI view, a view model, a coordinator,
/// or any async context — there is no dependency on UI controls.
///
/// ```swift
/// let camera = Camera()
/// // In SwiftUI: CameraPreview(camera: camera)
/// try await camera.start()
/// try await camera.startRecording()
/// let result = try await camera.stopRecording()
/// ```
@MainActor
@Observable
public final class Camera {
    // MARK: - Observable state

    /// The current lifecycle state. Observe directly from SwiftUI.
    public var state: CameraState { stateMachine.state }

    /// The elapsed duration of the in-progress recording. Starts at `.zero` and updates
    /// continuously while recording, then resets to `.zero` when the recording stops (the finished
    /// recording's duration remains available via ``lastRecordingResult`` and
    /// ``recordingFinishedStream()``).
    public private(set) var currentRecordingDuration: Duration = .zero

    /// The most recently completed recording, including auto-stopped recordings.
    public private(set) var lastRecordingResult: RecordingResult?

    /// The configuration currently applied to the camera.
    public private(set) var configuration: CameraConfiguration

    /// The clockwise video rotation angle (degrees) the preview should apply. Bound by
    /// ``CameraPreview``; also exposed for advanced consumers.
    public internal(set) var previewRotationAngle: CGFloat

    // MARK: - Permission state

    /// The current camera authorization status.
    public var cameraPermission: PermissionStatus { authorization.status(for: .video) }

    /// The current microphone authorization status.
    public var microphonePermission: PermissionStatus { authorization.status(for: .audio) }

    // MARK: - Private state

    // NOT @ObservationIgnored: `state` is a computed property derived from `stateMachine`, so the
    // machine must be observed for SwiftUI to react to lifecycle transitions (idle → running → …).
    private var stateMachine = CameraStateMachine()
    @ObservationIgnored private let engine: any CameraEngine
    @ObservationIgnored private let authorization: any AuthorizationProviding
    @ObservationIgnored private var eventTask: Task<Void, Never>?
    @ObservationIgnored private var pendingStop: CheckedContinuation<RecordingResult, any Error>?
    @ObservationIgnored private var durationContinuations: [UUID: AsyncStream<Duration>.Continuation] = [:]
    @ObservationIgnored private var finishedContinuations: [UUID: AsyncStream<RecordingResult>.Continuation] = [:]
    @ObservationIgnored private nonisolated(unsafe) var orientationObserver: (any NSObjectProtocol)?

    // MARK: - Init

    /// Creates a camera with the given configuration (defaults to ``CameraConfiguration()``).
    public convenience init(configuration: CameraConfiguration = CameraConfiguration()) {
        self.init(
            configuration: configuration,
            engine: CameraSession(),
            authorization: AVAuthorizationProvider()
        )
    }

    /// Designated initializer with injectable dependencies, used by tests.
    init(
        configuration: CameraConfiguration,
        engine: any CameraEngine,
        authorization: any AuthorizationProviding
    ) {
        self.configuration = configuration
        self.engine = engine
        self.authorization = authorization
        self.previewRotationAngle = OrientationResolver.rotationAngle(
            for: configuration.orientation,
            deviceOrientation: .portrait
        )
        startConsumingEvents()
        startObservingDeviceOrientation()
    }

    deinit {
        eventTask?.cancel()
        if let orientationObserver {
            NotificationCenter.default.removeObserver(orientationObserver)
        }
    }

    /// The underlying capture session box for the preview layer. Internal; used by ``CameraPreview``.
    var captureSessionBox: UncheckedSendableBox<AVCaptureSession>? {
        engine.captureSessionBox
    }

    // MARK: - Lifecycle

    /// Starts the camera: verifies permissions, configures the session, and begins the preview.
    ///
    /// - Throws: ``CameraError/cameraPermissionDenied`` or ``CameraError/microphonePermissionDenied``
    ///   if permissions are missing (the state becomes ``CameraState/permissionDenied``), or a
    ///   configuration error (the state becomes ``CameraState/failed(_:)``).
    public func start() async throws {
        // If already active, starting is a no-op.
        if stateMachine.state == .running || stateMachine.state.hasActiveRecording { return }
        guard stateMachine.canStart else { return }

        guard await ensureAuthorization(.video) else {
            stateMachine.markPermissionDenied()
            throw CameraError.cameraPermissionDenied
        }
        if configuration.isAudioEnabled {
            guard await ensureAuthorization(.audio) else {
                stateMachine.markPermissionDenied()
                throw CameraError.microphonePermissionDenied
            }
        }

        try stateMachine.beginStarting()
        do {
            try await engine.apply(configuration)
            let angle = recomputeOrientationAngle()
            await engine.setVideoRotationAngle(angle)
            try await engine.start()
            stateMachine.markRunning()
        } catch {
            let cameraError = Self.cameraError(from: error)
            stateMachine.markFailed(cameraError)
            throw cameraError
        }
    }

    /// Stops the camera and returns to the idle state. Safe to call when already idle.
    public func stop() async {
        await engine.stop()
        if stateMachine.state.hasActiveRecording, let pendingStop {
            self.pendingStop = nil
            pendingStop.resume(throwing: CameraError.cancelled)
        }
        stateMachine.markIdle()
    }

    /// Applies a new configuration. If the session is currently running (and not recording), it is
    /// reconfigured live; otherwise the configuration is stored for the next ``start()``.
    public func updateConfiguration(_ configuration: CameraConfiguration) async throws {
        self.configuration = configuration
        let angle = recomputeOrientationAngle()
        guard stateMachine.state == .running else { return }
        do {
            try await engine.apply(configuration)
            await engine.setVideoRotationAngle(angle)
        } catch {
            throw Self.cameraError(from: error)
        }
    }

    // MARK: - Recording

    /// Starts recording video to a library-generated file URL in the temporary directory.
    ///
    /// - Throws: ``CameraError/recordingAlreadyInProgress`` if a recording is active,
    ///   ``CameraError/sessionNotRunning`` if the session is not running.
    public func startRecording() async throws {
        try await startRecording(outputURL: Self.makeDefaultRecordingURL())
    }

    /// Starts recording video to the provided file URL.
    ///
    /// - Parameter outputURL: The destination file URL (should have a `.mov` extension).
    /// - Throws: ``CameraError/recordingAlreadyInProgress`` if a recording is active,
    ///   ``CameraError/sessionNotRunning`` if the session is not running.
    public func startRecording(outputURL: URL) async throws {
        try stateMachine.beginRecording()
        resetDuration()
        do {
            try await engine.startRecording(to: outputURL, configuration: configuration)
        } catch {
            stateMachine.finishRecording()
            throw Self.cameraError(from: error)
        }
    }

    /// Stops the in-progress recording and returns its result.
    ///
    /// - Returns: The ``RecordingResult`` for the finished recording.
    /// - Throws: ``CameraError/noRecordingInProgress`` if no recording is active, or a
    ///   ``CameraError`` describing a recording failure.
    @discardableResult
    public func stopRecording() async throws -> RecordingResult {
        try stateMachine.beginStoppingRecording()
        return try await withCheckedThrowingContinuation { continuation in
            self.pendingStop = continuation
            Task { await self.engine.stopRecording() }
        }
    }

    // MARK: - Duration tracking

    /// An async stream of the recording duration, updated continuously while recording. Yields the
    /// current value immediately on subscription, then ticks during recording (resetting to zero
    /// when a new recording starts). Multiple concurrent consumers are supported.
    ///
    /// ```swift
    /// for await duration in camera.recordingDurationStream() {
    ///     timerLabel = duration.formatted()
    /// }
    /// ```
    public func recordingDurationStream() -> AsyncStream<Duration> {
        let id = UUID()
        let (stream, continuation) = AsyncStream<Duration>.makeStream(
            bufferingPolicy: .bufferingNewest(1)
        )
        durationContinuations[id] = continuation
        continuation.onTermination = { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.durationContinuations.removeValue(forKey: id)
            }
        }
        continuation.yield(currentRecordingDuration)
        return stream
    }

    /// An async stream of completed recordings. This is how consumers receive the result of a
    /// recording that auto-stopped because ``CameraConfiguration/maximumRecordingDuration`` was
    /// reached (no `stopRecording()` caller is awaiting in that case).
    public func recordingFinishedStream() -> AsyncStream<RecordingResult> {
        let id = UUID()
        let (stream, continuation) = AsyncStream<RecordingResult>.makeStream(
            bufferingPolicy: .bufferingNewest(4)
        )
        finishedContinuations[id] = continuation
        continuation.onTermination = { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.finishedContinuations.removeValue(forKey: id)
            }
        }
        return stream
    }

    // MARK: - Event handling

    private func startConsumingEvents() {
        let stream = engine.makeEventStream()
        eventTask = Task { [weak self] in
            for await event in stream {
                guard let self else { return }
                self.handle(event)
            }
        }
    }

    private func handle(_ event: CameraEngineEvent) {
        switch event {
        case .recordingProgress(let duration):
            currentRecordingDuration = duration
            broadcastDuration(duration)

        case .recordingFinished(let result):
            if stateMachine.state.hasActiveRecording {
                stateMachine.finishRecording()
            }
            currentRecordingDuration = .zero
            lastRecordingResult = result
            broadcastDuration(.zero)
            broadcastFinished(result)
            if let pendingStop {
                self.pendingStop = nil
                pendingStop.resume(returning: result)
            }

        case .recordingFailed(let error):
            if stateMachine.state.hasActiveRecording {
                stateMachine.finishRecording()
            }
            if let pendingStop {
                self.pendingStop = nil
                pendingStop.resume(throwing: error)
            }

        case .interrupted, .interruptionEnded, .runtimeError:
            // The engine attempts automatic recovery for these; the public state is unchanged.
            break
        }
    }

    // MARK: - Helpers

    private func ensureAuthorization(_ mediaType: CameraMediaType) async -> Bool {
        switch authorization.status(for: mediaType) {
        case .authorized:
            return true
        case .notDetermined:
            return await authorization.requestAccess(for: mediaType)
        case .denied, .restricted:
            return false
        }
    }

    private func resetDuration() {
        currentRecordingDuration = .zero
        broadcastDuration(.zero)
    }

    private func broadcastDuration(_ duration: Duration) {
        for continuation in durationContinuations.values {
            continuation.yield(duration)
        }
    }

    private func broadcastFinished(_ result: RecordingResult) {
        for continuation in finishedContinuations.values {
            continuation.yield(result)
        }
    }

    @discardableResult
    private func recomputeOrientationAngle() -> CGFloat {
        let angle = OrientationResolver.rotationAngle(
            for: configuration.orientation,
            deviceOrientation: currentDeviceOrientation()
        )
        previewRotationAngle = angle
        return angle
    }

    private func currentDeviceOrientation() -> DeviceOrientation {
        #if canImport(UIKit)
        switch UIDevice.current.orientation {
        case .portrait: return .portrait
        case .portraitUpsideDown: return .portraitUpsideDown
        case .landscapeLeft: return .landscapeLeft
        case .landscapeRight: return .landscapeRight
        default: return .unknown
        }
        #else
        return .portrait
        #endif
    }

    private func startObservingDeviceOrientation() {
        #if canImport(UIKit)
        UIDevice.current.beginGeneratingDeviceOrientationNotifications()
        orientationObserver = NotificationCenter.default.addObserver(
            forName: UIDevice.orientationDidChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self else { return }
                let angle = self.recomputeOrientationAngle()
                Task { await self.engine.setVideoRotationAngle(angle) }
            }
        }
        #endif
    }

    private static func cameraError(from error: any Error) -> CameraError {
        (error as? CameraError) ?? .unknown(reason: error.localizedDescription)
    }

    /// Generates a unique `.mov` file URL in the temporary directory for silent recording.
    static func makeDefaultRecordingURL() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("ASCamera-\(UUID().uuidString)")
            .appendingPathExtension("mov")
    }
}
