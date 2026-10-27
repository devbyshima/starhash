import Foundation
import Observation

/// What the owner has told StarHash about themselves: their name, their
/// SIMs and the wallet they pay from, kept in UserDefaults. The one place
/// that reads and writes them, so the rules between them hold however
/// they change (Pay's menu, Settings, Profile, onboarding, a backup):
///
/// - A number is kept only once it is whole (a Rwandan mobile number), as
///   07XXXXXXXX; a field keeps what is half typed.
/// - The default SIM is the number the owner's code carries, and the one
///   payments are expected to dial from. With two SIMs and both numbers
///   in, it is always on the wallet's carrier: choosing a wallet makes the
///   SIM on it the default, and a new number moves the wallet to the
///   default SIM's carrier. With one, a number on the other carrier is
///   left as it is (`defaultSIMOnOtherCarrier`) for Profile to warn
///   about, since the owner may have a second SIM StarHash does not know.
/// - Going back to one SIM forgets the other number.
///
/// Whenever the owner's own accounts change (a number, the name, how many
/// SIMs), `onOwnAccountsChange` runs, so the store files their transfers
/// afresh.
@MainActor
@Observable
public final class Owner {
    /// As typed; empty when not given.
    public private(set) var name = ""
    /// The default SIM's number, once whole.
    public private(set) var defaultSIM: Recipient?
    /// The other SIM's number, once whole, while the owner pays from two.
    public private(set) var otherSIM: Recipient?
    /// Whether the owner said they pay from two SIMs (Settings' SIMs),
    /// whether or not the other number is in yet.
    public private(set) var usesTwoSIMs = false
    /// The wallet picked, nil before onboarding asks: what a Shortcuts or
    /// Siri action checks, since it can run before onboarding.
    public private(set) var chosenWallet: Recipient.Network?

    /// Runs after a change to the owner's own accounts (`ownAccounts`).
    @ObservationIgnored public var onOwnAccountsChange: (@MainActor () -> Void)?

    @ObservationIgnored private let defaults: UserDefaults

