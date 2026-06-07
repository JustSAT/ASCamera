import SwiftUI

@main
struct ASCameraExampleApp: App {
    @State private var store = RecordingsStore()

    var body: some Scene {
        WindowGroup {
            HomeView()
                .environment(store)
        }
    }
}
