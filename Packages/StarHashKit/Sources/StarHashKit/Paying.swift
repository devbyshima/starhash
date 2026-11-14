import Foundation

/// Paying someone, from the amount and recipient to the code dialled: the
/// one module Pay, Pay Again, a scanned code and the split payment sheet go
/// through. It refuses a recipient that cannot be paid, decides whether a
/// payment goes whole or in parts (`SplitPlan`, with Split Large Payments
/// on), records each payment before it is dialled (with Save Transactions
/// on), holds a split payment while its parts are sent, and puts the place
/// it was made on each payment once the location arrives, for Nearby.
///
/// What it cannot do itself sits behind its seam, handed in by the app and
/// by tests: dialling a code (`dial`), finding where the phone is
/// (`locate`), and asking whether a number is saved in Contacts
/// (`isContact`).
@MainActor
@Observable
public final class Paying {
    /// Dials a USSD code: the app opens its tel: link and says so when it
    /// cannot.
    public typealias Dial = @MainActor (_ code: String) -> Void
    /// Where the phone is, for Nearby: the best fix within a short wait,
    /// nil without one. `usable` hears the first fix good enough for
    /// Nearby's suggestions, before the best.
    public typealias Locate = @MainActor (_ usable: @escaping @MainActor (Transaction.Coordinate) -> Void) async -> Transaction.Coordinate?
    /// Whether a number is saved in Contacts: nil when Contacts cannot be
    /// read.
    public typealias IsContact = @MainActor (Recipient) async -> Bool?

    /// What `pay` did.
    public enum Outcome: Equatable, Sendable {
        /// Not paid: nothing typed, or a recipient that cannot be paid.
        case refused
        /// Recorded (when transactions are kept) and dialled.
        case dialled
        /// Cheaper in parts: `split` holds them, and nothing is dialled
        /// until `sendNextPart`.
        case split
    }

    /// How one part of `split` stands.
    public enum PartStatus: Equatable, Sendable {
        /// The part `sendNextPart` dials.
        case next
        /// After the next one.
        case notSent
        /// Dialled, with no record of it: Save Transactions is off.
        case dialled
        case pending
        case confirmed
        case failed
    }

    /// A payment going in parts, while its sheet is up. Kept in memory
    /// only: closing StarHash partway leaves the parts dialled in
    /// Transactions and drops the rest.
    public struct SplitPayment: Identifiable, Equatable, Sendable {
        /// The split's own id, carried by every part (`Transaction.Split`).
        public let id: UUID
        public let recipient: Recipient
        public let plan: SplitPlan
        /// The wallet the parts are dialled with, fixed when it began.
        public let wallet: Recipient.Network
        /// How many parts have been dialled, in order.
        public fileprivate(set) var dialled = 0
        /// Each dialled part's payment, by the part's index, when
        /// transactions are kept.
        public fileprivate(set) var payments: [Int: UUID] = [:]

        public var allDialled: Bool { dialled == plan.parts.count }
    }

    /// The split payment being sent, nil when there is none.
    public private(set) var split: SplitPayment?
    /// Where the phone is, once a fix good enough for Nearby has come
    /// since `prepare`: for the recipient screen's Nearby section.
    public private(set) var nearbyFix: Transaction.Coordinate?

    /// The location being found for the payment about to be made, and the
    /// store's ticket from when it started, so a fix that lands after
    /// Nearby was turned off or everything was erased is dropped.
    private struct Place {
        var location: Task<Transaction.Coordinate?, Never>?
        var ticket: StarHashStore.PlaceTicket?
    }

    private let store: StarHashStore
    private let owner: Owner
    private let defaults: UserDefaults
    private let dial: Dial
    private let locate: Locate
    private let isContact: IsContact
    private let dialDelay: Duration

    /// The place being found since `prepare`.
    private var place = Place()
    /// The place a split payment's parts share.
    private var splitPlace = Place()
    /// Which locating run is current, so a late fix from an older one is
    /// ignored.
    private var run = UUID()
    /// The latest place being put on a payment, so tests can wait for it.
    var placing: Task<Void, Never>?
    /// The location being found since `prepare`, so tests can wait for it.
    var locating: Task<Transaction.Coordinate?, Never>? { place.location }

    /// `dialDelay` is how long a whole payment waits before it is dialled,
    /// once recorded: the app's 0.4 seconds let the recipient screen or the
    /// parts sheet go first, so the call prompt comes up over the keypad.
    public init(
        store: StarHashStore,
        owner: Owner,
        defaults: UserDefaults = .standard,
        dialDelay: Duration = .milliseconds(400),
        dial: @escaping Dial,
        locate: @escaping Locate,
        isContact: @escaping IsContact
    ) {
        self.store = store
        self.owner = owner
        self.defaults = defaults
        self.dialDelay = dialDelay
        self.dial = dial
        self.locate = locate
        self.isContact = isContact
    }

    // MARK: Where

    /// A payment is about to be made: the recipient screen opened, or a
    /// recipient was chosen without it. With Nearby on, finding where the
    /// phone is starts now, so the fix is usually in hand by the time Pay
    /// is tapped; the payment never waits for it.
    public func prepare() {
        nearbyFix = nil
        let run = UUID()
        self.run = run
        place = Place(ticket: store.placeTicket())
        guard Preferences.nearbyLocation.value(in: defaults) else { return }
        place.location = Task { [weak self, locate] in
            await locate { fix in
                guard let self, self.run == run, self.nearbyFix == nil else { return }
                self.nearbyFix = fix
            }
        }
    }

    /// Back without paying: the fix found for it is dropped.
    public func forgetPlace() {
        place = Place()
        nearbyFix = nil
    }

    // MARK: Paying

