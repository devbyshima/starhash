import StarHashKit
import SwiftUI

/// Whether What's New shows this launch: the first launch after an update
/// to a release with an announcement, and never a fresh install's
/// (`WhatsNew` in StarHashKit). The version running is recorded as it is
/// decided, so the sheet shows once, however it is closed.
@MainActor
enum WhatsNewLaunch {
    /// Worked out on first use, at launch, before onboarding can mark a new
    /// install as used.
    static let pending: Release.Announcement? = decide()

    /// The version running, as seen: onboarding calls it as it ends, so an
    /// install set up again after Delete All Data, which forgets the last
    /// version, is not taken for an update on its next launch.
    static func markSeen() {
        UserDefaults.standard.set(SettingsVersion.short, forKey: PreferenceKey.lastRunVersion)
    }

    private static func decide() -> Release.Announcement? {
        let defaults = UserDefaults.standard
        let lastRun = defaults.string(forKey: PreferenceKey.lastRunVersion)
        markSeen()
        #if DEBUG
        if DebugLaunch.arguments.contains("-whatsNew") { return preview }
        // Any other debug argument keeps it away, so screenshots see their
        // screen.
        if DebugLaunch.arguments.contains(where: { $0.hasPrefix("-") && !$0.hasPrefix("-NS") && !$0.hasPrefix("-Apple") && !$0.hasPrefix("-UI") }) {
            return nil
        }
        #endif
        return WhatsNew.release(
            toAnnounce: SettingsVersion.short,
            lastRun: lastRun,
            hasUsedApp: defaults.bool(forKey: PreferenceKey.hasOnboarded),
            in: ReleaseHistory.releases
        )?.announcement
    }

    /// `-whatsNewPage <n>` (DEBUG): the page the sheet opens on, 0 for the
    /// first.
    static var startPage: Int {
        #if DEBUG
        DebugLaunch.value(after: "-whatsNewPage").flatMap(Int.init) ?? 0
        #else
        0
        #endif
    }
}

#if DEBUG
extension WhatsNewLaunch {
    /// What `-whatsNew` and starhash://whatsnew show: the newest release's
    /// announcement, or the sample before there is one.
    static var preview: Release.Announcement {
        ReleaseHistory.releases.lazy.compactMap(\.announcement).first ?? WhatsNewSample.announcement
    }
}

/// `-whatsNew` before any release has an announcement: 1.0's news, on the
/// sheet's pages. Without videos in the bundle, each card shows its
/// feature's symbol.
enum WhatsNewSample {
    static let announcement = Release.Announcement(
        highlights: [
            .init(symbol: "number", title: "Pay in a few taps", detail: "Type an amount, pick who gets it, and StarHash dials the code."),
            .init(symbol: "phone.fill", title: "Buy", detail: "The codes you dial often, one tap each, up to eight pinned."),
            .init(symbol: "clock.fill", title: "Activity", detail: "Every payment by day, week, month or year, with a chart."),
            .init(symbol: "checkmark.message.fill", title: "Auto-verify", detail: "Your wallet's messages confirm each payment for you."),
        ],
        pages: [
            .init(symbol: "number", title: "Pay in a few taps", detail: "Type an amount, pick a contact or a merchant code, and StarHash dials your wallet's code for you.", video: "WhatsNewSamplePay"),
            .init(symbol: "phone.fill", title: "Buy", detail: "Keep the codes you dial often, like cash out and bundles, and dial each one in a tap.", video: "WhatsNewSampleBuy"),
            .init(symbol: "clock.fill", title: "Activity", detail: "See what you spent by day, week, month or year, with a chart and every payment's details.", video: "WhatsNewSampleActivity"),
            .init(symbol: "checkmark.message.fill", title: "Auto-verify", detail: "Your wallet's messages confirm each payment, with its fee and balance. Thank you for using StarHash.", video: "WhatsNewSampleAutoVerify"),
        ]
    )
}
#endif
