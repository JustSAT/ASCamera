import SwiftUI

@main
struct ASCameraExampleApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @State private var store = RecordingsStore()

    var body: some Scene {
        WindowGroup {
            HomeView()
                .environment(store)
        }
    }
}

/// Bridges UIKit's orientation callback to ``InterfaceOrientationController`` so the example can
/// lock/unlock the app's interface orientation at runtime.
final class AppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        supportedInterfaceOrientationsFor window: UIWindow?
    ) -> UIInterfaceOrientationMask {
        // Called on the main thread by UIKit.
        MainActor.assumeIsolated { InterfaceOrientationController.shared.supportedMask }
    }
}
