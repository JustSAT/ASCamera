import SwiftUI

/// The example's landing screen. Pushes the two recorder layouts and the recordings library.
struct HomeView: View {
    @Environment(RecordingsStore.self) private var store
    @Bindable private var orientation = InterfaceOrientationController.shared

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Toggle("Lock app interface to portrait", isOn: $orientation.isLockedToPortrait)
                } header: {
                    Text("Host app orientation")
                } footer: {
                    Text("Locks the whole app's interface to portrait, like a real host app. Use it to check how the camera behaves when the host app's orientation is restricted. (Rotate a real device; the Simulator has no accelerometer.)")
                }

                Section {
                    NavigationLink {
                        FullScreenRecorderView()
                    } label: {
                        Label {
                            VStack(alignment: .leading) {
                                Text("Full-Screen Recorder").font(.headline)
                                Text("Edge-to-edge preview · back camera · follows device orientation · 60s max")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        } icon: {
                            Image(systemName: "viewfinder")
                        }
                    }

                    NavigationLink {
                        CardRecorderView()
                    } label: {
                        Label {
                            VStack(alignment: .leading) {
                                Text("Card Recorder").font(.headline)
                                Text("Framed card preview · front camera · locked portrait · 15s max")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        } icon: {
                            Image(systemName: "rectangle.on.rectangle.angled")
                        }
                    }
                } header: {
                    Text("Recorder layouts")
                } footer: {
                    Text("Two different UIs built on the same ASCamera library. Each recording embeds the start time into the video file.")
                }

                Section("Library") {
                    NavigationLink {
                        RecordingsListView()
                    } label: {
                        Label("Recordings (\(store.recordings.count))", systemImage: "film.stack")
                    }
                }
            }
            .navigationTitle("ASCamera")
            .onAppear { store.reload() }
        }
    }
}
