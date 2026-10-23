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

    /// The rotation angle (degrees, clockwise) for the given strategy and device orientation, as
    /// seen by the back camera. Use ``rotationAngle(for:deviceOrientation:position:)`` for a
    /// connection fed by a concrete camera.
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

    /// The rotation angle (degrees, clockwise) for the preview and recording connections of the
    /// camera at `position`. The front sensor is mounted opposite to the back one, so its
    /// landscape angles are swapped — reusing the back-camera angle turns landscape front-camera
    /// frames upside down. Preview mirroring only flips horizontally, so the preview needs the
    /// same angle as the recording.
    static func rotationAngle(
        for strategy: OrientationStrategy,
        deviceOrientation: DeviceOrientation,
        position: CameraPosition
    ) -> CGFloat {
        let angle = rotationAngle(for: strategy, deviceOrientation: deviceOrientation)
        guard position == .front else { return angle }
        switch angle {
        case landscapeLeftAngle:
            return landscapeRightAngle
        case landscapeRightAngle:
            return landscapeLeftAngle
        default:
            return angle
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
