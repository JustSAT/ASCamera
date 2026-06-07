import AVFoundation
import CoreGraphics
import Foundation
#if canImport(UIKit)
import UIKit
#endif

/// The production ``CameraEngine`` backed by `AVCaptureSession` and `AVCaptureMovieFileOutput`.
///
/// All AVFoundation objects are owned and mutated exclusively on this actor's executor. The only
/// value that escapes is the `AVCaptureSession` reference, handed to the main-actor preview layer
/// through ``captureSessionBox`` (see ``UncheckedSendableBox``).
actor CameraSession: CameraEngine {
    // MARK: Capture objects (actor-isolated)

    private let session: AVCaptureSession
    private let movieOutput = AVCaptureMovieFileOutput()
    private var videoInput: AVCaptureDeviceInput?
    private var audioInput: AVCaptureDeviceInput?
    private var videoDevice: AVCaptureDevice?

    // MARK: Recording state

    private var recordingDelegate: MovieRecordingDelegate?
    private var currentRecordingURL: URL?
    private var lastRecordedDuration: Duration = .zero
    private var progressTask: Task<Void, Never>?
    private var pendingRotationAngle: CGFloat = OrientationResolver.portraitAngle

    /// Monotonic clock used to drive the live recording timer. The timer is anchored at the moment
    /// recording is requested so the UI advances immediately, rather than waiting for the movie
    /// file output's `recordedDuration` to start growing (which lags ~1–2s on the first recording
    /// while the capture pipeline warms up). The exact written-file duration is still reported in
    /// the final ``RecordingResult`` via the asset's loaded duration.
    private let clock = ContinuousClock()
    private var recordingStartInstant: ContinuousClock.Instant?

    // MARK: Observation

    private nonisolated(unsafe) var observerTokens: [any NSObjectProtocol] = []
    private var observersInstalled = false

    // MARK: Events

    private let eventStream: AsyncStream<CameraEngineEvent>
    private let eventContinuation: AsyncStream<CameraEngineEvent>.Continuation

    // MARK: Preview bridge

    nonisolated let captureSessionBox: UncheckedSendableBox<AVCaptureSession>?

    init() {
        let session = AVCaptureSession()
        self.session = session
        self.captureSessionBox = UncheckedSendableBox(session)
        let (stream, continuation) = AsyncStream<CameraEngineEvent>.makeStream(
            bufferingPolicy: .bufferingNewest(16)
        )
        self.eventStream = stream
        self.eventContinuation = continuation
    }

    deinit {
        progressTask?.cancel()
        for token in observerTokens {
            NotificationCenter.default.removeObserver(token)
        }
        eventContinuation.finish()
    }

    nonisolated func makeEventStream() -> AsyncStream<CameraEngineEvent> {
        eventStream
    }

    // MARK: - Configuration

    func apply(_ configuration: CameraConfiguration) async throws {
        session.beginConfiguration()
        do {
            try configureVideoInput(position: configuration.position)
            configureAudioInput(enabled: configuration.isAudioEnabled)
            if session.canAddOutput(movieOutput), !session.outputs.contains(movieOutput) {
                session.addOutput(movieOutput)
            }
            session.sessionPreset = .inputPriority
            try configureDevice(with: configuration)
            session.commitConfiguration()
        } catch {
            session.commitConfiguration()
            throw mapConfigurationError(error)
        }
        applyStabilization(configuration.stabilization)
        applyRotationAngle(pendingRotationAngle)
    }

    private func configureVideoInput(position: CameraPosition) throws {
        // Reuse the existing input if it already matches the requested position.
        if let videoInput, videoInput.device.position == position.avPosition {
            self.videoDevice = videoInput.device
            return
        }
        guard let device = CameraDeviceDiscovery.videoDevice(for: position) else {
            throw CameraError.deviceUnavailable(position: position)
        }
        if let existing = videoInput {
            session.removeInput(existing)
            self.videoInput = nil
        }
        let input = try AVCaptureDeviceInput(device: device)
        guard session.canAddInput(input) else {
            throw CameraError.sessionConfigurationFailed(reason: "Cannot add video input.")
        }
        session.addInput(input)
        self.videoInput = input
        self.videoDevice = device
    }

    private func configureAudioInput(enabled: Bool) {
        if enabled {
            guard audioInput == nil else { return }
            guard let device = CameraDeviceDiscovery.audioDevice(),
                  let input = try? AVCaptureDeviceInput(device: device),
                  session.canAddInput(input) else {
                // Audio is best-effort; missing audio hardware should not abort configuration.
                return
            }
            session.addInput(input)
            self.audioInput = input
        } else if let audioInput {
            session.removeInput(audioInput)
            self.audioInput = nil
        }
    }

    private func configureDevice(with configuration: CameraConfiguration) throws {
        guard let device = videoDevice else {
            throw CameraError.deviceUnavailable(position: configuration.position)
        }
        guard let selection = CameraDeviceDiscovery.selectFormat(
            for: device,
            resolution: configuration.resolution,
            frameRate: configuration.frameRate
        ) else {
            throw CameraError.unsupportedConfiguration(
                reason: "No compatible format for \(configuration.resolution)."
            )
        }

        try device.lockForConfiguration()
        defer { device.unlockForConfiguration() }

        device.activeFormat = selection.format
        if selection.supportsRequestedFrameRate {
            let frameDuration = CMTime(
                value: 1,
                timescale: CMTimeScale(configuration.frameRate.fps.rounded())
            )
            device.activeVideoMinFrameDuration = frameDuration
            device.activeVideoMaxFrameDuration = frameDuration
        }

        if device.hasTorch, device.isTorchModeSupported(configuration.torch.avTorchMode) {
            device.torchMode = configuration.torch.avTorchMode
        }
    }

    private func applyStabilization(_ mode: VideoStabilizationMode) {
        guard let connection = movieOutput.connection(with: .video),
              connection.isVideoStabilizationSupported else { return }
        connection.preferredVideoStabilizationMode = mode.avStabilizationMode
    }

    private func applyRotationAngle(_ angle: CGFloat) {
        guard let connection = movieOutput.connection(with: .video),
              connection.isVideoRotationAngleSupported(angle) else { return }
        connection.videoRotationAngle = angle
    }

    private func mapConfigurationError(_ error: any Error) -> CameraError {
        if let cameraError = error as? CameraError { return cameraError }
        return .sessionConfigurationFailed(reason: error.localizedDescription)
    }

    // MARK: - Lifecycle

    func start() async throws {
        installObserversIfNeeded()
        guard !session.isRunning else { return }
        session.startRunning()
        guard session.isRunning else {
            throw CameraError.sessionConfigurationFailed(reason: "Session failed to start running.")
        }
    }

    func stop() async {
        progressTask?.cancel()
        progressTask = nil
        if session.isRunning {
            session.stopRunning()
        }
    }

    // MARK: - Recording

    func startRecording(to url: URL, configuration: CameraConfiguration) async throws {
        guard !movieOutput.isRecording else {
            throw CameraError.recordingAlreadyInProgress
        }
        guard movieOutput.connection(with: .video) != nil else {
            throw CameraError.sessionConfigurationFailed(reason: "No video connection for recording.")
        }

        if let maximum = configuration.maximumRecordingDuration {
            movieOutput.maxRecordedDuration = maximum.cmTime
        } else {
            movieOutput.maxRecordedDuration = .invalid
        }
        applyStabilization(configuration.stabilization)
        applyRotationAngle(pendingRotationAngle)

        // Stamp the recording-start time into the movie file's QuickTime metadata, so the exported
        // file itself carries the moment recording began (readable via AVAsset, `ffprobe`, etc.).
        movieOutput.metadata = Self.creationDateMetadata(for: Date())

        lastRecordedDuration = .zero
        currentRecordingURL = url

        let continuation = eventContinuation
        let delegate = MovieRecordingDelegate(
            onStart: { _ in },
            onFinish: { [weak self] finishedURL, error in
                guard let self else {
                    continuation.yield(.recordingFailed(.cancelled))
                    return
                }
                Task { await self.handleRecordingFinished(url: finishedURL, error: error) }
            }
        )
        recordingDelegate = delegate
        recordingStartInstant = clock.now
        movieOutput.startRecording(to: url, recordingDelegate: delegate)
        startProgressTracking()
    }

    func stopRecording() async {
        guard movieOutput.isRecording else { return }
        movieOutput.stopRecording()
    }

    /// Builds the QuickTime creation-date metadata embedded at recording start. The value is an
    /// ISO-8601 string under `com.apple.quicktime.creationdate`, which AVFoundation surfaces as the
    /// asset's creation date and `ffprobe` reports as `creation_time`.
    static func creationDateMetadata(for date: Date) -> [AVMetadataItem] {
        let item = AVMutableMetadataItem()
        item.identifier = .quickTimeMetadataCreationDate
        item.dataType = kCMMetadataBaseDataType_UTF8 as String
        item.value = ISO8601DateFormatter().string(from: date) as NSString
        return [item]
    }

    private func startProgressTracking() {
        progressTask?.cancel()
        progressTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(100))
                guard let self else { return }
                await self.emitProgressTick()
            }
        }
    }

    private func emitProgressTick() {
        guard movieOutput.isRecording, let start = recordingStartInstant else { return }
        let duration = start.duration(to: clock.now)
        lastRecordedDuration = duration
        eventContinuation.yield(.recordingProgress(duration))
    }

    private func handleRecordingFinished(url: URL, error: (any Error)?) async {
        progressTask?.cancel()
        progressTask = nil
        recordingDelegate = nil
        currentRecordingURL = nil
        recordingStartInstant = nil

        guard RecordingOutcome.isSuccessful(error: error) else {
            let reason = (error as NSError?)?.localizedDescription ?? "Unknown recording error."
            eventContinuation.yield(.recordingFailed(.recordingFailed(reason: reason)))
            return
        }

        let duration = await accurateDuration(of: url, fallback: lastRecordedDuration)
        let fileSize = fileSize(at: url)
        let result = RecordingResult(url: url, duration: duration, fileSize: fileSize)
        eventContinuation.yield(.recordingFinished(result))
    }

    private func accurateDuration(of url: URL, fallback: Duration) async -> Duration {
        let asset = AVURLAsset(url: url)
        if let cmDuration = try? await asset.load(.duration) {
            let resolved = Duration(cmTime: cmDuration)
            return resolved == .zero ? fallback : resolved
        }
        return fallback
    }

    private func fileSize(at url: URL) -> Int64 {
        let attributes = try? FileManager.default.attributesOfItem(atPath: url.path)
        return (attributes?[.size] as? NSNumber)?.int64Value ?? 0
    }

    // MARK: - Orientation

    func setVideoRotationAngle(_ angle: CGFloat) async {
        pendingRotationAngle = angle
        applyRotationAngle(angle)
    }

    // MARK: - Interruption / runtime observation

    private func installObserversIfNeeded() {
        guard !observersInstalled else { return }
        observersInstalled = true
        let center = NotificationCenter.default
        let continuation = eventContinuation

        observerTokens.append(center.addObserver(
            forName: AVCaptureSession.wasInterruptedNotification,
            object: session,
            queue: nil
        ) { notification in
            let reason = Self.interruptionReason(from: notification)
            continuation.yield(.interrupted(reason: reason))
        })

        observerTokens.append(center.addObserver(
            forName: AVCaptureSession.interruptionEndedNotification,
            object: session,
            queue: nil
        ) { [weak self] _ in
            continuation.yield(.interruptionEnded)
            if let self {
                Task { await self.resumeIfNeeded() }
            }
        })

        observerTokens.append(center.addObserver(
            forName: AVCaptureSession.runtimeErrorNotification,
            object: session,
            queue: nil
        ) { [weak self] notification in
            let error = notification.userInfo?[AVCaptureSessionErrorKey] as? NSError
            let reason = error?.localizedDescription ?? "Unknown runtime error."
            continuation.yield(.runtimeError(.unknown(reason: reason)))
            if let self {
                Task { await self.resumeIfNeeded() }
            }
        })

        #if canImport(UIKit)
        observerTokens.append(center.addObserver(
            forName: UIApplication.didBecomeActiveNotification,
            object: nil,
            queue: nil
        ) { [weak self] _ in
            if let self {
                Task { await self.resumeIfNeeded() }
            }
        })
        #endif
    }

    /// Restarts the session if it stopped due to an interruption while it should be running.
    private func resumeIfNeeded() {
        guard observersInstalled, !session.isRunning else { return }
        session.startRunning()
    }

    private static func interruptionReason(from notification: Notification) -> String {
        guard let value = notification.userInfo?[AVCaptureSessionInterruptionReasonKey] as? Int,
              let reason = AVCaptureSession.InterruptionReason(rawValue: value) else {
            return "unknown"
        }
        switch reason {
        case .videoDeviceNotAvailableInBackground:
            return "Video device not available in background."
        case .audioDeviceInUseByAnotherClient:
            return "Audio device in use by another client."
        case .videoDeviceInUseByAnotherClient:
            return "Video device in use by another client."
        case .videoDeviceNotAvailableWithMultipleForegroundApps:
            return "Video device not available with multiple foreground apps."
        case .videoDeviceNotAvailableDueToSystemPressure:
            return "Video device not available due to system pressure."
        default:
            return "unknown"
        }
    }
}
