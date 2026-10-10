import Foundation

/// What a payment was for. Kept in `Transaction.category` by raw value, so
/// a label the app no longer lists still shows under its own name. The
/// first five are things bought from a carrier or a utility (airtime, a
/// bundle, electricity, water, a TV subscription), which Activity shows as
/// bought rather than sent.
public enum TransactionCategory: String, CaseIterable, Codable, Identifiable, Sendable {
    case airtime
    case bundles
    case electricity
    case water
    case tv
    case restaurant
    case groceries
    case transport
    case bills
    case shopping
    case health
    case education
    case family
    case savings
    case other

    public var id: Self { self }

    /// Bought rather than sent: airtime, a bundle, electricity, water or
    /// TV.
    public var isPurchase: Bool {
        switch self {
        case .airtime, .bundles, .electricity, .water, .tv: true
        default: false
        }
    }

    /// The categories a person can choose for a payment, purchases first.
    public static let choices: [TransactionCategory] = allCases
}

extension Transaction {
    /// The category as one StarHash knows, nil for none or a label it no
    /// longer lists.
    public var knownCategory: TransactionCategory? {
        category.flatMap(TransactionCategory.init(rawValue:))
    }

    /// A purchase from a carrier or utility (airtime, a bundle,
    /// electricity, water, TV) rather than money sent to someone.
    public var isPurchase: Bool {
        direction == .outgoing && (knownCategory?.isPurchase ?? false)
    }
}

/// Works out a payment's category from what is known of it: the name it was
/// paid to and, for one read from an SMS, the message's own words. Rules
/// only, quick enough for the Shortcuts action; the app asks the on-device
/// model about the names these leave out.
public enum TransactionCategorizer {
    /// The category `name` (and `message`, for a purchase's message) points
    /// to, or nil when nothing does. A payment to a person is left alone:
    /// who they are says nothing of what it was for.
    public static func category(name: String?, message: String? = nil, kind: Recipient.Kind = .merchant) -> TransactionCategory? {
        if let message, let found = match(message.lowercased(), in: messageRules) { return found }
        guard kind == .merchant, let name, !name.isEmpty else { return nil }
        return match(" " + name.lowercased() + " ", in: nameRules)
    }

    /// The category of `transaction`, from its counterparty's name.
    public static func category(of transaction: Transaction) -> TransactionCategory? {
        guard transaction.direction == .outgoing else { return nil }
        return category(name: transaction.counterparty.name, kind: transaction.counterparty.kind)
    }

    private static func match(_ text: String, in rules: [(TransactionCategory, [String])]) -> TransactionCategory? {
        for (category, words) in rules where words.contains(where: { text.contains($0) }) {
            return category
        }
        return nil
    }

    /// Words in a purchase's message that say what was bought ("You have
    /// bought 1,000 RWF of airtime"). Only for a message that says it bought
    /// something: MoMo's transfers end with an advert for airtime.
    private static let messageRules: [(TransactionCategory, [String])] = [
        (.airtime, ["airtime"]),
        (.bundles, ["bundle", "internet pack", "data pack", "gwamon"]),
        (.electricity, ["cash power", "cashpower", "electricity", "eucl", "token for meter"]),
        (.water, ["wasac", "water bill"]),
        (.tv, ["canal+", "canal +", "startimes", "dstv", "gotv"]),
    ]

    /// Words in a merchant's name, padded with spaces at either end so a
    /// short word only matches whole ("reg" in "REG", not "regional").
    private static let nameRules: [(TransactionCategory, [String])] = [
        (.airtime, ["airtime", " credit ", "recharge", "ama inite"]),
        (.bundles, ["bundle", "internet", " data ", "gwamon", "yolo", "4g", "fibre", "fiber", "liquid", "canalbox"]),
        (.electricity, ["eucl", " reg ", "cash power", "cashpower", "electricity", "electrogaz", "umuriro"]),
        (.water, ["wasac", " water ", "amazi"]),
        (.tv, ["canal+", "canal +", "canal plus", "startimes", "star times", "dstv", "gotv", "azam", " tv "]),
        (.transport, ["taxi", "yego", " move ", " bus ", "volcano", "ritco", "tap&go", "tap and go", "kbs", "express", "parking", "fuel", "engen", "merez", "kobil", "station", "moto"]),
        (.health, ["pharma", "clinic", "clinique", "hospital", "hopital", "hôpital", "health", "dental", "ivuriro", "gym", "fitness"]),
        (.bills, ["irembo", " rra ", "tax", "rssb", "mutuelle", "insurance", "assurance", "radiant", "sanlam"]),
        (.education, ["school", "ecole", "école", "college", "university", "universite", "academy", "ishuri", "lycee", "lycée", "urubuto", "tuition"]),
        (.groceries, ["supermarket", "super market", "simba", "ndoli", "market", "alimentation", "grocer", "frulep", "kigali hub", "sawa citi", "carrefour", "nakumatt"]),
        (.restaurant, ["restaurant", "resto", "cafe", "café", "coffee", "bar ", " bar", "pizza", "burger", "kfc", "java house", "brioche", "grill", "lounge", "bistro", "kitchen", "food", "pili-pili", "pili pili", "poivre", "bakery", "patisserie"]),
        (.shopping, ["shop", "boutique", "store", "mall", "fashion", "electronics", "hardware", "quincaillerie"]),
        (.savings, ["ejo heza", "savings", "sacco", " bank", "equity", "i&m", "bk ", "cogebanque", "ecobank", "access bank", "bpr"]),
    ]
}
