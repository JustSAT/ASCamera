import Foundation

/// The observable lifecycle state of a ``Camera``.
///
/// State changes are published through the `@Observable` ``Camera`` and can be observed directly
/// from SwiftUI. The valid transitions are:
///
/// ```text
///                         ┌─────────────────────────────┐
///                         ▼                             │
///   idle ──start()──▶ starting ──▶ running ──startRecording()──▶ recording
///     ▲                  │            ▲  │                            │
///     │                  │            │  └──────stopRecording()───────┤
///     │                  │            │                               ▼
///     │                  │            └──────────────────────  stoppingRecording
///     │                  │
///     │            (permission)        any state on fatal error ──▶ failed(error)
///     └── stop() ◀───────┴────────────────────────────────────────────┘
///                        │
///                        └── permission missing ──▶ permissionDenied
/// ```
public enum CameraState: Sendable, Equatable {
    /// The session has not been started yet (initial state), or has been fully stopped.
    case idle
    /// The session is being configured and started.
    case starting
    /// The session is running and the preview is live, but not recording.
    case running
    /// A recording is currently in progress.
    case recording
    /// A recording is being finalized and written to disk.
    case stoppingRecording
    /// Camera and/or microphone permission is not granted.
    case permissionDenied
    /// The session entered an unrecoverable error state.
    case failed(CameraError)

    /// Whether the camera preview is expected to display live frames in this state.
    public var isPreviewActive: Bool {
        switch self {
        case .running, .recording, .stoppingRecording:
            return true
        case .idle, .starting, .permissionDenied, .failed:
            return false
        }
    }

    /// Whether a recording is actively capturing frames in this state.
    ///
    /// This is `true` only for ``recording``. While a recording is being finalized to disk
    /// (``stoppingRecording``) it is `false`, so UI bound to it clears the recording indicator the
    /// instant the user stops, rather than waiting for the file to finish writing.
    public var isRecording: Bool {
        self == .recording
    }

    /// Whether a recording session exists, including while it is being finalized to disk.
    ///
    /// Internal: drives teardown/finish logic that must also run during ``stoppingRecording``,
    /// where the public ``isRecording`` is already `false`.
    var hasActiveRecording: Bool {
        switch self {
        case .recording, .stoppingRecording:
            return true
        case .idle, .starting, .running, .permissionDenied, .failed:
            return false
        }
    }
}
