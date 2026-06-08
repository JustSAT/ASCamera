import ASCamera
import SwiftUI

/// Layout #1 — a classic, edge-to-edge camera with a floating control overlay.
struct FullScreenRecorderView: View {
    @Environment(RecordingsStore.self) private var store

    @State private var camera = Camera(
        configuration: CameraConfiguration()
            .position(.back)
            .frameRate(.fps30)
            .resolution(.fullHD)
            .orientation(.device)
            .maximumRecordingDuration(.seconds(60))
    )
    @State private var duration: Duration = .zero
    @State private var errorMessage: String?

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if camera.state == .permissionDenied {
                CameraPermissionErrorView(missing: missingPermission)
            } else {
                CameraPreview(camera: camera)
                    .ignoresSafeArea()
                overlay
            }
        }
        .navigationTitle("Full-Screen")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .task { await startCamera() }
        .task {
            for await value in camera.recordingDurationStream() {
                duration = value
            }
        }
        .task {
            for await result in camera.recordingFinishedStream() {
                store.add(result)
            }
        }
        .onDisappear {
            Task { await camera.stop() }
        }
        .alert("Camera Error", isPresented: .constant(errorMessage != nil)) {
            Button("OK") { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "")
        }
    }

    private var overlay: some View {
        VStack {
            HStack(alignment: .top) {
                if camera.state.isRecording {
                    Label(duration.clockString, systemImage: "circle.fill")
                        .font(.subheadline.monospacedDigit().bold())
                        .foregroundStyle(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 7)
                        .background(.red, in: Capsule())
                }
                Spacer()
                Button {
                    Task { await switchCamera() }
                } label: {
                    Image(systemName: "arrow.triangle.2.circlepath.camera.fill")
                        .font(.title2)
                        .foregroundStyle(.white)
                        .padding(12)
                        .background(.ultraThinMaterial, in: Circle())
                }
                .disabled(camera.state.isRecording)
                .opacity(camera.state.isRecording ? 0.4 : 1)
            }
            .padding()

            Spacer()

            ShutterButton(isRecording: camera.state.isRecording) {
                Task { await toggleRecording() }
            }
            .disabled(!canToggle)
            .padding(.bottom, 36)
        }
    }

    private var canToggle: Bool {
        camera.state == .running || camera.state.isRecording
    }

    private var missingPermission: CameraPermissionErrorView.MissingPermission {
        PermissionHelper.missing(camera: camera)
    }

    private func startCamera() async {
        do {
            try await camera.start()
        } catch let error as CameraError where error == .cameraPermissionDenied || error == .microphonePermissionDenied {
            // The permission screen is shown via state; no alert needed.
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func toggleRecording() async {
        do {
            if camera.state.isRecording {
                _ = try await camera.stopRecording()
                // Release the orientation lock now that recording has finished.
                InterfaceOrientationController.shared.unlock()
            } else {
                // Lock the interface to the current orientation *before* recording starts, so the
                // camera (which follows the interface orientation) stays fixed for the whole take.
                InterfaceOrientationController.shared.lockToCurrent()
                let url = RecordingsStore.makeRecordingURL(start: Date())
                try await camera.startRecording(outputURL: url)
            }
        } catch {
            // If starting failed, don't leave the interface stuck locked.
            InterfaceOrientationController.shared.unlock()
            errorMessage = error.localizedDescription
        }
    }

    private func switchCamera() async {
        var config = camera.configuration
        config.position = config.position.toggled
        try? await camera.updateConfiguration(config)
    }
}
