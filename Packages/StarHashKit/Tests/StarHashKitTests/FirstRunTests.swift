import Foundation
import Testing
@testable import StarHashKit

@Suite("First run")
struct FirstRunTests {
    static func defaults() -> UserDefaults {
        let name = "FirstRunTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        defaults.removePersistentDomain(forName: name)
        return defaults
    }

    static let settled = FirstRun.State(hasOnboarded: true, hasWallet: true, hasSeenWelcomeNote: true)

    // MARK: Onboarding

    @Test func anUnfinishedOnboardingOpensWhereItWasLeft() {
        let defaults = Self.defaults()
        #expect(FirstRun.savedScreen(in: defaults) == .reel)
        FirstRun.save(.nearby, in: defaults)
        #expect(FirstRun.savedScreen(in: defaults) == .nearby)
        FirstRun.save(nil, in: defaults)
        #expect(FirstRun.savedScreen(in: defaults) == .reel)
    }

    /// Earlier builds kept the screen's position; it still reads, and an
    /// unknown name or position starts again.
    @Test func aPositionFromAnEarlierBuildStillReads() {
        let defaults = Self.defaults()
        defaults.set(4, forKey: FirstRun.screenKey)
        #expect(FirstRun.savedScreen(in: defaults) == .contacts)
        defaults.set(99, forKey: FirstRun.screenKey)
        #expect(FirstRun.savedScreen(in: defaults) == .reel)
        defaults.set("gone", forKey: FirstRun.screenKey)
        #expect(FirstRun.savedScreen(in: defaults) == .reel)
    }

    @Test func theScreensStepInOrder() {
        #expect(FirstRun.Screen.reel.previous == nil)
        #expect(FirstRun.Screen.number.next == .photo)
        #expect(FirstRun.Screen.photo.previous == .number)
        #expect(FirstRun.Screen.setup.next == nil)
    }

    // MARK: After onboarding

    @Test func nothingOpensOverOnboardingOrTheWalletPage() {
        let due = FirstRun.State(hasOnboarded: false, hasWallet: true, hasSeenWelcomeNote: false, whatsNewPending: true, reviewNoteDue: true)
        #expect(FirstRun.next(due) == nil)
        var noWallet = due
        noWallet.hasOnboarded = true
        noWallet.hasWallet = false
        #expect(FirstRun.next(noWallet) == nil)
    }

    /// One at a time, each waiting for the ones before it.
    @Test func theSheetsComeInOrder() {
        var state = FirstRun.State(
            hasOnboarded: true, hasWallet: true, hasSeenWelcomeNote: false,
            whatsNewPending: true, showMyNameNoticeDue: true, reviewNoteDue: true
        )
        #expect(FirstRun.next(state) == .welcomeNote)
        state.hasSeenWelcomeNote = true
        #expect(FirstRun.next(state) == .whatsNew)
        state.whatsNewPending = false
        #expect(FirstRun.next(state) == .showMyNameNotice)
        state.showMyNameNoticeDue = false
        #expect(FirstRun.next(state) == .reviewNote)
        state.reviewNoteDue = false
        #expect(FirstRun.next(state) == nil)
    }

    @Test func aForcedWelcomeNoteComesFirstWhatever() {
        var state = Self.settled
        state.hasOnboarded = false
        state.forcesWelcomeNote = true
        #expect(FirstRun.next(state) == .welcomeNote)
    }

    @Test func theRatingNoteWaitsForEverythingElse() {
        #expect(FirstRun.reviewNoteMayCome(Self.settled))
        var due = Self.settled
        due.reviewNoteDue = true
        #expect(FirstRun.reviewNoteMayCome(due))
        var news = Self.settled
        news.whatsNewPending = true
        #expect(!FirstRun.reviewNoteMayCome(news))
        var fresh = Self.settled
        fresh.hasOnboarded = false
        #expect(!FirstRun.reviewNoteMayCome(fresh))
    }
}
