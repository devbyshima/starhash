import StarHashKit
import SwiftUI

extension PreferenceKey {
    /// When auto-verify was last set up (seconds since 1970): payments
    /// dialled before it are never failed for want of a message.
    static let autoVerifySince = "autoVerifySince"
}

/// Fails the payments auto-verify should have confirmed by now
/// (`AutoVerify`): dialled from StarHash while auto-verify was on, and no
/// message within the hour. Runs whenever StarHash wakes (back to the
/// foreground, every minute while it stays there, and after the Process
/// Carrier SMS action), so a payment's status is right whenever it is
/// looked at.
@MainActor
enum PaymentExpiry {
    /// Whether unconfirmed payments fail on their own: auto-verify is on
    /// and does not look broken.
    static var isActive: Bool {
        StarHashPreferences.autoVerifyOn && !looksBroken
    }

    /// Auto-verify is on but no message has come for a week and the last
    /// payments all went unconfirmed: Settings says to check the shortcut,
    /// and nothing more is failed until a message comes again.
    static var looksBroken: Bool {
        StarHashPreferences.autoVerifyOn && AutoVerify.looksBroken(
            AppEnvironment.store.transactions,
            lastMessageAt: StarHashPreferences.lastVerifiedAt,
            now: .now
        )
    }

    static func run(now: Date = .now) {
        guard isActive else { return }
        AppEnvironment.store.expireUnconfirmed(dialledSince: since, now: now)
    }

    /// Set when the setup finishes. An install that set auto-verify up
    /// before this was kept starts counting from now.
    private static var since: Date {
        let saved = UserDefaults.standard.double(forKey: PreferenceKey.autoVerifySince)
        guard saved > 0 else {
            markSetUp()
            return .now
        }
        return Date(timeIntervalSince1970: saved)
    }

    static func markSetUp(at date: Date = .now) {
        UserDefaults.standard.set(date.timeIntervalSince1970, forKey: PreferenceKey.autoVerifySince)
    }
}
