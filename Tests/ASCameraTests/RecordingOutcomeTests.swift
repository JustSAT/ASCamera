import AVFoundation
import Foundation
import Testing
@testable import ASCamera

@Suite("Recording outcome classification")
struct RecordingOutcomeTests {
    @Test("No error is a successful recording")
    func noError() {
        #expect(RecordingOutcome.isSuccessful(error: nil))
    }

    @Test("Reaching maximum duration is a successful auto-stop")
    func maximumDurationReached() {
        let error = NSError(
            domain: AVFoundationErrorDomain,
            code: AVError.maximumDurationReached.rawValue
        )
        #expect(RecordingOutcome.isSuccessful(error: error))
    }

    @Test("Error with the 'successfully finished' flag set is a success")
    func successfullyFinishedFlagTrue() {
        let error = NSError(
            domain: AVFoundationErrorDomain,
            code: AVError.diskFull.rawValue,
            userInfo: [AVErrorRecordingSuccessfullyFinishedKey: true]
        )
        #expect(RecordingOutcome.isSuccessful(error: error))
    }

    @Test("Error with the 'successfully finished' flag false is a failure")
    func successfullyFinishedFlagFalse() {
        let error = NSError(
            domain: AVFoundationErrorDomain,
            code: AVError.diskFull.rawValue,
            userInfo: [AVErrorRecordingSuccessfullyFinishedKey: false]
        )
        #expect(!RecordingOutcome.isSuccessful(error: error))
    }

    @Test("Unrelated error is a failure")
    func genericError() {
        let error = NSError(domain: "com.example", code: 42)
        #expect(!RecordingOutcome.isSuccessful(error: error))
    }
}
