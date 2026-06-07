import Foundation

/// How the preview and recorded video orientation are determined.
public enum OrientationStrategy: Sendable, Equatable, CaseIterable, CustomStringConvertible {
    /// Follow the physical device orientation (default).
    case device
    /// Lock to portrait regardless of device rotation.
    case lockedPortrait
    /// Lock to landscape-left regardless of device rotation.
    case lockedLandscapeLeft
    /// Lock to landscape-right regardless of device rotation.
    case lockedLandscapeRight

    /// Whether this strategy ignores physical device rotation.
    public var isLocked: Bool {
        self != .device
    }

    public var description: String {
        switch self {
        case .device: return "device"
        case .lockedPortrait: return "lockedPortrait"
        case .lockedLandscapeLeft: return "lockedLandscapeLeft"
        case .lockedLandscapeRight: return "lockedLandscapeRight"
        }
    }
}
