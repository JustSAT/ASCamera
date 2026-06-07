import Foundation
import Observation
import Testing
@testable import ASCamera

/// A minimal thread-safe flag for capturing `withObservationTracking`'s `@Sendable` onChange.
private final class Flag: @unchecked Sendable {
    private let lock = NSLock()
    private var value = false
    func raise() { lock.withLock { value = true } }
    var isRaised: Bool { lock.withLock { value } }
}

@MainActor
@Suite("Observation")
struct ObservationTests {
    /// Regression guard: `camera.state` must notify Observation when it changes, otherwise SwiftUI
    /// views (e.g. a record button gated on `state == .running`) never refresh.
    @Test("state changes are observable")
    func stateIsObservable() async throws {
        let camera = Camera.makeForTesting()
        let flag = Flag()
        withObservationTracking {
            _ = camera.state
        } onChange: {
            flag.raise()
        }

        try await camera.start()
        #expect(camera.state == .running)
        #expect(flag.isRaised)
    }

    /// `currentRecordingDuration` must also be observable for timer UIs.
    @Test("currentRecordingDuration changes are observable")
    func durationIsObservable() async throws {
        let engine = FakeCameraEngine()
        let camera = Camera.makeForTesting(engine: engine)
        try await camera.start()
        try await camera.startRecording()

        let flag = Flag()
        withObservationTracking {
            _ = camera.currentRecordingDuration
        } onChange: {
            flag.raise()
        }

        engine.emit(.recordingProgress(.seconds(1)))
        // Allow the main-actor event consumer to process the emitted progress event.
        for await duration in camera.recordingDurationStream() where duration == .seconds(1) { break }
        #expect(flag.isRaised)
    }
}
