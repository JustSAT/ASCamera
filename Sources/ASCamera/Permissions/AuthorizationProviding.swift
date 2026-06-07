import AVFoundation
import Foundation

/// Abstraction over media-capture authorization, allowing the permission flow in ``Camera`` to be
/// unit tested with a fake provider instead of the real, prompt-driving AVFoundation APIs.
protocol AuthorizationProviding: Sendable {
    func status(for mediaType: CameraMediaType) -> PermissionStatus
    func requestAccess(for mediaType: CameraMediaType) async -> Bool
}

/// The production implementation backed by `AVCaptureDevice`.
struct AVAuthorizationProvider: AuthorizationProviding {
    func status(for mediaType: CameraMediaType) -> PermissionStatus {
        switch AVCaptureDevice.authorizationStatus(for: mediaType.avMediaType) {
        case .notDetermined: return .notDetermined
        case .authorized: return .authorized
        case .denied: return .denied
        case .restricted: return .restricted
        @unknown default: return .denied
        }
    }

    func requestAccess(for mediaType: CameraMediaType) async -> Bool {
        await AVCaptureDevice.requestAccess(for: mediaType.avMediaType)
    }
}

private extension CameraMediaType {
    var avMediaType: AVMediaType {
        switch self {
        case .video: return .video
        case .audio: return .audio
        }
    }
}
