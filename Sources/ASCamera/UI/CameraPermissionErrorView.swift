#if canImport(UIKit)
import SwiftUI

/// A ready-to-use SwiftUI screen explaining which capture permission is missing and offering a
/// button to open the Settings app. Consumers may use it directly or build their own.
///
/// ```swift
/// if camera.cameraPermission == .denied {
///     CameraPermissionErrorView(missing: .camera)
/// }
/// ```
public struct CameraPermissionErrorView: View {
    /// Which permission(s) are missing.
    public enum MissingPermission: Sendable, Equatable {
        case camera
        case microphone
        case both

        var title: String {
            switch self {
            case .camera: return "Camera Access Needed"
            case .microphone: return "Microphone Access Needed"
            case .both: return "Camera & Microphone Access Needed"
            }
        }

        var message: String {
            switch self {
            case .camera:
                return "This app needs access to your camera to record video. Enable Camera access in Settings."
            case .microphone:
                return "This app needs access to your microphone to record audio. Enable Microphone access in Settings."
            case .both:
                return "This app needs access to your camera and microphone to record video. Enable both in Settings."
            }
        }

        var systemImage: String {
            switch self {
            case .camera: return "video.slash.fill"
            case .microphone: return "mic.slash.fill"
            case .both: return "exclamationmark.triangle.fill"
            }
        }
    }

    private let missing: MissingPermission
    private let customMessage: String?

    @Environment(\.openURL) private var openURL

    /// Creates the error view.
    /// - Parameters:
    ///   - missing: Which permission is missing.
    ///   - message: An optional message overriding the default explanation.
    public init(missing: MissingPermission, message: String? = nil) {
        self.missing = missing
        self.customMessage = message
    }

    public var body: some View {
        VStack(spacing: 20) {
            Image(systemName: missing.systemImage)
                .font(.system(size: 56))
                .foregroundStyle(.secondary)

            Text(missing.title)
                .font(.title2.bold())
                .multilineTextAlignment(.center)

            Text(customMessage ?? missing.message)
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Button("Open Settings") {
                openSettings()
            }
            .buttonStyle(.borderedProminent)
        }
        .padding(32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func openSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        openURL(url)
    }
}

#Preview {
    CameraPermissionErrorView(missing: .both)
}
#endif
