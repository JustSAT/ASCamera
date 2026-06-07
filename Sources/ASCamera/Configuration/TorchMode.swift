import AVFoundation

/// The torch (flashlight) behavior during capture.
///
/// If the active device has no torch, the requested mode is ignored and capture continues
/// normally — the library fails gracefully rather than throwing.
public enum TorchMode: Sendable, Equatable, CaseIterable, CustomStringConvertible {
    /// Torch is always off.
    case off
    /// Torch is always on.
    case on
    /// The system decides based on ambient light.
    case auto

    public var description: String {
        switch self {
        case .off: return "off"
        case .on: return "on"
        case .auto: return "auto"
        }
    }

    /// The AVFoundation torch mode this maps to.
    var avTorchMode: AVCaptureDevice.TorchMode {
        switch self {
        case .off: return .off
        case .on: return .on
        case .auto: return .auto
        }
    }
}