    /// Pays `amount` to `recipient` from the owner's wallet: refused when
    /// nothing is typed or the recipient cannot be paid; held in `split`
    /// when Split Large Payments is on and parts cost less; otherwise
    /// recorded and dialled after `dialDelay`.
    @discardableResult
    public func pay(_ amount: Int, to recipient: Recipient) -> Outcome {
        guard amount > 0, recipient.isPayable else { return .refused }
        let place = place
        self.place = Place()
        nearbyFix = nil
        // Paid, however it was chosen: a Nearby suggestion passed over
        // before is suggested again.
        var misses = NearbyMisses.stored(in: defaults)
        misses.paid(recipient)
        misses.save(in: defaults)

        let wallet = owner.wallet
        if Preferences.splitLargePayments.value(in: defaults),
           let plan = SplitPlan.cheapest(sending: amount, to: recipient, from: wallet) {
            split = SplitPayment(id: UUID(), recipient: recipient, plan: plan, wallet: wallet)
            splitPlace = place
            return .split
        }
        send(amount, to: recipient, wallet: wallet, split: nil, place: place, after: dialDelay)
        return .dialled
    }

    // MARK: A split payment

    /// Dials the next part of `split`.
    public func sendNextPart() {
        guard var split, !split.allDialled else { return }
        let index = split.dialled
        if let id = sendPart(index, of: split) { split.payments[index] = id }
        split.dialled = index + 1
        self.split = split
    }

    /// Whether the last part dialled can be dialled again: a call cancelled
    /// at the system's prompt. Not once its message confirmed it, or it
    /// failed.
    public var canDialPartAgain: Bool {
        guard let split, split.dialled > 0 else { return false }
        let status = status(ofPart: split.dialled - 1)
        return status == .pending || status == .dialled
    }

    /// Dials the last part dialled again: the same payment, not a second.
    public func dialPartAgain() {
        guard canDialPartAgain, var split else { return }
        let index = split.dialled - 1
        if let id = sendPart(index, of: split) { split.payments[index] = id }
        self.split = split
    }

    /// Sends the whole amount as one payment instead, before any part has
    /// gone.
    public func sendWhole() {
        guard let split, split.dialled == 0 else { return }
        self.split = nil
        send(split.plan.amount, to: split.recipient, wallet: split.wallet, split: nil, place: splitPlace, after: dialDelay)
        splitPlace = Place()
    }

    /// Done with the split payment: the parts not dialled are not sent.
    public func stop() {
        split = nil
        splitPlace = Place()
    }

    /// How part `index` of `split` stands.
    public func status(ofPart index: Int) -> PartStatus {
        guard let split else { return .notSent }
        if index >= split.dialled { return index == split.dialled ? .next : .notSent }
        guard let id = split.payments[index], let payment = store.transaction(id: id) else { return .dialled }
        switch payment.status {
        case .pending: return .pending
        case .confirmed: return .confirmed
        case .failed: return .failed
        }
    }

    // MARK: Sending

    /// Records part `index` (again, for a retry: the store keeps it one
    /// payment) and dials it at once, the sheet staying up.
    private func sendPart(_ index: Int, of split: SplitPayment) -> UUID? {
        let part = Transaction.Split(id: split.id, part: index + 1, count: split.plan.parts.count, total: split.plan.amount)
        return send(split.plan.parts[index], to: split.recipient, wallet: split.wallet, split: part, place: splitPlace, after: .zero)
    }

    /// Records the payment when transactions are kept, then dials it after
    /// `delay`, and puts its place on it once the location arrives.
    @discardableResult
    private func send(
        _ amount: Int, to recipient: Recipient, wallet: Recipient.Network,
        split: Transaction.Split?, place: Place, after delay: Duration
    ) -> UUID? {
        var recordedID: UUID?
        if Preferences.saveTransactions.value(in: defaults) {
            recordedID = store.recordPayment(to: recipient, amount: amount, wallet: wallet, split: split).id
        }
        let code = USSD.payment(to: recipient, amount: amount, from: wallet)
        if delay == .zero {
            dial(code)
        } else {
            Task { [dial] in
                try? await Task.sleep(for: delay)
                dial(code)
            }
        }
        if let recordedID { putPlace(place, on: recordedID, paidTo: recipient) }
        return recordedID
    }

    /// The place goes on the payment once it arrives, never before
    /// dialling: its map, and what Nearby suggests from, when
    /// `Nearby.remembersPlace` allows. Nearby turned off while it was
    /// coming drops it here; everything erased drops it in the store.
    private func putPlace(_ place: Place, on id: UUID, paidTo recipient: Recipient) {
        guard let location = place.location, let ticket = place.ticket else { return }
        placing = Task { [store, defaults, isContact] in
            guard let fix = await location.value, Preferences.nearbyLocation.value(in: defaults) else { return }
            let saved = recipient.kind == .phone ? await isContact(recipient) : nil
            guard Nearby.remembersPlace(of: recipient, isContact: saved) else { return }
            store.attachPlace(fix, to: id, ticket: ticket)
        }
    }
}

extension NearbyMisses {
    /// Where the misses are kept, with the preferences, so Delete All Data
    /// clears them with the rest.
    public static let key = "nearbyMisses"

    /// The misses kept in `defaults`, or none yet.
    public static func stored(in defaults: UserDefaults) -> NearbyMisses {
        defaults.data(forKey: key).flatMap { try? JSONDecoder().decode(NearbyMisses.self, from: $0) } ?? NearbyMisses()
    }

    /// Keeps these misses in `defaults`.
    public func save(in defaults: UserDefaults) {
        defaults.set(try? JSONEncoder().encode(self), forKey: Self.key)
    }
}
