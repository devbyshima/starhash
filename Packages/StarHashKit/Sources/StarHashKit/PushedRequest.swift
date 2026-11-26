import Foundation

/// A request as the server's push brings it to the iPhone asked, opened
/// there before iOS shows it (StarHash's Notification Service Extension),
/// so the banner can say who asks and for how much although neither the
/// server nor Apple can read it. The push carries the request sealed just
/// as the server keeps it, with the asker's public key; it is opened with
/// the owner's request key and shown only when it passes the checks the app
/// makes before it shows any request from anywhere (`RequestsAnywhere`):
/// sealed for this key by the key the asker's number is listed under, and
/// from someone in the owner's Contacts, by the name it is saved under
/// there. Anything else keeps the push's own words, "New request", and the
/// app decides when it opens.
public enum PushedRequest {
    /// What the push carries of the request: its id, what was sealed, and
    /// the public key of whoever sealed it. Nothing readable.
    public struct Sealed: Equatable, Sendable {
        public var id: UUID
        public var sealed: String
        public var key: String

        public init(id: UUID, sealed: String, key: String) {
            self.id = id
            self.sealed = sealed
            self.key = key
        }

        /// The push's `sealed` entry, as the Worker writes it.
        public init?(userInfo: [AnyHashable: Any]) {
            guard let entry = userInfo["sealed"] as? [String: Any],
                  let id = (entry["id"] as? String).flatMap(UUID.init(uuidString:)),
                  let sealed = entry["sealed"] as? String, let key = entry["key"] as? String,
                  RequestSeal.isPublicKey(key) else { return nil }
            self.init(id: id, sealed: sealed, key: key)
        }
    }

    /// Who the owner's Contacts say asks: their name there, nil when the
    /// number is in none of them, or `.cannotTell` when Contacts cannot be
    /// read (not allowed, or Enable contacts off), when the app waits too.
    public enum Contact: Equatable, Sendable {
        case saved(String)
        case unknown
        case cannotTell
    }

    /// A request fit to show, and the name to show it under.
    public struct Opened: Equatable, Sendable {
        public var ask: MoneyRequest.Message.Ask
        public var name: String
    }

    /// The request inside `pushed`, when the owner should see it now:
    /// sealed for `own` by `pushed.key` under its id, the asker's number
    /// listed under that same key (`lookUp`, the directory now), and the
    /// asker in the owner's Contacts (`contact`). Nil for anything else,
    /// whether the app will drop it or only cannot tell yet.
    public static func open(
        _ pushed: Sealed,
        with own: RequestSeal.PrivateKey,
        lookUp: (String) async -> RequestsAnywhere.LookUp,
        contact: (Recipient) async -> Contact
    ) async -> Opened? {
        guard let data = RequestSeal.open(pushed.sealed, id: pushed.id, purpose: .ask, with: own, from: pushed.key),
              case .ask(let ask) = MoneyRequest.Message(data: data), ask.id == pushed.id else { return nil }
        guard case .listed(let listed) = await lookUp(ask.number), listed.key == pushed.key else { return nil }
        guard case .saved(let name) = await contact(Recipient(name: ask.name, destination: ask.number, kind: .phone)) else { return nil }
        return Opened(ask: ask, name: name)
    }

    /// What the notification says: "Request for 1,500 RWF from Jean
    /// Bosco", the note under it; with amounts hidden on the Lock Screen
    /// (Settings, Notifications), who asks and nothing more.
    public static func text(for opened: Opened, showsAmounts: Bool) -> (title: String, body: String) {
        guard showsAmounts else { return (String(kit: "Request from \(opened.name)"), "") }
        return (String(kit: "Request for \(Money.formatWithCurrency(opened.ask.amount)) from \(opened.name)"), opened.ask.note ?? "")
    }
}
