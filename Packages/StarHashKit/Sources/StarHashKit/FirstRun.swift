import Foundation

/// The first run, and what opens on its own after it: onboarding's
/// screens, where an unfinished one was left, and the sheets that follow,
/// one at a time. The app shows what this answers; the order lives here.
public enum FirstRun {
    // MARK: Onboarding

    /// Onboarding's screens, in order.
    public enum Screen: String, CaseIterable, Sendable {
        case reel, wallet, number, photo, contacts, nearby, notifications, autoVerify, setup

        /// The screen after this one; nil after the last.
        public var next: Screen? {
            let all = Self.allCases
            let index = all.firstIndex(of: self)!
            return index + 1 < all.count ? all[index + 1] : nil
        }

        /// The screen before this one; nil before the first.
        public var previous: Screen? {
            let all = Self.allCases
            let index = all.firstIndex(of: self)!
            return index > 0 ? all[index - 1] : nil
        }
    }

    static let screenKey = "onboardingStage"

    /// Where an unfinished onboarding was left, so it opens there again.
    /// Kept by name: a screen added later moves the others along, and an
    /// install part-way through still opens on the screen it left. Earlier
    /// builds kept the screen's position, which still reads.
    public static func savedScreen(in defaults: UserDefaults = .standard) -> Screen {
        switch defaults.object(forKey: screenKey) {
        case let name as String:
            return Screen(rawValue: name) ?? .reel
        case let position as Int:
            return Screen.allCases.indices.contains(position) ? Screen.allCases[position] : .reel
        default:
            return .reel
        }
    }

    /// Saves where onboarding is; nil once it is finished, so a replay
    /// starts from the first screen.
    public static func save(_ screen: Screen?, in defaults: UserDefaults = .standard) {
        if let screen {
            defaults.set(screen.rawValue, forKey: screenKey)
        } else {
            defaults.removeObject(forKey: screenKey)
        }
    }

    // MARK: After onboarding

    /// What opens on its own over the app, one at a time, in this order.
    public enum Sheet: Equatable, Sendable {
        /// Shima's note, as onboarding ends (and again if the app was quit
        /// before it was closed).
        case welcomeNote
        /// The first launch after an update with news.
        case whatsNew
        /// Once, for owners set up before Show My Name came.
        case showMyNameNotice
        /// Two weeks after the first setup, the note asking for a rating.
        case reviewNote
    }

    /// What the app knows when it asks.
    public struct State: Equatable, Sendable {
        public var hasOnboarded: Bool
        /// A wallet chosen: an install from before onboarding asked for one
        /// is asked first, on its own page.
        public var hasWallet: Bool
        public var hasSeenWelcomeNote: Bool
        /// Shown whatever else (a debug launch, a replay from Settings).
        public var forcesWelcomeNote: Bool
        public var whatsNewPending: Bool
        public var showMyNameNoticeDue: Bool
        public var reviewNoteDue: Bool

        public init(
            hasOnboarded: Bool, hasWallet: Bool, hasSeenWelcomeNote: Bool, forcesWelcomeNote: Bool = false,
            whatsNewPending: Bool = false, showMyNameNoticeDue: Bool = false, reviewNoteDue: Bool = false
        ) {
            self.hasOnboarded = hasOnboarded
            self.hasWallet = hasWallet
            self.hasSeenWelcomeNote = hasSeenWelcomeNote
            self.forcesWelcomeNote = forcesWelcomeNote
            self.whatsNewPending = whatsNewPending
            self.showMyNameNoticeDue = showMyNameNoticeDue
            self.reviewNoteDue = reviewNoteDue
        }
    }

    /// The sheet to show now, if any: never over onboarding or the wallet
    /// page, and never one over another.
    public static func next(_ state: State) -> Sheet? {
        if state.forcesWelcomeNote { return .welcomeNote }
        guard state.hasOnboarded, state.hasWallet else { return nil }
        if !state.hasSeenWelcomeNote { return .welcomeNote }
        if state.whatsNewPending { return .whatsNew }
        if state.showMyNameNoticeDue { return .showMyNameNotice }
        if state.reviewNoteDue { return .reviewNote }
        return nil
    }

    /// Whether the rating note's two weeks may start, and the note come
    /// when they are up: onboarding done and nothing else waiting to show.
    public static func reviewNoteMayCome(_ state: State) -> Bool {
        var before = state
        before.reviewNoteDue = false
        return state.hasOnboarded && state.hasWallet && next(before) == nil
    }
}
