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

    /// Who sent it, so a look-alike from someone's own number is caught.
    /// Optional: a shortcut set up before StarHash asked for it passes
    /// none, and then only the message's wording is checked.
    @Parameter(
        title: "Sender",
        description: "Who sent the message. In an automation, pass Shortcut Input's Sender."
    )
    var sender: String?

    static var parameterSummary: some ParameterSummary {
        Summary("Process \(\.$message) from \(\.$sender)")
    }

    init() {}

    init(message: String, sender: String? = nil) {
        self.message = message
        self.sender = sender
    }

    /// Silent: the automation runs this for every message containing RWF,
    /// bank texts included, so it never puts a result on screen. What the
    /// message does is `AutoVerify.receive`'s; this only says so when a
    /// notification is turned on, and reschedules the rest.
    @MainActor
    func perform() async throws -> some IntentResult {
        let outcome = AppEnvironment.autoVerify.receive(message, sender: sender)
        await StarHashNotifications.shared.announce(outcome)
        if outcome.reachedTransactions { await StarHashNotifications.shared.sync() }
        return .result()
    }
}
