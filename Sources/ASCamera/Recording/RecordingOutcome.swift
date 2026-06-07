import AVFoundation
import Foundation

/// Pure classification of an `AVCaptureFileOutputRecordingDelegate` finish error into "the file is
/// usable" vs "the recording failed".
///
/// Crucially, reaching `maximumRecordedDuration` reports an `AVError`, but the file *is* complete
/// and playable — so it must be treated as a successful result, matching the requirement that an
/// auto-stopped recording returns a normal ``RecordingResult``.
enum RecordingOutcome {
    /// Whether the recording produced a usable file despite any reported error.
    static func isSuccessful(error: (any Error)?) -> Bool {
        guard let error else { return true }

        let nsError = error as NSError
        // AVFoundation sets this flag when the partial file is still finished and playable.
        if let finished = nsError.userInfo[AVErrorRecordingSuccessfullyFinishedKey] as? Bool {
            return finished
        }
        // Hitting the configured maximum duration is an expected, successful auto-stop.
        if nsError.domain == AVFoundationErrorDomain,
           nsError.code == AVError.maximumDurationReached.rawValue {
            return true
        }
        return false
    }
}
