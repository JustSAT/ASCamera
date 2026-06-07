import Foundation

/// A recorded video on disk, shown in the example's library.
struct Recording: Identifiable, Hashable {
    let url: URL
    var duration: Duration?
    var fileSize: Int64

    var id: URL { url }
    var fileName: String { url.lastPathComponent }

    var fileSizeString: String {
        ByteCountFormatter.string(fromByteCount: fileSize, countStyle: .file)
    }
}

extension Duration {
    /// `mm:ss` clock string for timer labels.
    var clockString: String {
        let totalSeconds = Int(components.seconds)
        return String(format: "%02d:%02d", totalSeconds / 60, totalSeconds % 60)
    }
}

enum RecordingFormatters {
    /// Filesystem-safe timestamp used in recording file names.
    static let fileName: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter
    }()

    /// Human-readable timestamp for display.
    static let display: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .medium
        return formatter
    }()
}
