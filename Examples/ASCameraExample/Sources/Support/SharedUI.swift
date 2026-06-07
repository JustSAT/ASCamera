import ASCamera
import SwiftUI

/// A classic camera shutter button that morphs between a filled circle (idle) and a rounded square
/// (recording).
struct ShutterButton: View {
    let isRecording: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .stroke(.white, lineWidth: 4)
                    .frame(width: 74, height: 74)
                RoundedRectangle(cornerRadius: isRecording ? 7 : 30)
                    .fill(.red)
                    .frame(
                        width: isRecording ? 32 : 60,
                        height: isRecording ? 32 : 60
                    )
                    .animation(.easeInOut(duration: 0.2), value: isRecording)
            }
        }
        .buttonStyle(.plain)
    }
}

enum PermissionHelper {
    /// Maps the camera's current permission state to the error-view's missing-permission case.
    @MainActor
    static func missing(camera: Camera) -> CameraPermissionErrorView.MissingPermission {
        switch (camera.cameraPermission.isAuthorized, camera.microphonePermission.isAuthorized) {
        case (false, false): return .both
        case (false, true): return .camera
        default: return .microphone
        }
    }
}
