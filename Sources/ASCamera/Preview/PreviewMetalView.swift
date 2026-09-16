#if canImport(UIKit)
import AVFoundation
import UIKit

/// A `UIView` whose backing layer is an `AVCaptureVideoPreviewLayer`, so the live camera feed is
/// rendered efficiently and resizes automatically with the view.
///
/// This is the `UIViewType` vended by ``CameraPreview`` and is public only to satisfy
/// `UIViewRepresentable`'s visibility requirements; it is an implementation detail and should not
/// be constructed directly.
public final class CameraPreviewUIView: UIView {
    /// The camera whose interface-orientation angle this view applies. Weak: the view is owned by
    /// SwiftUI, the camera by the consumer.
    weak var camera: Camera?

    public override class var layerClass: AnyClass {
        AVCaptureVideoPreviewLayer.self
    }

    /// The backing preview layer. Optional to avoid a force cast; `layerClass` guarantees the type.
    var previewLayer: AVCaptureVideoPreviewLayer? {
        layer as? AVCaptureVideoPreviewLayer
    }

    /// The frozen frame covering the feed while the capture device is swapped.
    private var transitionCover: UIView?

    private static let blurInDuration: TimeInterval = 0.12
    private static let fadeOutDuration: TimeInterval = 0.28
    /// The reconfigured session reports back before its first frames reach the layer, so the
    /// cover is held a moment longer — uncovering immediately reveals a still-black layer.
    private static let settleDelay: TimeInterval = 0.15

    public override func layoutSubviews() {
        super.layoutSubviews()
        applyInterfaceOrientation()
    }

    /// Applies the camera's current interface-orientation angle to the preview connection. Called on
    /// layout (which fires when the interface rotates) and by ``CameraPreview`` on update.
    ///
    /// Layout is also the most reliable signal the library gets that the interface has rotated, so
    /// this is where the camera is asked to refresh the angle it hands to the capture session —
    /// otherwise a rotation the device never physically performed would keep the preview and the
    /// recording out of sync (see ``Camera/refreshOrientationIfNeeded()``).
    func applyInterfaceOrientation() {
        guard let camera, let connection = previewLayer?.connection else { return }
        let angle = camera.currentInterfaceRotationAngle
        if connection.isVideoRotationAngleSupported(angle) {
            connection.videoRotationAngle = angle
        }
        camera.refreshOrientationIfNeeded()
    }
}

// MARK: - Preview transition

extension CameraPreviewUIView: PreviewTransitioning {

    func beginPreviewTransition() {
        // A cover still fading out from a previous switch would be captured by the snapshot.
        transitionCover?.removeFromSuperview()
        transitionCover = nil

        guard let frozenFrame = snapshotView(afterScreenUpdates: false) else { return }

        let cover = UIView(frame: bounds)
        cover.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        cover.backgroundColor = .black

        frozenFrame.frame = cover.bounds
        frozenFrame.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        cover.addSubview(frozenFrame)

        let blur = UIVisualEffectView(effect: nil)
        blur.frame = cover.bounds
        blur.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        cover.addSubview(blur)

        addSubview(cover)
        transitionCover = cover

        UIView.animate(withDuration: Self.blurInDuration) {
            blur.effect = UIBlurEffect(style: .systemThinMaterialDark)
        }
    }

    func endPreviewTransition() {
        guard let cover = transitionCover else { return }
        transitionCover = nil
        UIView.animate(
            withDuration: Self.fadeOutDuration,
            delay: Self.settleDelay,
            options: [.curveEaseOut],
            animations: { cover.alpha = 0 },
            completion: { _ in cover.removeFromSuperview() }
        )
    }
}
#endif
