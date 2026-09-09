import AVFoundation
import Foundation
import Testing
@testable import ASCamera

@Suite("Recording file type")
struct RecordingFileTypeTests {
    @Test("Default configuration records QuickTime movies")
    func defaultIsQuickTime() {
        #expect(CameraConfiguration().fileType == .quickTimeMovie)
    }

    @Test("Builder helper sets the file type without mutating the original")
    func builder() {
        let base = CameraConfiguration()
        let configured = base.fileType(.mpeg4)
        #expect(configured.fileType == .mpeg4)
        #expect(base.fileType == .quickTimeMovie)
    }

    @Test("Path extensions match the container")
    func pathExtensions() {
        #expect(RecordingFileType.quickTimeMovie.pathExtension == "mov")
        #expect(RecordingFileType.mpeg4.pathExtension == "mp4")
    }

    @Test("AVFileType mapping")
    func avFileTypes() {
        #expect(RecordingFileType.quickTimeMovie.avFileType == .mov)
        #expect(RecordingFileType.mpeg4.avFileType == .mp4)
    }

    @Test("QuickTime accepts .mov/.qt in any case and rejects .mp4")
    func quickTimeAcceptsMatchingExtensions() {
        let type = RecordingFileType.quickTimeMovie
        #expect(type.accepts(URL(fileURLWithPath: "/tmp/take.mov")))
        #expect(type.accepts(URL(fileURLWithPath: "/tmp/TAKE.MOV")))
        #expect(type.accepts(URL(fileURLWithPath: "/tmp/take.qt")))
        #expect(!type.accepts(URL(fileURLWithPath: "/tmp/take.mp4")))
        #expect(!type.accepts(URL(fileURLWithPath: "/tmp/take")))
    }

    @Test("MPEG-4 accepts .mp4 in any case and rejects .mov")
    func mpeg4AcceptsMatchingExtensions() {
        let type = RecordingFileType.mpeg4
        #expect(type.accepts(URL(fileURLWithPath: "/tmp/take.mp4")))
        #expect(type.accepts(URL(fileURLWithPath: "/tmp/TAKE.MP4")))
        #expect(!type.accepts(URL(fileURLWithPath: "/tmp/take.mov")))
        #expect(!type.accepts(URL(fileURLWithPath: "/tmp/take")))
    }

    @Test("Remux sidecar is a distinct .mov next to the requested file")
    func sidecarURL() {
        let requested = URL(fileURLWithPath: "/tmp/videos/free_2026.mp4")
        let sidecar = MovieRemuxer.sidecarURL(for: requested)
        #expect(sidecar.pathExtension == "mov")
        #expect(sidecar.deletingLastPathComponent() == requested.deletingLastPathComponent())
        #expect(sidecar != requested)
        #expect(sidecar.deletingPathExtension().lastPathComponent.hasPrefix("free_2026"))
    }
}
