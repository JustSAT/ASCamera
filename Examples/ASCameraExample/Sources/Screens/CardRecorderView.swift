import ASCamera
import SwiftUI

/// Layout #2 — a framed "card" preview with the controls laid out below it on a light panel.
/// Uses a different configuration (front camera, locked portrait, shorter max duration) to show
/// the same library powering a very different UI.
struct CardRecorderView: View {
    @Environment(RecordingsStore.self) private var store

    @State private var camera = Camera(
        configuration: CameraConfiguration()
            .position(.front)
            .frameRate(.fps30)
            .resolution(.fullHD)
            .orientation(.lockedPortrait)
            .stabilization(.standard)
            .maximumRecordingDuration(.seconds(15))
    )
    @State private var duration: Duration = .zero
    @State private var errorMessage: String?

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(.systemGray6), Color(.systemGray4)],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            if camera.state == .permissionDenied {
                CameraPermissionErrorView(missing: PermissionHelper.missing(camera: camera))
            } else {
                content
            }
        }
        .navigationTitle("Card Recorder")
        .navigationBarTitleDisplayMode(.inline)
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

    private var content: some View {
        VStack(spacing: 24) {
            Text("Front camera · portrait-locked · max 15s")
                .font(.footnote)
                .foregroundStyle(.secondary)

            previewCard

            controlPanel

            Spacer()
        }
        .padding()
    }

    private var previewCard: some View {
        ZStack(alignment: .topLeading) {
            CameraPreview(camera: camera)
                .aspectRatio(3.0 / 4.0, contentMode: .fit)
                .clipShape(RoundedRectangle(cornerRadius: 24))
                .overlay(
                    RoundedRectangle(cornerRadius: 24)
                        .strokeBorder(.white.opacity(0.6), lineWidth: 2)
                )
                .shadow(color: .black.opacity(0.2), radius: 16, y: 8)

            if camera.state.isRecording {
                Label("REC \(duration.clockString)", systemImage: "circle.fill")
                    .font(.caption.monospacedDigit().bold())
                    .foregroundStyle(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(.red, in: Capsule())
                    .padding(12)
            }
        }
    }

    private var controlPanel: some View {
        HStack(spacing: 20) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Elapsed")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Text(duration.clockString)
                    .font(.title3.monospacedDigit().bold())
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Button {
                Task { await toggleRecording() }
            } label: {
                Text(camera.state.isRecording ? "Stop" : "Record")
                    .font(.headline)
                    .foregroundStyle(.white)
                    .frame(width: 120, height: 50)
                    .background(camera.state.isRecording ? Color.red : Color.accentColor, in: Capsule())
            }
            .buttonStyle(.plain)
            .disabled(!canToggle)
            .opacity(canToggle ? 1 : 0.5)

            Button {
                Task { await switchCamera() }
            } label: {
                Image(systemName: "arrow.triangle.2.circlepath.camera.fill")
                    .font(.title2)
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
            .disabled(camera.state.isRecording)
        }
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 20))
    }

    private var canToggle: Bool {
        camera.state == .running || camera.state.isRecording
    }

    private func startCamera() async {
        do {
            try await camera.start()
        } catch let error as CameraError where error == .cameraPermissionDenied || error == .microphonePermissionDenied {
            // Shown via the permission screen.
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func toggleRecording() async {
        do {
            if camera.state.isRecording {
                _ = try await camera.stopRecording()
            } else {
                let url = RecordingsStore.makeRecordingURL(start: Date())
                try await camera.startRecording(outputURL: url)
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func switchCamera() async {
        var config = camera.configuration
        config.position = config.position.toggled
        try? await camera.updateConfiguration(config)
    }
}
