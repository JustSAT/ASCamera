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

    @Test("Recording start resolves the rotation angle again instead of reusing the last pushed one")
    func anglePushedToEngineOnRecordingStart() async throws {
        let engine = FakeCameraEngine()
        let camera = Camera.makeForTesting(
            configuration: CameraConfiguration().orientation(.lockedPortrait),
            engine: engine
        )
        try await camera.start()
        // Drop the angle recorded by `start()` so only a fresh push can satisfy the expectation
        // below — the interface can rotate between starting the session and starting a recording
        // without the device physically moving, and nothing would report that.
        await engine.clearRotationAngle()

        try await camera.startRecording(outputURL: URL(fileURLWithPath: "/tmp/ascamera-test.mov"))

        #expect(await engine.rotationAngleAtRecordingStart == 90)
        #expect(await engine.lastRotationAngle == 90)
    }

    @Test("A failed recording start still resolved the angle first")
    func anglePushedEvenWhenRecordingStartFails() async throws {
        let engine = FakeCameraEngine()
        await engine.setStartRecordingError(.recordingFailed(reason: "no disk space"))
        let camera = Camera.makeForTesting(
            configuration: CameraConfiguration().orientation(.lockedLandscapeLeft),
            engine: engine
        )
        try await camera.start()
        await engine.clearRotationAngle()

        await #expect(throws: CameraError.self) {
            try await camera.startRecording(outputURL: URL(fileURLWithPath: "/tmp/ascamera-test.mov"))
        }

        #expect(await engine.rotationAngleAtRecordingStart == 180)
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
