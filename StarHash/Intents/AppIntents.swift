import AppIntents
import StarHashKit
import UIKit

/// Opens StarHash and dials the main wallet's balance code (*182*6*1# on
/// MTN MoMo).
struct CheckBalanceIntent: AppIntent {
    static let title: LocalizedStringResource = "Check MoMo Balance"
    static let description = IntentDescription("Dials your wallet's balance code.")
    /// The dialer can only be opened from the foreground.
    static let openAppWhenRun = true

    @MainActor
    func perform() async throws -> some IntentResult {
        AppEnvironment.router.selectedTab = .pay
        if let url = USSD.telURL(for: USSD.balance(for: StarHashPreferences.wallet)) {
            await UIApplication.shared.open(url)
        }
        return .result()
    }
}

/// Opens StarHash on the Pay tab, ready for an amount.
struct OpenPayIntent: AppIntent {
    static let title: LocalizedStringResource = "Pay with StarHash"
    static let description = IntentDescription("Opens StarHash's keypad to pay someone.")
    static let openAppWhenRun = true

    @MainActor
    func perform() async throws -> some IntentResult {
        AppEnvironment.router.selectedTab = .pay
        return .result()
    }
}

/// Siri phrases and Spotlight entries for StarHash's actions.
struct StarHashShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: OpenPayIntent(),
            phrases: [
                "Pay with \(.applicationName)",
                "Pay someone with \(.applicationName)",
            ],
            shortTitle: "Pay",
            systemImageName: "number"
        )
        AppShortcut(
            intent: CheckBalanceIntent(),
            phrases: [
                "Check my balance in \(.applicationName)",
                "Check my MoMo balance with \(.applicationName)",
            ],
            shortTitle: "Check Balance",
            systemImageName: "banknote"
        )
        AppShortcut(
            intent: ProcessCarrierSMSIntent(),
            phrases: [
                "Process carrier SMS in \(.applicationName)",
            ],
            shortTitle: "Process Carrier SMS",
            systemImageName: "checkmark.message"
        )
    }
}
