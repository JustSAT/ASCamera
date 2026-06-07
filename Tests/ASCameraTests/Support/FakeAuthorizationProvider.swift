import Foundation
@testable import ASCamera

/// A deterministic ``AuthorizationProviding`` for testing the permission flow without prompting.
struct FakeAuthorizationProvider: AuthorizationProviding {
    var videoStatus: PermissionStatus
    var audioStatus: PermissionStatus
    /// The result returned from `requestAccess` for `.notDetermined` media types.
    var grantOnRequest: Bool

    init(
        videoStatus: PermissionStatus = .authorized,
        audioStatus: PermissionStatus = .authorized,
        grantOnRequest: Bool = true
    ) {
        self.videoStatus = videoStatus
        self.audioStatus = audioStatus
        self.grantOnRequest = grantOnRequest
    }

    func status(for mediaType: CameraMediaType) -> PermissionStatus {
        switch mediaType {
        case .video: return videoStatus
        case .audio: return audioStatus
        }
    }

    func requestAccess(for mediaType: CameraMediaType) async -> Bool {
        grantOnRequest
    }
}

extension Camera {
    /// Convenience test factory wiring up the fakes.
    @MainActor
    static func makeForTesting(
        configuration: CameraConfiguration = CameraConfiguration(),
        engine: FakeCameraEngine = FakeCameraEngine(),
        authorization: FakeAuthorizationProvider = FakeAuthorizationProvider()
    ) -> Camera {
        Camera(configuration: configuration, engine: engine, authorization: authorization)
    }
}
