import CoreMedia
import Foundation

/// A requested capture resolution.
///
/// Resolutions are expressed as semantic presets and mapped internally to concrete pixel
/// dimensions used to select an `AVCaptureDevice.Format`.
public enum Resolution: Sendable, Equatable, CaseIterable, CustomStringConvertible {
    /// 1280 × 720 (720p).
    case hd
    /// 1920 × 1080 (1080p).
    case fullHD
    /// 3840 × 2160 (2160p / 4K UHD).
    case uhd4K

    public var description: String {
        switch self {
        case .hd: return "HD (720p)"
        case .fullHD: return "Full HD (1080p)"
        case .uhd4K: return "UHD 4K (2160p)"
        }
    }

    /// The target pixel dimensions (width × height) for this resolution.
    var dimensions: CMVideoDimensions {
        switch self {
        case .hd: return CMVideoDimensions(width: 1280, height: 720)
        case .fullHD: return CMVideoDimensions(width: 1920, height: 1080)
        case .uhd4K: return CMVideoDimensions(width: 3840, height: 2160)
        }
    }

    /// Total pixel count, used to rank candidate device formats.
    var pixelCount: Int {
        let dimensions = self.dimensions
        return Int(dimensions.width) * Int(dimensions.height)
    }
}
