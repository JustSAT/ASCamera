import AVFoundation
import Foundation

/// Bridges `AVCaptureFileOutputRecordingDelegate` callbacks (delivered on an arbitrary queue) into
/// `@Sendable` closures the ``CameraSession`` actor can hop onto.
final class MovieRecordingDelegate: NSObject, AVCaptureFileOutputRecordingDelegate, Sendable {
    private let onStart: @Sendable (URL) -> Void
    private let onFinish: @Sendable (URL, (any Error)?) -> Void

    init(
        onStart: @escaping @Sendable (URL) -> Void,
        onFinish: @escaping @Sendable (URL, (any Error)?) -> Void
    ) {
        self.onStart = onStart
        self.onFinish = onFinish
    }

    func fileOutput(
        _ output: AVCaptureFileOutput,
        didStartRecordingTo fileURL: URL,
        from connections: [AVCaptureConnection]
    ) {
        onStart(fileURL)
    }

    func fileOutput(
        _ output: AVCaptureFileOutput,
        didFinishRecordingTo outputFileURL: URL,
        from connections: [AVCaptureConnection],
        error: (any Error)?
    ) {
        onFinish(outputFileURL, error)
    }
}
