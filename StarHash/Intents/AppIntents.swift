import AppIntents
import StarHashKit
import UIKit

/// Opens StarHash and dials the main wallet's balance code (*182*6*1# on
/// MTN MoMo, the *182# menu on Airtel Money). Before a wallet is picked it
/// only opens StarHash, on onboarding, so nothing is dialled on a guess.
struct CheckBalanceIntent: AppIntent {
    static let title: LocalizedStringResource = "Check Wallet Balance"
    static let description = IntentDescription("Dials your MTN MoMo or Airtel Money balance code.")
    /// The dialer can only be opened from the foreground. iOS 26 reads
    /// `supportedModes`; before it, the flag. Drop the flag once StarHash
    /// needs iOS 26.
    static let openAppWhenRun = true
    @available(iOS 26.0, *)
    static var supportedModes: IntentModes { .foreground }

    @MainActor
    func perform() async throws -> some IntentResult {
        AppEnvironment.router.show(.pay)
        // Through the app's dialler, so a code it cannot dial shows on Pay
        // with the code to dial by hand.
        if let wallet = AppEnvironment.owner.chosenWallet {
            AppEnvironment.dialler.dial(USSD.balance(for: wallet))
        }
        return .result()
    }
}

/// Opens StarHash on the Pay tab, ready for an amount.
struct OpenPayIntent: AppIntent {
    static let title: LocalizedStringResource = "Pay with StarHash"
    static let description = IntentDescription("Opens StarHash's keypad to pay someone.")
    static let openAppWhenRun = true
    @available(iOS 26.0, *)
    static var supportedModes: IntentModes { .foreground }

    @MainActor
    func perform() async throws -> some IntentResult {
        AppEnvironment.router.show(.pay)
        return .result()
    }
}

/// Siri phrases and Spotlight entries for StarHash's actions. Their French
/// is in `Resources/AppShortcuts.xcstrings`, keyed by each phrase with
/// `${applicationName}` for the app's name (Localizable.xcstrings doesn't
/// reach them); a new phrase needs its French there too. Siri has no
/// Kinyarwanda, so there is none.
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
        // Not Process Carrier SMS: it is the auto-verify shortcut's action,
        // fed each message by the automation. Offered to Siri, Spotlight
        // and the Action button it only asked for an SMS's text with a
        // bare prompt. It stays an action in Shortcuts, which the shared
        // shortcut and a by-hand one use.
    }
}
