import Foundation

/// A pure, value-type validator for ``CameraState`` transitions.
///
/// This type contains no AVFoundation or concurrency dependencies, which makes the safety-critical
/// transition rules (preventing double-start, stop-when-not-recording, etc.) fully unit testable in
/// isolation. ``Camera`` owns one instance on the main actor and consults it before performing any
/// state-changing operation.
struct CameraStateMachine: Sendable {
    /// The current state. Mutated only through the validated `apply` helpers.
    private(set) var state: CameraState

    init(state: CameraState = .idle) {
        self.state = state
    }

    // MARK: - Guards

    /// Whether `start()` may be invoked from the current state.
    var canStart: Bool {
        switch state {
        case .idle, .permissionDenied, .failed:
            return true
        case .starting, .running, .recording, .stoppingRecording:
            return false
        }
    }

    /// Whether `startRecording()` may be invoked from the current state.
    var canStartRecording: Bool {
        state == .running
    }

    /// Whether `stopRecording()` may be invoked from the current state.
    var canStopRecording: Bool {
        state == .recording
    }

    // MARK: - Validated transitions

    /// Validates and performs the transition into `.starting`.
    mutating func beginStarting() throws {
        guard canStart else { throw invalidTransition("start") }
        state = .starting
    }

    /// Marks the session as running after a successful start.
    mutating func markRunning() {
        state = .running
    }

    /// Validates and performs the transition into `.recording`.
    ///
    /// - Throws: ``CameraError/recordingAlreadyInProgress`` if a recording is already active,
    ///   or ``CameraError/sessionNotRunning`` if the session is not running.
    mutating func beginRecording() throws {
        switch state {
        case .running:
            state = .recording
        case .recording, .stoppingRecording:
            throw CameraError.recordingAlreadyInProgress
        default:
            throw CameraError.sessionNotRunning
        }
    }

    /// Validates and performs the transition into `.stoppingRecording`.
    ///
    /// - Throws: ``CameraError/noRecordingInProgress`` if no recording is active.
    mutating func beginStoppingRecording() throws {
        guard state == .recording else { throw CameraError.noRecordingInProgress }
        state = .stoppingRecording
    }

    /// Marks the recording as finished, returning the session to `.running`.
    mutating func finishRecording() {
        state = .running
    }

    /// Transitions to `.permissionDenied`.
    mutating func markPermissionDenied() {
        state = .permissionDenied
    }

    /// Transitions to `.failed` carrying the given error.
    mutating func markFailed(_ error: CameraError) {
        state = .failed(error)
    }

    /// Transitions to `.idle` (fully stopped).
    mutating func markIdle() {
        state = .idle
    }

    private func invalidTransition(_ operation: String) -> CameraError {
        .unknown(reason: "Cannot \(operation) from state \(state).")
    }
}