    private enum Key {
        static let name = "profileName"
        static let number = "profileNumber"
        static let simCount = "simCount"
        static let otherNumber = "secondNumber"
        static let wallet = "wallet"
    }

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        load()
        // At launch the wallet leads, so one chosen before there was a
        // default SIM stands.
        let loaded = (defaultSIM, otherSIM, chosenWallet)
        followWallet()
        followDefaultSIM()
        if loaded != (defaultSIM, otherSIM, chosenWallet) { save() }
    }

    // MARK: Reading

    /// MTN MoMo until the owner picks a wallet, which onboarding asks for
    /// before anything can be dialled.
    public var wallet: Recipient.Network { chosenWallet ?? .mtn }

    /// The wallets the owner can pay from, one for each SIM.
    public var wallets: OwnerWallets {
        OwnerWallets(numbers: [defaultSIM, otherSIM].compactMap { $0?.destination }, chosen: wallet)
    }

    /// The owner's own numbers, with two SIMs: money between them is moved,
    /// not spent or received.
    public var ownAccounts: OwnAccounts? {
        guard usesTwoSIMs else { return nil }
        return OwnAccounts(numbers: [defaultSIM, otherSIM].compactMap { $0?.destination }, name: name)
    }

    /// The owner's name and numbers, for a backup. The photo is kept apart.
    public var profile: OwnerProfile {
        OwnerProfile(name: name.isEmpty ? nil : name, number: defaultSIM?.destination, otherNumber: otherSIM?.destination)
    }

    /// Who the owner's code pays: the default SIM, under their name.
    public var codeRecipient: Recipient? { profile.recipient }

    /// The default SIM's carrier when it is not the wallet's, which only
    /// one SIM allows: Profile warns about it rather than changing either.
    public var defaultSIMOnOtherCarrier: Recipient.Network? {
        guard otherSIM == nil, let network = defaultSIM?.network, network != wallet else { return nil }
        return network
    }

    // MARK: Changing

    public func setName(_ name: String) {
        change { self.name = name }
    }

    /// Keeps `typed` as the default SIM's number once it is whole, forgets
    /// the number when nothing is typed, and leaves it while it is half
    /// typed. Returns whether `typed` is a whole number.
    @discardableResult
    public func setNumber(_ typed: String) -> Bool {
        if let sim = Recipient.ownNumber(typed) {
            change {
                defaultSIM = sim
                followDefaultSIM()
            }
            return true
        }
        if !typed.contains(where: \.isNumber) { change { defaultSIM = nil } }
        return false
    }

    /// `setNumber` for the other SIM, while the owner pays from two.
    @discardableResult
    public func setOtherNumber(_ typed: String) -> Bool {
        guard usesTwoSIMs else { return false }
        if let sim = Recipient.ownNumber(typed) {
            change {
                otherSIM = sim
                followDefaultSIM()
            }
            return true
        }
        if !typed.contains(where: \.isNumber) { change { otherSIM = nil } }
        return false
    }

    /// Two SIMs, the other's number still to come.
    public func useTwoSIMs() {
        change {
            usesTwoSIMs = true
            followDefaultSIM()
        }
    }

    /// Back to one SIM, forgetting the other number. With both numbers in,
    /// `sim` is the one that stays (ask the owner which): it becomes the
    /// default SIM and the wallet follows its carrier, since it is the one
    /// that pays now. Otherwise, or with `sim` nil, the default SIM stays,
    /// or the other one when it is the only number in.
    public func useOneSIM(keeping sim: Recipient? = nil) {
        change {
            if let both, let sim, let kept = [both.default, both.other].first(where: { $0.destination == sim.destination }) {
                defaultSIM = kept
                if let network = kept.network { chosenWallet = network }
            } else if defaultSIM == nil {
                defaultSIM = otherSIM
            }
            otherSIM = nil
            usesTwoSIMs = false
        }
    }

    /// The wallet chosen on Pay or in Settings: with a SIM, that SIM
    /// becomes the default, the one the code carries and payments dial
    /// from.
    public func choose(_ wallet: OwnerWallets.Wallet) {
        change {
            if let sim = wallet.sim, chosenWallet != nil { makeDefault(sim) } else { chosenWallet = wallet.network }
            followWallet()
            followDefaultSIM()
        }
    }

    /// The wallet picked during onboarding, before any number; nil forgets
    /// it, as a fresh install has none.
    public func choose(_ network: Recipient.Network?) {
        change {
            chosenWallet = network
            followWallet()
            followDefaultSIM()
        }
    }

    /// A backup's name and numbers, when the owner has given neither a
    /// name nor a number: a backup with a second number brings the second
    /// SIM back with it. Returns whether it was taken.
    @discardableResult
    public func restore(_ profile: OwnerProfile) -> Bool {
        guard name.isEmpty, defaultSIM == nil else { return false }
        change {
            name = profile.name ?? ""
            defaultSIM = profile.number.flatMap(Recipient.ownNumber)
            if let other = profile.otherNumber.flatMap(Recipient.ownNumber) {
                usesTwoSIMs = true
                otherSIM = other
            }
            followDefaultSIM()
        }
        return true
    }

    /// Reads everything again, after Delete All Data cleared it.
    public func reload() {
        change(saving: false) { load() }
    }

    // MARK: Keeping

    private func load() {
        name = defaults.string(forKey: Key.name) ?? ""
        defaultSIM = defaults.string(forKey: Key.number).flatMap(Recipient.ownNumber)
        usesTwoSIMs = defaults.integer(forKey: Key.simCount) == 2
        // Saved spaced before numbers were kept bare; read either.
        otherSIM = usesTwoSIMs ? defaults.string(forKey: Key.otherNumber).flatMap(Recipient.ownNumber) : nil
        chosenWallet = defaults.string(forKey: Key.wallet).flatMap(Recipient.Network.init(rawValue:))
    }

    private func save() {
        defaults.set(name, forKey: Key.name)
        defaults.set(defaultSIM?.destination ?? "", forKey: Key.number)
        defaults.set(usesTwoSIMs ? 2 : 1, forKey: Key.simCount)
        if let otherSIM {
            defaults.set(otherSIM.destination, forKey: Key.otherNumber)
        } else {
            defaults.removeObject(forKey: Key.otherNumber)
        }
        if let chosenWallet {
            defaults.set(chosenWallet.rawValue, forKey: Key.wallet)
        } else {
            defaults.removeObject(forKey: Key.wallet)
        }
    }

    /// Makes `body`'s change, saves it, and says so when the owner's own
    /// accounts are not what they were.
    private func change(saving: Bool = true, _ body: () -> Void) {
        let before = ownAccounts
        body()
        if saving { save() }
        if ownAccounts != before { onOwnAccountsChange?() }
    }

    // MARK: The default SIM

    /// Both numbers, when both are in and differ.
    private var both: (default: Recipient, other: Recipient)? {
        guard let defaultSIM, let otherSIM, defaultSIM.destination != otherSIM.destination else { return nil }
        return (defaultSIM, otherSIM)
    }

    /// `sim` as the default SIM: when it is the other one, the two numbers
    /// trade places, and the wallet follows its carrier.
    private func makeDefault(_ sim: Recipient) {
        if let both, both.other.destination == sim.destination {
            defaultSIM = both.other
            otherSIM = both.default
        }
        if let network = sim.network { chosenWallet = network }
    }

    /// After the wallet changes (or at launch): when the default SIM is on
    /// the other carrier and the other SIM on the wallet's, the other one
    /// becomes the default, so the wallet chosen stands.
    private func followWallet() {
        guard let both, let wallet = chosenWallet, both.default.network != wallet, both.other.network == wallet else { return }
        makeDefault(both.other)
    }

    /// After a number changes: the wallet follows the default SIM.
    private func followDefaultSIM() {
        guard let both, chosenWallet != nil, let network = both.default.network, network != chosenWallet else { return }
        chosenWallet = network
    }
}
