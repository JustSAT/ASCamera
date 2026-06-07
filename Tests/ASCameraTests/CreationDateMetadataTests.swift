import AVFoundation
import Foundation
import Testing
@testable import ASCamera

@Suite("Recording start-time metadata")
struct CreationDateMetadataTests {
    @Test("Embeds a QuickTime creation-date item")
    func usesQuickTimeCreationDateIdentifier() {
        let items = CameraSession.creationDateMetadata(for: Date())
        #expect(items.count == 1)
        #expect(items.first?.identifier == .quickTimeMetadataCreationDate)
    }

    @Test("Embedded value round-trips back to the start date")
    func valueRoundTrips() throws {
        // A fixed, known instant (2026-06-07T12:34:56Z).
        let original = Date(timeIntervalSince1970: 1_780_835_696)
        let item = try #require(CameraSession.creationDateMetadata(for: original).first)
        let string = try #require(item.value as? String)

        let parsed = try #require(ISO8601DateFormatter().date(from: string))
        // ISO-8601 without fractional seconds is accurate to the second.
        #expect(abs(parsed.timeIntervalSince(original)) < 1)
    }
}
