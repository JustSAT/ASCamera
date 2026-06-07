import Foundation

/// Errors thrown by ``Camera`` and the surrounding ASCamera APIs.
///
/// `CameraError` is intentionally a small, stable, `Equatable` value type so that it can be
/// embedded inside ``CameraState`` and compared in tests and SwiftUI diffing without exposing
/// any AVFoundation types to consumers.
public enum CameraError: Error, Sendable, Equatable, CustomStringConvertible {
    /// Camera usage was denied or restricted by the user/system.
    case cameraPermissionDenied
    /// Microphone usage was denied or restricted while audio recording is enabled.
    case microphonePermissionDenied
    /// The capture session could not be configured.
    case sessionConfigurationFailed(reason: String)
    /// No capture device is available for the requested position.
    case deviceUnavailable(position: CameraPosition)
    /// The requested configuration is not supported by the current device.
    case unsupportedConfiguration(reason: String)
    /// `startRecording` was called while a recording was already in progress.
    case recordingAlreadyInProgress
    /// `stopRecording` was called while no recording was in progress.
    case noRecordingInProgress
    /// Recording failed while in progress.
    case recordingFailed(reason: String)
    /// The session is not running, so the requested operation is not allowed.
    case sessionNotRunning
    /// The capture session was interrupted (e.g. phone call, background, resource conflict).
    case interrupted(reason: String)
    /// The operation was cancelled (e.g. structured concurrency cancellation).
    case cancelled
    /// An unexpected error occurred. `reason` carries a human-readable description.
    case unknown(reason: String)

    public var description: String {
        switch self {
        case .cameraPermissionDenied:
            return "Camera access is not authorized."
        case .microphonePermissionDenied:
            return "Microphone access is not authorized."
        case .sessionConfigurationFailed(let reason):
            return "Failed to configure the capture session: \(reason)"
        case .deviceUnavailable(let position):
            return "No capture device available for position: \(position)."
        case .unsupportedConfiguration(let reason):
            return "Unsupported configuration: \(reason)"
        case .recordingAlreadyInProgress:
            return "A recording is already in progress."
        case .noRecordingInProgress:
            return "There is no recording in progress."
        case .recordingFailed(let reason):
            return "Recording failed: \(reason)"
        case .sessionNotRunning:
            return "The camera session is not running."
        case .interrupted(let reason):
            return "The capture session was interrupted: \(reason)"
        case .cancelled:
            return "The operation was cancelled."
        case .unknown(let reason):
            return "An unexpected error occurred: \(reason)"
        }
    }
}
