import AppIntents
import StarHashKit

/// The action a Shortcuts automation runs for every MoMo message: it reads
/// the SMS text, and when it is an MTN MoMo or Airtel Money transaction,
/// logs it (or confirms the payment StarHash dialled). Runs without opening
/// the app and shows nothing of its own, so the automation stays silent;
/// only a notification the owner turned on says what it did.
struct ProcessCarrierSMSIntent: AppIntent {
    static let title: LocalizedStringResource = "Process Carrier SMS"
    static let description = IntentDescription(
        "Reads an MTN MoMo or Airtel Money message and logs the transaction in StarHash. Other messages are ignored.",
        categoryName: "Transactions"
    )
    static let openAppWhenRun = false

    @Parameter(
        title: "Message",
        description: "The text of the MoMo SMS. In an automation, pass Shortcut Input.",
        inputOptions: String.IntentInputOptions(multiline: true)
    )
    var message: String

    static var parameterSummary: some ParameterSummary {
        Summary("Process \(\.$message)")
    }

    init() {}

    init(message: String) {
        self.message = message
    }

    /// Silent: the automation runs this for every message containing RWF,
    /// bank texts included, so it never puts a result on screen. A MoMo
    /// transaction shows up in Activity, with a notification only when one
    /// is turned on; anything else is ignored. (The setup guide shows its
    /// own success state for the sample.)
    @MainActor
    func perform() async throws -> some IntentResult {
        // Any run proves the shortcut reaches StarHash; the setup guide
        // watches this to show its success state.
        StarHashPreferences.markVerified()

        guard !AutoVerificationSample.isSample(message),
              StarHashPreferences.autoVerifyOn,
              StarHashPreferences.saveTransactions,
              let sms = CarrierSMS.parse(message) else { return .result() }
        let store = AppEnvironment.store
        let before = store.transactions
        let applied = store.apply(sms)
        // The one notification StarHash may add of its own, when asked to
        // on the Notifications page; the payment's reminder goes with it.
        await StarHashNotifications.shared.messageApplied(applied, previous: before.first { $0.id == applied.id })
        await StarHashNotifications.shared.sync()
        return .result()
    }
}

/// The sample message the setup guide sends through the shortcut to check
/// it works. It parses like a real merchant payment, so the whole path is
/// exercised, but the action recognises it and saves nothing.
enum AutoVerificationSample {
    /// What the guide tells the user to name the shortcut, and runs by name.
    static let shortcutName = "StarHash SMS"

    private static let marker = "STARHASH TEST"

    static let message = "TxId: 0000000000. Your payment of 1,000 RWF to \(marker) 000000 has been completed at 2024-01-01 12:00:00. Your new balance: 0 RWF. Fee was 0 RWF."

    static func isSample(_ text: String) -> Bool {
        text.localizedCaseInsensitiveContains(marker)
    }
}
