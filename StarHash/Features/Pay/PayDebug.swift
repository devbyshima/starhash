#if DEBUG
import StarHashKit

/// Launch arguments for Pay's screenshots (DEBUG builds only):
///   -payAmount <n>       start with this amount on the keypad
///   -payPicker           open the recipient picker
///   -payQuery <text>     open the picker with this in its search field
///   -payChooser          (with -payPicker) the number chooser for the
///                        first contact with several numbers
///   -payChosen <input>   a recipient already chosen, as Pay Again leaves
///                        it when no amount is typed
///   -payShake            taps Pay with nothing typed three times, to
///                        record the amount's shake
///   -payPick <seconds>   (with -payPicker) chooses the first recent
///                        recipient after this long, to record the way back
@MainActor
enum PayDebug {
    static var shakes: Bool { DebugLaunch.arguments.contains("-payShake") }
    static var picksAfter: Double? { DebugLaunch.value(after: "-payPick").flatMap(Double.init) }

    static var amount: Int? { DebugLaunch.value(after: "-payAmount").flatMap(Int.init) }
    static var opensPicker: Bool { DebugLaunch.arguments.contains("-payPicker") || query != nil }
    static var query: String? { DebugLaunch.value(after: "-payQuery") }

    static func chosenRecipient(in store: StarHashStore) -> Recipient? {
        DebugLaunch.value(after: "-payChosen").flatMap { named($0, in: store) }
    }

    /// The typed number or code, named from recents when it matches one.
    private static func named(_ input: String, in store: StarHashStore) -> Recipient? {
        guard var recipient = Recipient(input: input) else { return nil }
        recipient.name = store.recentRecipients(limit: 50)
            .first { $0.destination == recipient.destination }?.name
        return recipient
    }
}
#endif
