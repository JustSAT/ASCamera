import AVFoundation
import CoreGraphics
import Foundation
@testable import ASCamera

/// An in-memory ``CameraEngine`` used to drive ``Camera`` deterministically in tests, with no
/// camera hardware. Tests push lifecycle events through `emit(_:)` and inspect recorded calls.
actor FakeCameraEngine: CameraEngine {
    nonisolated let captureSessionBox: UncheckedSendableBox<AVCaptureSession>? = nil

    nonisolated let eventStream: AsyncStream<CameraEngineEvent>
    private nonisolated let eventContinuation: AsyncStream<CameraEngineEvent>.Continuation

    private(set) var applyCount = 0
    private(set) var startCount = 0
    private(set) var stopCount = 0
    private(set) var startRecordingCount = 0
    private(set) var stopRecordingCount = 0
    private(set) var lastRotationAngle: CGFloat?
    private(set) var lastRecordingURL: URL?
    private(set) var lastConfiguration: CameraConfiguration?

    private var applyError: CameraError?
    private var startRecordingError: CameraError?
    /// When set, `stopRecording()` automatically emits this result, mirroring the real engine
    /// finishing the file after a stop request.
    private var resultOnStop: RecordingResult?

    init() {
        (eventStream, eventContinuation) = AsyncStream<CameraEngineEvent>.makeStream(
            bufferingPolicy: .unbounded
        )
    }

    nonisolated func makeEventStream() -> AsyncStream<CameraEngineEvent> {
        eventStream
    }

    /// Pushes an unsolicited event to ``Camera``.
    nonisolated func emit(_ event: CameraEngineEvent) {
        eventContinuation.yield(event)
    }

    // MARK: Test configuration

    func setApplyError(_ error: CameraError?) { applyError = error }
    func setStartRecordingError(_ error: CameraError?) { startRecordingError = error }
    func setResultOnStop(_ result: RecordingResult?) { resultOnStop = result }

    // MARK: CameraEngine

    func apply(_ configuration: CameraConfiguration) async throws {
        applyCount += 1
        lastConfiguration = configuration
        if let applyError { throw applyError }
    }

    func start() async throws {
        startCount += 1
    }

    func stop() async {
        stopCount += 1
    }

    func startRecording(to url: URL, configuration: CameraConfiguration) async throws {
        startRecordingCount += 1
        lastRecordingURL = url
        lastConfiguration = configuration
        if let startRecordingError { throw startRecordingError }
    }

    func stopRecording() async {
        stopRecordingCount += 1
        if let resultOnStop {
            eventContinuation.yield(.recordingFinished(resultOnStop))
        }
    }

    func setVideoRotationAngle(_ angle: CGFloat) async {
        lastRotationAngle = angle
    }
}
