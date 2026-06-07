import Foundation
import Testing
@testable import ASCamera

@MainActor
@Suite("Recording duration tracking")
struct DurationTrackingTests {
    @Test("Duration starts at zero when recording begins")
    func startsAtZero() async throws {
        let camera = Camera.makeForTesting()
        try await camera.start()
        try await camera.startRecording()
        #expect(camera.currentRecordingDuration == .zero)
    }

    @Test("Duration updates continuously from engine progress events")
    func updatesFromProgress() async throws {
        let engine = FakeCameraEngine()
        let camera = Camera.makeForTesting(engine: engine)
        try await camera.start()
        try await camera.startRecording()

        let stream = camera.recordingDurationStream()
        engine.emit(.recordingProgress(.seconds(1)))
        engine.emit(.recordingProgress(.seconds(2)))
        engine.emit(.recordingProgress(.seconds(3)))

        var latest: Duration = .zero
        for await duration in stream {
            latest = duration
            if duration == .seconds(3) { break }
        }
        #expect(latest == .seconds(3))
        #expect(camera.currentRecordingDuration == .seconds(3))
    }

    @Test("Duration resets to zero when recording stops")
    func resetsOnStop() async throws {
        let engine = FakeCameraEngine()
        await engine.setResultOnStop(
            RecordingResult(url: URL(fileURLWithPath: "/tmp/a.mov"), duration: .seconds(8), fileSize: 1)
        )
        let camera = Camera.makeForTesting(engine: engine)
        try await camera.start()
        try await camera.startRecording()
        engine.emit(.recordingProgress(.seconds(8)))
        let result = try await camera.stopRecording()

        // The live counter resets to zero once recording stops...
        #expect(camera.currentRecordingDuration == .zero)
        // ...while the finished recording's duration remains available on the result.
        #expect(result.duration == .seconds(8))
        #expect(camera.lastRecordingResult?.duration == .seconds(8))

        // A new recording also starts from zero.
        try await camera.startRecording()
        #expect(camera.currentRecordingDuration == .zero)
    }

    @Test("Duration stream yields its current value on subscription")
    func yieldsCurrentValueImmediately() async throws {
        let engine = FakeCameraEngine()
        let camera = Camera.makeForTesting(engine: engine)
        try await camera.start()
        try await camera.startRecording()
        engine.emit(.recordingProgress(.seconds(5)))

        // Drain to the latest known value, then a fresh subscription should start there.
        let firstStream = camera.recordingDurationStream()
        for await duration in firstStream where duration == .seconds(5) { break }

        let lateStream = camera.recordingDurationStream()
        var firstValue: Duration?
        for await duration in lateStream {
            firstValue = duration
            break
        }
        #expect(firstValue == .seconds(5))
    }
}
