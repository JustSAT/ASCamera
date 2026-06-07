import Foundation

/// The result of a completed video recording.
///
/// Returned from ``Camera/stopRecording()`` and also delivered through
/// ``Camera/recordingFinishedStream()`` (notably when a recording auto-stops because
/// ``CameraConfiguration/maximumRecordingDuration`` was reached).
public struct RecordingResult: Sendable, Equatable {
    /// The on-disk location of the recorded video file.
    public let url: URL
    /// The total duration of the recording.
    public let duration: Duration
    /// The size of the recorded file in bytes.
    public let fileSize: Int64

    public init(url: URL, duration: Duration, fileSize: Int64) {
        self.url = url
        self.duration = duration
        self.fileSize = fileSize
    }
}
