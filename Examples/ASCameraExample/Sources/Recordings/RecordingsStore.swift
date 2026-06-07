import Foundation
import Observation
import ASCamera

/// Owns the example's recorded files: where they live, listing them, and adding/removing.
/// Shared across both recorder screens and the library screen via the SwiftUI environment.
@MainActor
@Observable
final class RecordingsStore {
    private(set) var recordings: [Recording] = []

    /// `Documents/Recordings`, where the example saves all clips so they persist between launches.
    static let directory: URL = {
        let base = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return base.appendingPathComponent("Recordings", isDirectory: true)
    }()

    init() {
        reload()
    }

    /// Rescans the recordings directory from disk.
    func reload() {
        ensureDirectory()
        let keys: [URLResourceKey] = [.fileSizeKey, .contentModificationDateKey]
        let urls = (try? FileManager.default.contentsOfDirectory(
            at: Self.directory,
            includingPropertiesForKeys: keys
        )) ?? []

        recordings = urls
            .filter { $0.pathExtension.lowercased() == "mov" }
            .map { Recording(url: $0, duration: nil, fileSize: fileSize(at: $0)) }
            .sorted { $0.fileName > $1.fileName }
    }

    /// Adds a freshly finished recording (deduped by URL, since explicit stop and auto-stop can
    /// both surface the same result).
    func add(_ result: RecordingResult) {
        guard !recordings.contains(where: { $0.url == result.url }) else { return }
        let recording = Recording(url: result.url, duration: result.duration, fileSize: result.fileSize)
        recordings.insert(recording, at: 0)
    }

    func delete(_ recording: Recording) {
        try? FileManager.default.removeItem(at: recording.url)
        recordings.removeAll { $0.url == recording.url }
    }

    /// Builds a timestamped destination URL, e.g. `rec-2026-06-07_22-30-15.mov`, so the start time
    /// is visible in the file name in addition to being embedded in the file's metadata.
    static func makeRecordingURL(start: Date) -> URL {
        let name = "rec-\(RecordingFormatters.fileName.string(from: start)).mov"
        return directory.appendingPathComponent(name)
    }

    private func ensureDirectory() {
        try? FileManager.default.createDirectory(
            at: Self.directory,
            withIntermediateDirectories: true
        )
    }

    private func fileSize(at url: URL) -> Int64 {
        let values = try? url.resourceValues(forKeys: [.fileSizeKey])
        return Int64(values?.fileSize ?? 0)
    }
}
