#if canImport(UIKit)
import AVFoundation
import SwiftUI

/// A SwiftUI view that displays the live camera output for a ``Camera``.
///
/// This view *only* renders the preview — it contains no buttons, overlays, or controls. Consumers
/// compose their own UI on top of it.
///
/// ```swift
/// CameraPreview(camera: camera)
///     .ignoresSafeArea()
/// ```
public struct CameraPreview: UIViewRepresentable {
    private let camera: Camera
    private let videoGravity: AVLayerVideoGravity

    /// Creates a preview bound to the given camera.
    /// - Parameters:
    ///   - camera: The camera whose output to display.
    ///   - videoGravity: How the video fills the view. Defaults to `.resizeAspectFill`.
    public init(camera: Camera, videoGravity: AVLayerVideoGravity = .resizeAspectFill) {
        self.camera = camera
        self.videoGravity = videoGravity
    }

    public func makeUIView(context: Context) -> CameraPreviewUIView {
        let view = CameraPreviewUIView()
        view.backgroundColor = .black
        view.previewLayer?.videoGravity = videoGravity
        configure(view)
        return view
    }

    public func updateUIView(_ view: CameraPreviewUIView, context: Context) {
        view.previewLayer?.videoGravity = videoGravity
        configure(view)
    }

    /// Associates the session and applies the current preview rotation angle. Reading
    /// `camera.previewRotationAngle` here registers SwiftUI observation, so the preview re-orients
    /// automatically when the angle changes.
    private func configure(_ view: CameraPreviewUIView) {
        view.camera = camera
        guard let previewLayer = view.previewLayer else { return }
        if let box = camera.captureSessionBox, previewLayer.session !== box.value {
            previewLayer.session = box.value
        }
        view.applyInterfaceOrientation()
    }
}
#endif
