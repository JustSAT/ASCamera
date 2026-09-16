import Foundation

/// A preview surface that can hide a break in the camera feed behind a frozen frame.
///
/// Swapping the capture device tears the video input out of the running session, so the preview
/// receives no frames until the new one is wired up and simply goes black. ``Camera`` drives the
/// two ends of that gap through this protocol; ``CameraPreviewUIView`` implements it by freezing
/// the last frame, blurring it, and cross-fading into the new feed.
@MainActor
protocol PreviewTransitioning: AnyObject {

    /// Called while the feed is still live, immediately before it is interrupted.
    func beginPreviewTransition()

    /// Called once the session has been reconfigured and frames are about to resume.
    func endPreviewTransition()
}
