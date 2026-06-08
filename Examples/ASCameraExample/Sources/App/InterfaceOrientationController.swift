import SwiftUI

/// Drives the app's allowed interface orientations at runtime.
///
/// Two independent uses:
/// - `isLockedToPortrait` — a manual demo toggle to mimic a portrait-locked host app.
/// - `lockToCurrent()` / `unlock()` — the recommended **lock-on-record** pattern: freeze the
///   interface to the current orientation while recording, so the camera (which follows the
///   interface orientation) stays fixed for the whole take, then release it on stop.
@MainActor
@Observable
final class InterfaceOrientationController {
    /// Shared instance read by `AppDelegate.application(_:supportedInterfaceOrientationsFor:)`.
    static let shared = InterfaceOrientationController()

    /// When `true`, the whole app interface is locked to portrait (manual demo toggle).
    var isLockedToPortrait = false {
        didSet { applyToActiveScene() }
    }

    /// When non-nil, the interface is frozen to this mask (used by the lock-on-record pattern).
    /// Takes precedence over `isLockedToPortrait`.
    private var lockedMask: UIInterfaceOrientationMask?

    /// The mask reported to UIKit. Intersected with `UISupportedInterfaceOrientations` from the
    /// Info.plist, so `.all` effectively means "portrait + both landscapes" here.
    var supportedMask: UIInterfaceOrientationMask {
        if let lockedMask { return lockedMask }
        return isLockedToPortrait ? .portrait : .all
    }

    /// Locks the interface to whatever orientation is active right now. Call **before**
    /// `startRecording` so the orientation is fixed before the first recorded frame.
    func lockToCurrent() {
        guard let scene = activeScene else { return }
        lockedMask = scene.interfaceOrientation.toMask
        apply(to: scene)
    }

    /// Releases the lock-on-record lock. Call on record stop.
    func unlock() {
        lockedMask = nil
        if let scene = activeScene { apply(to: scene) }
    }

    private var activeScene: UIWindowScene? {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first
    }

    private func applyToActiveScene() {
        guard let scene = activeScene else { return }
        apply(to: scene)
    }

    private func apply(to scene: UIWindowScene) {
        scene.keyWindow?.rootViewController?.setNeedsUpdateOfSupportedInterfaceOrientations()
        scene.requestGeometryUpdate(.iOS(interfaceOrientations: supportedMask)) { _ in
            // A geometry update can fail (e.g. requesting an orientation UIKit currently disallows);
            // it's non-fatal for this demo, so we ignore the error.
        }
    }
}

private extension UIInterfaceOrientation {
    /// The single-orientation mask matching this interface orientation.
    var toMask: UIInterfaceOrientationMask {
        switch self {
        case .portrait: return .portrait
        case .portraitUpsideDown: return .portraitUpsideDown
        case .landscapeLeft: return .landscapeLeft
        case .landscapeRight: return .landscapeRight
        default: return .portrait
        }
    }
}
