import Foundation

/// A small public facade for querying and requesting camera and microphone permissions, without
/// exposing AVFoundation. ``Camera`` performs these checks automatically during ``Camera/start()``;
/// this type is provided for consumers that want to drive a pre-flight permission UI themselves.
public enum CameraPermissions {
    private static let provider: AuthorizationProviding = AVAuthorizationProvider()

    /// The current camera authorization status.
    public static var cameraStatus: PermissionStatus {
        provider.status(for: .video)
    }

    /// The current microphone authorization status.
    public static var microphoneStatus: PermissionStatus {
        provider.status(for: .audio)
    }

    /// Requests camera access, prompting the user if not yet determined.
    /// - Returns: `true` if access is authorized.
    @discardableResult
    public static func requestCameraAccess() async -> Bool {
        await provider.requestAccess(for: .video)
    }

    /// Requests microphone access, prompting the user if not yet determined.
    /// - Returns: `true` if access is authorized.
    @discardableResult
    public static func requestMicrophoneAccess() async -> Bool {
        await provider.requestAccess(for: .audio)
    }
}
