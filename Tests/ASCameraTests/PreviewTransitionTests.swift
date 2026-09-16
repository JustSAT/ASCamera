import Testing
@testable import ASCamera

@MainActor
private final class SpyPreviewTransitionTarget: PreviewTransitioning {
    private(set) var beginCount = 0
    private(set) var endCount = 0

    func beginPreviewTransition() { beginCount += 1 }
    func endPreviewTransition() { endCount += 1 }
}

@MainActor
@Suite("Preview transition")
struct PreviewTransitionTests {

    @Test("Swapping the camera position brackets the reconfiguration")
    func positionChangeTransitions() async throws {
        let target = SpyPreviewTransitionTarget()
        let camera = Camera.makeForTesting()
        camera.previewTransitionTarget = target
        try await camera.start()

        try await camera.updateConfiguration(camera.configuration.position(.front))

        #expect(target.beginCount == 1)
        #expect(target.endCount == 1)
    }

    @Test("Changes that keep the position do not interrupt the preview")
    func otherChangesDoNotTransition() async throws {
        let target = SpyPreviewTransitionTarget()
        let camera = Camera.makeForTesting()
        camera.previewTransitionTarget = target
        try await camera.start()

        try await camera.updateConfiguration(camera.configuration.torch(.on))

        #expect(target.beginCount == 0)
        #expect(target.endCount == 0)
    }

    @Test("A stopped session applies the position without a transition")
    func idleSessionDoesNotTransition() async throws {
        let target = SpyPreviewTransitionTarget()
        let camera = Camera.makeForTesting()
        camera.previewTransitionTarget = target

        try await camera.updateConfiguration(camera.configuration.position(.front))

        #expect(camera.configuration.position == .front)
        #expect(target.beginCount == 0)
        #expect(target.endCount == 0)
    }

    @Test("A failed reconfiguration still uncovers the preview")
    func failedReconfigurationEndsTransition() async throws {
        let engine = FakeCameraEngine()
        let target = SpyPreviewTransitionTarget()
        let camera = Camera.makeForTesting(engine: engine)
        camera.previewTransitionTarget = target
        try await camera.start()
        await engine.setApplyError(CameraError.deviceUnavailable(position: .front))

        await #expect(throws: (any Error).self) {
            try await camera.updateConfiguration(camera.configuration.position(.front))
        }

        #expect(target.beginCount == 1)
        #expect(target.endCount == 1)
    }
}
