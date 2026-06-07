import CoreGraphics
import Foundation

/// A device physical orientation, decoupled from UIKit so the mapping logic stays pure and
/// unit-testable.
enum DeviceOrientation: Sendable, Equatable {
    case portrait
    case portraitUpsideDown
    case landscapeLeft
    case landscapeRight
    /// Face up/down or genuinely unknown — callers should fall back to a sensible default.
    case unknown
}

/// Resolves an ``OrientationStrategy`` (plus the current device orientation) into the clockwise
/// video rotation angle, in degrees, expected by `AVCaptureConnection.videoRotationAngle`.
///
/// This type is intentionally pure (no AVFoundation, no UIKit, no shared state) so the orientation
/// rules can be exhaustively unit tested. The chosen convention is:
///
/// | Orientation          | Angle |
/// |----------------------|-------|
/// | portrait             | 90°   |
/// | portrait upside down | 270°  |
/// | landscape left       | 180°  |
/// | landscape right      | 0°    |
///
/// Locked strategies always return their fixed angle and ignore the device orientation, which is
/// what guarantees the preview *and* the exported video stay fixed regardless of how the device is
/// physically rotated.
enum OrientationResolver {
    static let portraitAngle: CGFloat = 90
    static let portraitUpsideDownAngle: CGFloat = 270
    static let landscapeLeftAngle: CGFloat = 180
    static let landscapeRightAngle: CGFloat = 0

    /// The rotation angle (degrees, clockwise) for the given strategy and device orientation.
    static func rotationAngle(
        for strategy: OrientationStrategy,
        deviceOrientation: DeviceOrientation
    ) -> CGFloat {
        switch strategy {
        case .lockedPortrait:
            return portraitAngle
        case .lockedLandscapeLeft:
            return landscapeLeftAngle
        case .lockedLandscapeRight:
            return landscapeRightAngle
        case .device:
            return angle(for: deviceOrientation)
        }
    }

    private static func angle(for orientation: DeviceOrientation) -> CGFloat {
        switch orientation {
        case .portrait:
            return portraitAngle
        case .portraitUpsideDown:
            return portraitUpsideDownAngle
        case .landscapeLeft:
            return landscapeLeftAngle
        case .landscapeRight:
            return landscapeRightAngle
        case .unknown:
            // Default to portrait when the physical orientation can't be determined.
            return portraitAngle
        }
    }
}
