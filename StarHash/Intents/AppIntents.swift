import AppIntents
import StarHashKit
import UIKit

/// Opens StarHash and dials the main wallet's balance code (*182*6*1# on
/// MTN MoMo, the *182# menu on Airtel Money). Before a wallet is picked it
/// only opens StarHash, on onboarding, so nothing is dialled on a guess.
struct CheckBalanceIntent: AppIntent {
    static let title: LocalizedStringResource = "Check Wallet Balance"
    static let description = IntentDescription("Dials your MTN MoMo or Airtel Money balance code.")
    /// The dialer can only be opened from the foreground.
    static let openAppWhenRun = true

    @MainActor
    func perform() async throws -> some IntentResult {
        AppEnvironment.router.show(.pay)
        if let wallet = StarHashPreferences.chosenWallet, let url = USSD.telURL(for: USSD.balance(for: wallet)) {
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
        AppEnvironment.router.show(.pay)
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
                "Check my wallet balance with \(.applicationName)",
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
