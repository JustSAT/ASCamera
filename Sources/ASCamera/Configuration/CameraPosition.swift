import AVFoundation

/// The physical camera to use for capture.
public enum CameraPosition: Sendable, Equatable, CaseIterable, CustomStringConvertible {
    /// The front-facing ("selfie") camera.
    case front
    /// The rear-facing camera.
    case back

    /// The opposite position, useful for camera-switch UI built by consumers.
    public var toggled: CameraPosition {
        self == .front ? .back : .front
    }

    public var description: String {
        switch self {
        case .front: return "front"
        case .back: return "back"
        }
    }

    /// The AVFoundation device position this maps to.
    var avPosition: AVCaptureDevice.Position {
        switch self {
        case .front: return .front
        case .back: return .back
        }
    }
}
