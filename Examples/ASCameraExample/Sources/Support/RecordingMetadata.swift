import AVFoundation
import Foundation

/// Reads the recording-start timestamp that ASCamera embeds into each movie file's QuickTime
/// metadata. This is how the example *verifies* that the file itself contains the start time.
enum RecordingMetadata {
    static func startDate(for url: URL) async -> Date? {
        let asset = AVURLAsset(url: url)

        // Preferred: the QuickTime creation-date metadata ASCamera writes.
        if let metadata = try? await asset.load(.metadata) {
            let items = AVMetadataItem.metadataItems(
                from: metadata,
                filteredByIdentifier: .quickTimeMetadataCreationDate
            )
            if let item = items.first {
                if let date = try? await item.load(.dateValue) {
                    return date
                }
                if let string = try? await item.load(.stringValue), let date = parse(string) {
                    return date
                }
            }
        }

        // Fallback: the asset's aggregated creation date.
        if let item = try? await asset.load(.creationDate) {
            if let date = try? await item.load(.dateValue) {
                return date
            }
            if let string = try? await item.load(.stringValue), let date = parse(string) {
                return date
            }
        }
        return nil
    }

    private static func parse(_ string: String) -> Date? {
        let withFraction = ISO8601DateFormatter()
        withFraction.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = withFraction.date(from: string) { return date }
        return ISO8601DateFormatter().date(from: string)
    }
}
