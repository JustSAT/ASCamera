import Foundation

/// A reference wrapper that carries a non-`Sendable` value across isolation domains.
///
/// This is used in exactly one place: bridging the `AVCaptureSession` owned by the
/// ``CameraSession`` actor to the main-actor ``CameraPreview`` so the preview layer can hold a
/// reference to it. AVFoundation guarantees the preview layer / session association is safe to
/// establish from the main thread while configuration happens on the session's queue, so this
/// bridge is deliberately and narrowly `@unchecked Sendable`.
final class UncheckedSendableBox<Value>: @unchecked Sendable {
    let value: Value
    init(_ value: Value) {
        self.value = value
    }
}
