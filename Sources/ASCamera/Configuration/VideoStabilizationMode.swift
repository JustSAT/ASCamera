import AVFoundation

/// Video stabilization to apply to recorded video.
///
/// If a mode is not supported by the active device/format, the library falls back to the
/// device's preferred behavior rather than failing.
public enum VideoStabilizationMode: Sendable, Equatable, CaseIterable, CustomStringConvertible {
    /// No stabilization.
    case off
    /// Standard stabilization.
    case standard
    /// Cinematic stabilization (higher quality, more latency).
    case cinematic
    /// Extended cinematic stabilization.
    case cinematicExtended
    /// Let the system choose the most appropriate mode.
    case auto

    public var description: String {
        switch self {
        case .off: return "off"
        case .standard: return "standard"
        case .cinematic: return "cinematic"
        case .cinematicExtended: return "cinematicExtended"
        case .auto: return "auto"
        }
    }

    /// The AVFoundation stabilization mode this maps to.
    var avStabilizationMode: AVCaptureVideoStabilizationMode {
        switch self {
        case .off: return .off
        case .standard: return .standard
        case .cinematic: return .cinematic
        case .cinematicExtended: return .cinematicExtended
        case .auto: return .auto
        }
    }
}
