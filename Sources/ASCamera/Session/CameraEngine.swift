import AVFoundation
import Foundation

/// Unsolicited events emitted by a ``CameraEngine`` over its lifetime.
///
/// Request/response operations (start, stop, recording start) are modelled as `async` functions on
/// the engine. Everything that happens *without* a direct caller — recording progress ticks,
/// auto-stop on reaching the maximum duration, interruptions, and runtime errors — is delivered
/// through the engine's event stream.
enum CameraEngineEvent: Sendable {
    /// The recording advanced; carries the elapsed recording duration.
    case recordingProgress(Duration)
    /// A recording finished and was written to disk (covers both explicit stop and auto-stop).
    case recordingFinished(RecordingResult)
    /// A recording failed irrecoverably.
    case recordingFailed(CameraError)
    /// The session was interrupted (phone call, background, resource conflict, …).
    case interrupted(reason: String)
    /// A prior interruption ended; the engine has resumed (or will resume) running.
    case interruptionEnded
    /// Audio capture could not be wired up, so the session records video only. Audio is
    /// best-effort by design, but silently dropping it leaves consumers with a movie that has no
    /// audio track and no way to know why — this carries the reason instead.
    case audioUnavailable(reason: String)
    /// A runtime error occurred on the session.
    case runtimeError(CameraError)
}

/// The capture engine behind ``Camera``.
///
/// The production implementation (``CameraSession``) wraps `AVCaptureSession`; tests substitute a
/// fake. Keeping AVFoundation entirely behind this protocol is what lets the recording lifecycle,
/// duration tracking, and auto-stop behavior be unit tested without camera hardware.
protocol CameraEngine: Sendable {
    /// A box holding the underlying `AVCaptureSession` for the preview layer to reference, or `nil`
    /// for engines (e.g. fakes) that have no live preview.
    nonisolated var captureSessionBox: UncheckedSendableBox<AVCaptureSession>? { get }

    /// The single stream of unsolicited engine events. Consumed once by ``Camera``.
    func makeEventStream() -> AsyncStream<CameraEngineEvent>

    /// Applies a configuration, (re)building inputs/outputs as needed.
    func apply(_ configuration: CameraConfiguration) async throws

    /// Starts the capture session running. Returns once the session is running.
    func start() async throws

    /// Stops the capture session.
    func stop() async

    /// Begins recording to the given URL. Returns once recording has begun.
    func startRecording(to url: URL, configuration: CameraConfiguration) async throws

    /// Requests that the current recording stop. The result is delivered via
    /// ``CameraEngineEvent/recordingFinished(_:)``.
    func stopRecording() async

    /// Sets the clockwise video rotation angle (degrees) applied to the recording output, so the
    /// exported video orientation matches the preview. The angle is resolved on the main actor by
    /// ``Camera`` from the active ``OrientationStrategy`` and current device orientation.
    func setVideoRotationAngle(_ angle: CGFloat) async
}
