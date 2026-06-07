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
    public override class var layerClass: AnyClass {
        AVCaptureVideoPreviewLayer.self
    }

    /// The backing preview layer. Optional to avoid a force cast; `layerClass` guarantees the type.
    var previewLayer: AVCaptureVideoPreviewLayer? {
        layer as? AVCaptureVideoPreviewLayer
    }
}
#endif
