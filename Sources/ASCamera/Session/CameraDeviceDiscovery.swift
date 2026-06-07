import AVFoundation
import CoreMedia
import Foundation

/// Locates capture devices and selects the best `AVCaptureDevice.Format` for a requested
/// resolution and frame rate.
enum CameraDeviceDiscovery {
    /// Returns the best available video capture device for the given position.
    static func videoDevice(for position: CameraPosition) -> AVCaptureDevice? {
        let discovery = AVCaptureDevice.DiscoverySession(
            deviceTypes: [
                .builtInTripleCamera,
                .builtInDualCamera,
                .builtInDualWideCamera,
                .builtInWideAngleCamera
            ],
            mediaType: .video,
            position: position.avPosition
        )
        // Prefer the first device (discovery returns them in priority order), falling back to the
        // default device for the position.
        return discovery.devices.first
            ?? AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: position.avPosition)
    }

    /// Returns the default audio capture device.
    static func audioDevice() -> AVCaptureDevice? {
        AVCaptureDevice.default(for: .audio)
    }

    /// The outcome of selecting a device format.
    struct FormatSelection {
        let format: AVCaptureDevice.Format
        /// Whether the requested frame rate is supported by the chosen format.
        let supportsRequestedFrameRate: Bool
    }

    /// Selects the device format that best matches the target resolution while supporting the
    /// requested frame rate when possible.
    ///
    /// Selection strategy:
    /// 1. Prefer formats that support the requested frame rate.
    /// 2. Among those, choose the format whose pixel area is closest to (and ideally at least)
    ///    the requested resolution.
    /// 3. If no format supports the frame rate, fall back to the closest-resolution format and
    ///    report `supportsRequestedFrameRate == false`.
    static func selectFormat(
        for device: AVCaptureDevice,
        resolution: Resolution,
        frameRate: FrameRate
    ) -> FormatSelection? {
        let targetArea = resolution.pixelCount
        let formats = device.formats.filter { $0.mediaType == .video }
        guard !formats.isEmpty else { return nil }

        func area(of format: AVCaptureDevice.Format) -> Int {
            let dimensions = CMVideoFormatDescriptionGetDimensions(format.formatDescription)
            return Int(dimensions.width) * Int(dimensions.height)
        }

        func supportsFrameRate(_ format: AVCaptureDevice.Format) -> Bool {
            format.videoSupportedFrameRateRanges.contains { range in
                frameRate.fps >= range.minFrameRate && frameRate.fps <= range.maxFrameRate
            }
        }

        // Rank by: closeness of pixel area to target (prefer >= target), then smaller area.
        func score(_ format: AVCaptureDevice.Format) -> (Int, Int) {
            let formatArea = area(of: format)
            let meetsTarget = formatArea >= targetArea ? 0 : 1
            return (meetsTarget, abs(formatArea - targetArea))
        }

        let supporting = formats.filter(supportsFrameRate)
        if let best = supporting.min(by: { score($0) < score($1) }) {
            return FormatSelection(format: best, supportsRequestedFrameRate: true)
        }

        // No format supports the frame rate; pick the closest resolution anyway.
        if let fallback = formats.min(by: { score($0) < score($1) }) {
            return FormatSelection(format: fallback, supportsRequestedFrameRate: false)
        }
        return nil
    }
}
