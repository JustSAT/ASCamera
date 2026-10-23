import CoreMedia
import Testing
@testable import ASCamera

@Suite("Format selection")
struct FormatSelectionTests {
    private func score(_ width: Int32, _ height: Int32, for resolution: Resolution = .fullHD) -> FormatScore {
        CameraDeviceDiscovery.formatScore(
            dimensions: CMVideoDimensions(width: width, height: height),
            resolution: resolution
        )
    }

    @Test("A landscape format beats a portrait one with the same pixel count")
    func landscapeBeatsPortraitOfEqualArea() {
        #expect(score(1920, 1080) < score(1080, 1920))
    }

    @Test("A landscape format beats a square one with the same pixel count")
    func landscapeBeatsSquareOfEqualArea() {
        #expect(score(1920, 1080) < score(1440, 1440))
    }

    @Test("A landscape format beats a portrait one even when the portrait one is closer to the target")
    func landscapeBeatsCloserPortrait() {
        #expect(score(3840, 2160) < score(1080, 1920))
    }

    @Test("Among landscape formats the closest one at or above the target wins")
    func closestLandscapeWins() {
        #expect(score(1920, 1080) < score(3840, 2160))
        #expect(score(1920, 1080) < score(1280, 720))
        #expect(score(3840, 2160) < score(1280, 720))
    }
}
