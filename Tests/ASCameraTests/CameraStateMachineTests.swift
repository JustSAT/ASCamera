import Testing
@testable import ASCamera

@Suite("Camera state machine")
struct CameraStateMachineTests {
    @Test("Can start only from idle, permissionDenied, or failed")
    func canStart() {
        #expect(CameraStateMachine(state: .idle).canStart)
        #expect(CameraStateMachine(state: .permissionDenied).canStart)
        #expect(CameraStateMachine(state: .failed(.cancelled)).canStart)
        #expect(!CameraStateMachine(state: .starting).canStart)
        #expect(!CameraStateMachine(state: .running).canStart)
        #expect(!CameraStateMachine(state: .recording).canStart)
        #expect(!CameraStateMachine(state: .stoppingRecording).canStart)
    }

    @Test("Can start recording only when running")
    func canStartRecording() {
        #expect(CameraStateMachine(state: .running).canStartRecording)
        for state: CameraState in [.idle, .starting, .recording, .stoppingRecording, .permissionDenied] {
            #expect(!CameraStateMachine(state: state).canStartRecording)
        }
    }

    @Test("Can stop recording only when recording")
    func canStopRecording() {
        #expect(CameraStateMachine(state: .recording).canStopRecording)
        for state: CameraState in [.idle, .starting, .running, .stoppingRecording, .permissionDenied] {
            #expect(!CameraStateMachine(state: state).canStopRecording)
        }
    }

    @Test("isRecording is true only while recording, not while stopping")
    func isRecordingExcludesStopping() {
        #expect(CameraState.recording.isRecording)
        #expect(!CameraState.stoppingRecording.isRecording)
        for state: CameraState in [.idle, .starting, .running, .permissionDenied, .failed(.cancelled)] {
            #expect(!state.isRecording)
        }
    }

    @Test("hasActiveRecording covers both recording and stopping")
    func hasActiveRecordingCoversStopping() {
        #expect(CameraState.recording.hasActiveRecording)
        #expect(CameraState.stoppingRecording.hasActiveRecording)
        for state: CameraState in [.idle, .starting, .running, .permissionDenied, .failed(.cancelled)] {
            #expect(!state.hasActiveRecording)
        }
    }

    @Test("Full happy-path transition sequence")
    func happyPath() throws {
        var machine = CameraStateMachine()
        #expect(machine.state == .idle)
        try machine.beginStarting()
        #expect(machine.state == .starting)
        machine.markRunning()
        #expect(machine.state == .running)
        try machine.beginRecording()
        #expect(machine.state == .recording)
        try machine.beginStoppingRecording()
        #expect(machine.state == .stoppingRecording)
        machine.finishRecording()
        #expect(machine.state == .running)
    }

    @Test("Double start recording throws recordingAlreadyInProgress")
    func doubleStartRecording() throws {
        var machine = CameraStateMachine(state: .running)
        try machine.beginRecording()
        #expect(throws: CameraError.recordingAlreadyInProgress) {
            try machine.beginRecording()
        }
        // Also throws while stopping.
        machine = CameraStateMachine(state: .stoppingRecording)
        #expect(throws: CameraError.recordingAlreadyInProgress) {
            try machine.beginRecording()
        }
    }

    @Test("Start recording while not running throws sessionNotRunning")
    func startRecordingNotRunning() {
        var machine = CameraStateMachine(state: .idle)
        #expect(throws: CameraError.sessionNotRunning) {
            try machine.beginRecording()
        }
    }

    @Test("Stop recording when not recording throws noRecordingInProgress")
    func stopWhenNotRecording() {
        var machine = CameraStateMachine(state: .running)
        #expect(throws: CameraError.noRecordingInProgress) {
            try machine.beginStoppingRecording()
        }
    }

    @Test("Permission denied and failed transitions")
    func terminalStates() {
        var machine = CameraStateMachine(state: .starting)
        machine.markPermissionDenied()
        #expect(machine.state == .permissionDenied)
        machine.markFailed(.sessionConfigurationFailed(reason: "x"))
        #expect(machine.state == .failed(.sessionConfigurationFailed(reason: "x")))
        machine.markIdle()
        #expect(machine.state == .idle)
    }
}
