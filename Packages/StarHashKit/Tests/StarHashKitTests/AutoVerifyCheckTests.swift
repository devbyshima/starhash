import Foundation
import Testing
@testable import StarHashKit

/// The setup's check, driven as the guide drives it: `beginCheck`, the
/// shortcut's run arriving through `receive`, and Shortcuts coming back.
@Suite("The setup's check")
@MainActor
struct AutoVerifyCheckTests {
    static let now = Date(timeIntervalSince1970: 1_790_000_000)

    static func autoVerify() -> AutoVerify {
        let name = "AutoVerifyCheckTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        defaults.removePersistentDomain(forName: name)
        return AutoVerify(store: StarHashStore(fileURL: nil), defaults: defaults, now: now)
    }

    @Test func theSampleArrivingFinishesTheSetupAndWaitsForAMessage() {
        let autoVerify = Self.autoVerify()
        autoVerify.beginCheck()
        #expect(autoVerify.check == .running)
        autoVerify.receive(AutoVerificationSample.message, sender: nil, at: Self.now)
        #expect(autoVerify.check == .awaitingMessage)
        #expect(autoVerify.status(at: Self.now) == .waiting)
        autoVerify.receive("Bank: 1,000 RWF", sender: nil, at: Self.now.addingTimeInterval(60))
        #expect(autoVerify.check == .proven)
        #expect(autoVerify.status(at: Self.now.addingTimeInterval(60)) == .active)
    }

    @Test func comingBackWithoutTheShortcutRunningFails() {
        let autoVerify = Self.autoVerify()
        autoVerify.beginCheck()
        autoVerify.checkReturned(.cancel)
        #expect(autoVerify.check == .failed)

        autoVerify.beginCheck()
        autoVerify.checkReturned(nil)
        #expect(autoVerify.check == .failed)
        #expect(autoVerify.status(at: Self.now) == .off)
    }

    /// Shortcuts says it ran before the action's write lands: still running.
    @Test func aSuccessWithNoRunYetKeepsRunning() {
        let autoVerify = Self.autoVerify()
        autoVerify.beginCheck()
        autoVerify.checkReturned(.success)
        #expect(autoVerify.check == .running)
        autoVerify.receive(AutoVerificationSample.message, sender: nil, at: Self.now)
        #expect(autoVerify.check == .awaitingMessage)
    }

    /// A run from before the check began proves nothing about this one.
    @Test func anEarlierRunDoesNotPassTheCheck() {
        let autoVerify = Self.autoVerify()
        autoVerify.receive(AutoVerificationSample.message, sender: nil, at: Self.now)
        autoVerify.beginCheck()
        autoVerify.checkReturned(.error)
        #expect(autoVerify.check == .failed)
        #expect(autoVerify.status(at: Self.now) == .off)
    }

    @Test func leavingTheStepResetsIt() {
        let autoVerify = Self.autoVerify()
        autoVerify.beginCheck()
        autoVerify.resetCheck()
        #expect(autoVerify.check == .idle)
        autoVerify.receive(AutoVerificationSample.message, sender: nil, at: Self.now)
        #expect(autoVerify.check == .idle)
        #expect(autoVerify.status(at: Self.now) == .off)
    }
}
