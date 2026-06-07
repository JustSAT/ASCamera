import CoreMedia
import Foundation

extension Duration {
    /// The duration expressed as a floating-point number of seconds.
    var seconds: Double {
        let (whole, attoseconds) = components
        return Double(whole) + Double(attoseconds) / 1_000_000_000_000_000_000
    }

    /// Converts the duration to a `CMTime` with a high, stable timescale.
    var cmTime: CMTime {
        CMTime(seconds: seconds, preferredTimescale: 600)
    }

    /// Creates a `Duration` from a `CMTime`, returning `.zero` for invalid/indefinite times.
    init(cmTime: CMTime) {
        guard cmTime.isValid, cmTime.isNumeric else {
            self = .zero
            return
        }
        self = .seconds(max(0, cmTime.seconds))
    }
}
