import CoreGraphics
import Testing
@testable import ASCamera

@MainActor
@Suite("Camera orientation handling")
struct OrientationHandlingTests {
    @Test("Locked orientation produces a fixed preview angle at init")
    func lockedPreviewAngle() {
        let portrait = Camera.makeForTesting(
            configuration: CameraConfiguration().orientation(.lockedPortrait)
        )
        #expect(portrait.previewRotationAngle == 90)

        let landscapeRight = Camera.makeForTesting(
            configuration: CameraConfiguration().orientation(.lockedLandscapeRight)
        )
        #expect(landscapeRight.previewRotationAngle == 0)

        let landscapeLeft = Camera.makeForTesting(
            configuration: CameraConfiguration().orientation(.lockedLandscapeLeft)
        )
        #expect(landscapeLeft.previewRotationAngle == 180)
    }

    @Test("Start pushes the resolved rotation angle to the engine")
    func anglePushedToEngineOnStart() async throws {
        let engine = FakeCameraEngine()
        let camera = Camera.makeForTesting(
            configuration: CameraConfiguration().orientation(.lockedPortrait),
            engine: engine
        )
        try await camera.start()
        #expect(await engine.lastRotationAngle == 90)
    }

    @Test("updateConfiguration re-resolves the preview angle for the new strategy")
    func updateConfigurationUpdatesAngle() async throws {
        let camera = Camera.makeForTesting(
            configuration: CameraConfiguration().orientation(.lockedPortrait)
        )
        #expect(camera.previewRotationAngle == 90)

        try await camera.updateConfiguration(
            CameraConfiguration().orientation(.lockedLandscapeLeft)
        )
        #expect(camera.previewRotationAngle == 180)
        #expect(camera.configuration.orientation == .lockedLandscapeLeft)
    }
}
