import Foundation
import Testing
@testable import ASCamera

@MainActor
@Suite("Maximum duration auto-stop")
struct MaximumDurationAutoStopTests {
    @Test("Maximum recording duration is forwarded to the engine")
    func maximumForwardedToEngine() async throws {
        let engine = FakeCameraEngine()
        let config = CameraConfiguration().maximumRecordingDuration(.seconds(30))
        let camera = Camera.makeForTesting(configuration: config, engine: engine)
        try await camera.start()
        try await camera.startRecording()
        #expect(await engine.lastConfiguration?.maximumRecordingDuration == .seconds(30))
    }

    @Test("Auto-stop delivers a normal result via the finished stream and returns to running")
    func autoStopDeliversResult() async throws {
        let engine = FakeCameraEngine()
        let config = CameraConfiguration().maximumRecordingDuration(.seconds(2))
        let camera = Camera.makeForTesting(configuration: config, engine: engine)
        try await camera.start()
        try await camera.startRecording()
        #expect(camera.state == .recording)

        let finishedStream = camera.recordingFinishedStream()
        let result = RecordingResult(
            url: URL(fileURLWithPath: "/tmp/auto.mov"),
            duration: .seconds(2),
            fileSize: 4096
        )
        // Simulate the engine auto-finishing on reaching the maximum duration (no stopRecording call).
        engine.emit(.recordingFinished(result))

        var received: RecordingResult?
        for await finished in finishedStream {
            received = finished
            break
        }

        #expect(received == result)
        #expect(camera.state == .running)
        #expect(camera.lastRecordingResult == result)
        #expect(camera.currentRecordingDuration == .seconds(2))
        // The library stopped automatically — the consumer never called stopRecording.
        #expect(await engine.stopRecordingCount == 0)
    }
}
