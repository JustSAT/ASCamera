import Foundation

/// A requested capture frame rate, in frames per second.
///
/// Common rates are provided as presets, but any positive value can be requested. The library
/// validates the requested rate against the active device format at configuration time and selects
/// the closest supported format; unsupported rates surface as
/// ``CameraError/unsupportedConfiguration(reason:)``.
public struct FrameRate: Sendable, Equatable, Comparable, ExpressibleByIntegerLiteral, CustomStringConvertible {
    /// The requested frames-per-second value.
    public let fps: Double

    public init(_ fps: Double) {
        self.fps = max(1, fps)
    }

    public init(integerLiteral value: Int) {
        self.init(Double(value))
    }

    public static let fps24 = FrameRate(24)
    public static let fps30 = FrameRate(30)
    public static let fps60 = FrameRate(60)
    public static let fps120 = FrameRate(120)
    public static let fps240 = FrameRate(240)

    public static func < (lhs: FrameRate, rhs: FrameRate) -> Bool {
        lhs.fps < rhs.fps
    }

    public var description: String {
        "\(Int(fps)) fps"
    }
}
