import AVFoundation
import Foundation

/// Rewraps a finished QuickTime take into another container without re-encoding.
///
/// Used when ``CameraConfiguration/fileType`` asks for something other than QuickTime: the capture
/// pipeline records into a sidecar `.mov` next to the requested file, and the sidecar is passed
/// through an `AVAssetExportSession` into the requested container once the take is complete.
enum MovieRemuxer {
    /// Where the QuickTime take is captured when the caller asked for a different container: the
    /// same directory (so the export lands on the same volume), a `.mov` extension the capture
    /// pipeline is honest about, and a suffix that cannot collide with the requested name.
    static func sidecarURL(for destination: URL) -> URL {
        destination
            .deletingLastPathComponent()
            .appendingPathComponent(destination.deletingPathExtension().lastPathComponent + "-capture")
            .appendingPathExtension(RecordingFileType.quickTimeMovie.pathExtension)
    }

    /// Copies every track of `source` into `destination` as `fileType`, replacing any file already
    /// there. The recording-start stamp is written again so it survives the rewrap.
    static func remux(
        source: URL,
        to destination: URL,
        fileType: AVFileType,
        creationDate: Date
    ) async throws {
        let asset = AVURLAsset(url: source)
        guard let session = AVAssetExportSession(asset: asset, presetName: AVAssetExportPresetPassthrough) else {
            throw CameraError.recordingFailed(reason: "Passthrough export is unavailable for the recorded take.")
        }
        try? FileManager.default.removeItem(at: destination)
        session.metadata = CameraSession.creationDateMetadata(for: creationDate)
        session.shouldOptimizeForNetworkUse = true
        if #available(iOS 18.0, *) {
            try await session.export(to: destination, as: fileType)
        } else {
            session.outputURL = destination
            session.outputFileType = fileType
            await session.export()
            if let error = session.error { throw error }
            guard session.status == .completed else {
                throw CameraError.recordingFailed(reason: "Export ended in state \(session.status.rawValue).")
            }
        }
    }
}
