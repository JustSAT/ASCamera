import Foundation
import Testing
@testable import ASCamera

@MainActor
@Suite("Recording lifecycle")
struct RecordingLifecycleTests {
    private func makeResult(seconds: Int64 = 5) -> RecordingResult {
        RecordingResult(
            url: URL(fileURLWithPath: "/tmp/test.mov"),
            duration: .seconds(seconds),
            fileSize: 1234
        )
    }

    @Test("start transitions idle -> running")
    func startRunning() async throws {
        let camera = Camera.makeForTesting()
        #expect(camera.state == .idle)
        try await camera.start()
        #expect(camera.state == .running)
    }

    @Test("startRecording transitions running -> recording and invokes the engine")
    func startRecording() async throws {
        let engine = FakeCameraEngine()
        let camera = Camera.makeForTesting(engine: engine)
        try await camera.start()
        try await camera.startRecording()
        #expect(camera.state == .recording)
        #expect(await engine.startRecordingCount == 1)
        #expect(await engine.lastRecordingURL != nil)
    }

    @Test("Double startRecording throws recordingAlreadyInProgress")
    func doubleStart() async throws {
        let camera = Camera.makeForTesting()
        try await camera.start()
        try await camera.startRecording()
        await #expect(throws: CameraError.recordingAlreadyInProgress) {
            try await camera.startRecording()
        }
        #expect(camera.state == .recording)
    }

    @Test("startRecording before start throws sessionNotRunning")
    func recordBeforeStart() async {
        let camera = Camera.makeForTesting()
        await #expect(throws: CameraError.sessionNotRunning) {
            try await camera.startRecording()
        }
    }

    @Test("stopRecording without an active recording throws noRecordingInProgress")
    func stopWithoutRecording() async throws {
        let camera = Camera.makeForTesting()
        try await camera.start()
        await #expect(throws: CameraError.noRecordingInProgress) {
            _ = try await camera.stopRecording()
        }
    }

    @Test("stopRecording returns the engine result and returns to running")
    func stopReturnsResult() async throws {
        let engine = FakeCameraEngine()
        let expected = makeResult(seconds: 7)
        await engine.setResultOnStop(expected)
        let camera = Camera.makeForTesting(engine: engine)
        try await camera.start()
        try await camera.startRecording()

        let result = try await camera.stopRecording()
        #expect(result == expected)
        #expect(camera.state == .running)
        #expect(camera.lastRecordingResult == expected)
        #expect(await engine.stopRecordingCount == 1)
    }

    @Test("Custom output URL is forwarded to the engine")
    func customOutputURL() async throws {
        let engine = FakeCameraEngine()
        let camera = Camera.makeForTesting(engine: engine)
        try await camera.start()
        let url = URL(fileURLWithPath: "/tmp/custom-output.mov")
        try await camera.startRecording(outputURL: url)
        #expect(await engine.lastRecordingURL == url)
    }

    @Test("Engine failure on startRecording reverts state to running")
    func startRecordingEngineFailure() async throws {
        let engine = FakeCameraEngine()
        await engine.setStartRecordingError(.recordingFailed(reason: "boom"))
        let camera = Camera.makeForTesting(engine: engine)
        try await camera.start()
        await #expect(throws: CameraError.recordingFailed(reason: "boom")) {
            try await camera.startRecording()
        }
        #expect(camera.state == .running)
    }
}
