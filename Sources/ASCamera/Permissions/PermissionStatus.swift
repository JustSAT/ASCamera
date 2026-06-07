import Foundation

/// The authorization status for a capture media type (camera or microphone).
public enum PermissionStatus: Sendable, Equatable {
    /// The user has not yet been asked.
    case notDetermined
    /// Access is granted.
    case authorized
    /// The user explicitly denied access.
    case denied
    /// Access is restricted by system policy (e.g. parental controls) and cannot be granted.
    case restricted

    /// Whether capture is permitted in this state.
    public var isAuthorized: Bool {
        self == .authorized
    }
}

/// A capture media type whose authorization can be queried/requested.
enum CameraMediaType: Sendable, Equatable {
    case video
    case audio
}
