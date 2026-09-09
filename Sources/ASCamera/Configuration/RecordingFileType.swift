import AVFoundation
import Foundation

/// The container a finished recording is delivered in.
///
/// `AVCaptureMovieFileOutput` only ever writes QuickTime movies, whatever the output URL's extension
/// says — and AVFoundation picks the container *parser* from that extension. A QuickTime take that
/// is merely named `.mp4` therefore reads back with its audio track missing in `AVAsset`, `AVPlayer`
/// and export sessions alike. ASCamera closes both halves of that trap: an output URL whose extension
/// does not match the configured type is refused up front, and real MPEG-4 is produced by remuxing
/// the finished QuickTime take (no re-encoding) instead of relabelling it.
public enum RecordingFileType: Sendable, Equatable, CaseIterable {
    /// QuickTime movie (`.mov`) — the native container of the capture pipeline. Default.
    case quickTimeMovie
    /// MPEG-4 (`.mp4`) — captured as QuickTime, then rewrapped into MPEG-4 when the take finishes.
    /// Finishing takes a little longer than QuickTime (I/O bound, proportional to the file size),
    /// and the capture temporarily needs the take's size in free space twice.
    case mpeg4

    /// The path extension a file of this type carries.
    public var pathExtension: String {
        switch self {
        case .quickTimeMovie: return "mov"
        case .mpeg4: return "mp4"
        }
    }

    /// Whether `url` carries an extension matching this container (case-insensitive).
    public func accepts(_ url: URL) -> Bool {
        acceptedExtensions.contains(url.pathExtension.lowercased())
    }

    var avFileType: AVFileType {
        switch self {
        case .quickTimeMovie: return .mov
        case .mpeg4: return .mp4
        }
    }

    private var acceptedExtensions: Set<String> {
        switch self {
        case .quickTimeMovie: return ["mov", "qt"]
        case .mpeg4: return ["mp4"]
        }
    }
}
