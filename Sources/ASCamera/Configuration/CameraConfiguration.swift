import Foundation

/// A strongly-typed, value-semantic description of how the camera should be configured.
///
/// `CameraConfiguration` is designed for long-term extensibility: new options are added as new
/// properties with sensible defaults, so existing call sites keep compiling. There is no large
/// initializer — start from defaults and mutate, or use the fluent `with`-style helpers:
///
/// ```swift
/// // Mutable style
/// var config = CameraConfiguration()
/// config.position = .front
/// config.frameRate = .fps60
///
/// // Builder style (chainable, value-returning)
/// let config = CameraConfiguration()
///     .position(.front)
///     .frameRate(.fps60)
///     .resolution(.fullHD)
///     .orientation(.lockedPortrait)
///     .maximumRecordingDuration(.seconds(30))
/// ```
public struct CameraConfiguration: Sendable, Equatable {
    /// Which physical camera to use. Default: `.back`.
    public var position: CameraPosition

    /// Desired capture frame rate. Default: `.fps30`.
    public var frameRate: FrameRate

    /// Desired capture resolution. Default: `.fullHD`.
    public var resolution: Resolution

    /// Torch behavior. Default: `.off`.
    public var torch: TorchMode

    /// Whether audio is captured alongside video. Default: `true`.
    public var isAudioEnabled: Bool

    /// Video stabilization mode. Default: `.auto`.
    public var stabilization: VideoStabilizationMode

    /// How preview and recording orientation are determined. Default: `.device`.
    public var orientation: OrientationStrategy

    /// Maximum recording duration. When set, recording auto-stops on reaching this limit and
    /// delivers a normal ``RecordingResult``. `nil` means unlimited. Default: `nil`.
    public var maximumRecordingDuration: Duration?

    /// Creates a configuration with sensible defaults.
    public init(
        position: CameraPosition = .back,
        frameRate: FrameRate = .fps30,
        resolution: Resolution = .fullHD,
        torch: TorchMode = .off,
        isAudioEnabled: Bool = true,
        stabilization: VideoStabilizationMode = .auto,
        orientation: OrientationStrategy = .device,
        maximumRecordingDuration: Duration? = nil
    ) {
        self.position = position
        self.frameRate = frameRate
        self.resolution = resolution
        self.torch = torch
        self.isAudioEnabled = isAudioEnabled
        self.stabilization = stabilization
        self.orientation = orientation
        self.maximumRecordingDuration = maximumRecordingDuration
    }
}

// MARK: - Fluent builder helpers

public extension CameraConfiguration {
    /// Returns a copy with the given camera position.
    func position(_ value: CameraPosition) -> Self {
        var copy = self
        copy.position = value
        return copy
    }

    /// Returns a copy with the given frame rate.
    func frameRate(_ value: FrameRate) -> Self {
        var copy = self
        copy.frameRate = value
        return copy
    }

    /// Returns a copy with the given resolution.
    func resolution(_ value: Resolution) -> Self {
        var copy = self
        copy.resolution = value
        return copy
    }

    /// Returns a copy with the given torch mode.
    func torch(_ value: TorchMode) -> Self {
        var copy = self
        copy.torch = value
        return copy
    }

    /// Returns a copy with audio recording enabled or disabled.
    func audioEnabled(_ value: Bool) -> Self {
        var copy = self
        copy.isAudioEnabled = value
        return copy
    }

    /// Returns a copy with the given stabilization mode.
    func stabilization(_ value: VideoStabilizationMode) -> Self {
        var copy = self
        copy.stabilization = value
        return copy
    }

    /// Returns a copy with the given orientation strategy.
    func orientation(_ value: OrientationStrategy) -> Self {
        var copy = self
        copy.orientation = value
        return copy
    }

    /// Returns a copy with the given maximum recording duration (`nil` for unlimited).
    func maximumRecordingDuration(_ value: Duration?) -> Self {
        var copy = self
        copy.maximumRecordingDuration = value
        return copy
    }
}
