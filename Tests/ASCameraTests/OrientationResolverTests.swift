import CoreGraphics
import Testing
@testable import ASCamera

@Suite("Orientation resolver")
struct OrientationResolverTests {
    @Test("Locked portrait is always 90 regardless of device orientation")
    func lockedPortraitIgnoresDevice() {
        for device: DeviceOrientation in [.portrait, .landscapeLeft, .landscapeRight, .portraitUpsideDown, .unknown] {
            #expect(OrientationResolver.rotationAngle(for: .lockedPortrait, deviceOrientation: device) == 90)
        }
    }

    @Test("Locked landscape strategies ignore device orientation")
    func lockedLandscapeIgnoresDevice() {
        #expect(OrientationResolver.rotationAngle(for: .lockedLandscapeLeft, deviceOrientation: .portrait) == 180)
        #expect(OrientationResolver.rotationAngle(for: .lockedLandscapeRight, deviceOrientation: .portrait) == 0)
        // Even if the device is rotated the opposite way, the locked angle holds.
        #expect(OrientationResolver.rotationAngle(for: .lockedLandscapeLeft, deviceOrientation: .landscapeRight) == 180)
        #expect(OrientationResolver.rotationAngle(for: .lockedLandscapeRight, deviceOrientation: .landscapeLeft) == 0)
    }

    @Test("Device strategy follows the physical orientation")
    func deviceStrategyFollowsDevice() {
        #expect(OrientationResolver.rotationAngle(for: .device, deviceOrientation: .portrait) == 90)
        #expect(OrientationResolver.rotationAngle(for: .device, deviceOrientation: .portraitUpsideDown) == 270)
        #expect(OrientationResolver.rotationAngle(for: .device, deviceOrientation: .landscapeLeft) == 180)
        #expect(OrientationResolver.rotationAngle(for: .device, deviceOrientation: .landscapeRight) == 0)
    }

    @Test("Unknown device orientation falls back to portrait")
    func unknownFallsBackToPortrait() {
        #expect(OrientationResolver.rotationAngle(for: .device, deviceOrientation: .unknown) == 90)
    }

    @Test("Front camera recording swaps the landscape angles and keeps the portrait ones")
    func frontCameraCaptureAngles() {
        #expect(OrientationResolver.captureRotationAngle(for: .device, deviceOrientation: .landscapeLeft, position: .front) == 0)
        #expect(OrientationResolver.captureRotationAngle(for: .device, deviceOrientation: .landscapeRight, position: .front) == 180)
        #expect(OrientationResolver.captureRotationAngle(for: .device, deviceOrientation: .portrait, position: .front) == 90)
        #expect(OrientationResolver.captureRotationAngle(for: .device, deviceOrientation: .portraitUpsideDown, position: .front) == 270)
        #expect(OrientationResolver.captureRotationAngle(for: .lockedLandscapeLeft, deviceOrientation: .portrait, position: .front) == 0)
        #expect(OrientationResolver.captureRotationAngle(for: .lockedLandscapeRight, deviceOrientation: .portrait, position: .front) == 180)
    }

    @Test("Back camera recording uses the preview angles")
    func backCameraCaptureAngles() {
        for strategy in OrientationStrategy.allCases {
            for device: DeviceOrientation in [.portrait, .landscapeLeft, .landscapeRight, .portraitUpsideDown, .unknown] {
                #expect(
                    OrientationResolver.captureRotationAngle(for: strategy, deviceOrientation: device, position: .back)
                        == OrientationResolver.rotationAngle(for: strategy, deviceOrientation: device)
                )
            }
        }
    }
}
