import Testing
@testable import ASCamera

@MainActor
@Suite("Permission handling")
struct PermissionTests {
    @Test("Denied camera permission blocks start and reports permissionDenied")
    func cameraDenied() async {
        let camera = Camera.makeForTesting(
            authorization: FakeAuthorizationProvider(videoStatus: .denied)
        )
        await #expect(throws: CameraError.cameraPermissionDenied) {
            try await camera.start()
        }
        #expect(camera.state == .permissionDenied)
    }

    @Test("Denied microphone permission blocks start when audio is enabled")
    func microphoneDenied() async {
        let config = CameraConfiguration().audioEnabled(true)
        let camera = Camera.makeForTesting(
            configuration: config,
            authorization: FakeAuthorizationProvider(videoStatus: .authorized, audioStatus: .denied)
        )
        await #expect(throws: CameraError.microphonePermissionDenied) {
            try await camera.start()
        }
        #expect(camera.state == .permissionDenied)
    }

    @Test("Microphone permission is not required when audio is disabled")
    func microphoneNotRequiredWhenAudioDisabled() async throws {
        let config = CameraConfiguration().audioEnabled(false)
        let camera = Camera.makeForTesting(
            configuration: config,
            authorization: FakeAuthorizationProvider(videoStatus: .authorized, audioStatus: .denied)
        )
        try await camera.start()
        #expect(camera.state == .running)
    }

    @Test("Not-determined permission triggers a request and proceeds when granted")
    func notDeterminedGranted() async throws {
        let camera = Camera.makeForTesting(
            authorization: FakeAuthorizationProvider(
                videoStatus: .notDetermined,
                audioStatus: .notDetermined,
                grantOnRequest: true
            )
        )
        try await camera.start()
        #expect(camera.state == .running)
    }

    @Test("Not-determined permission that is denied on request blocks start")
    func notDeterminedDenied() async {
        let camera = Camera.makeForTesting(
            authorization: FakeAuthorizationProvider(
                videoStatus: .notDetermined,
                grantOnRequest: false
            )
        )
        await #expect(throws: CameraError.cameraPermissionDenied) {
            try await camera.start()
        }
        #expect(camera.state == .permissionDenied)
    }

    @Test("Exposed permission state reflects the provider")
    func exposedPermissionState() {
        let camera = Camera.makeForTesting(
            authorization: FakeAuthorizationProvider(videoStatus: .authorized, audioStatus: .denied)
        )
        #expect(camera.cameraPermission == .authorized)
        #expect(camera.microphonePermission == .denied)
    }
}
