import Testing
@testable import ASCamera

@Suite("Configuration & value types")
struct ConfigurationTests {
    @Test("Default configuration uses sensible defaults")
    func defaults() {
        let config = CameraConfiguration()
        #expect(config.position == .back)
        #expect(config.frameRate == .fps30)
        #expect(config.resolution == .fullHD)
        #expect(config.torch == .off)
        #expect(config.isAudioEnabled)
        #expect(config.stabilization == .auto)
        #expect(config.orientation == .device)
        #expect(config.maximumRecordingDuration == nil)
    }

    @Test("Builder helpers compose without mutating the original")
    func builderComposition() {
        let base = CameraConfiguration()
        let configured = base
            .position(.front)
            .frameRate(.fps60)
            .resolution(.uhd4K)
            .torch(.auto)
            .audioEnabled(false)
            .stabilization(.cinematic)
            .orientation(.lockedPortrait)
            .maximumRecordingDuration(.seconds(30))

        #expect(configured.position == .front)
        #expect(configured.frameRate == .fps60)
        #expect(configured.resolution == .uhd4K)
        #expect(configured.torch == .auto)
        #expect(!configured.isAudioEnabled)
        #expect(configured.stabilization == .cinematic)
        #expect(configured.orientation == .lockedPortrait)
        #expect(configured.maximumRecordingDuration == .seconds(30))

        // Original is untouched (value semantics).
        #expect(base.position == .back)
        #expect(base.maximumRecordingDuration == nil)
    }

    @Test("Frame rate presets and integer literals")
    func frameRate() {
        #expect(FrameRate.fps24.fps == 24)
        #expect(FrameRate.fps120.fps == 120)
        let literal: FrameRate = 30
        #expect(literal == .fps30)
        // Clamps to a minimum of 1.
        #expect(FrameRate(0).fps == 1)
        #expect(FrameRate.fps24 < FrameRate.fps60)
    }

    @Test("Camera position toggling")
    func positionToggle() {
        #expect(CameraPosition.front.toggled == .back)
        #expect(CameraPosition.back.toggled == .front)
    }

    @Test("Resolution pixel counts are ordered")
    func resolutionOrdering() {
        #expect(Resolution.hd.pixelCount < Resolution.fullHD.pixelCount)
        #expect(Resolution.fullHD.pixelCount < Resolution.uhd4K.pixelCount)
    }
}
