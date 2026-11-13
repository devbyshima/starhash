import Foundation

/// The wallets the owner can pay from, worked out from their SIMs: each
/// SIM's carrier from its number (078 and 079 are MTN, 072 and 073
/// Airtel), one wallet for each SIM, so two SIMs on one carrier give two
/// MTN MoMo (or Airtel Money) wallets told apart by their numbers, and two
/// on different carriers give MTN MoMo and Airtel Money. The first number
/// is the default SIM (`Owner`). The wallet chosen on Pay is always
/// among them, even before its SIM's number is in; with no number known
/// at all, both carriers are offered.
public struct OwnerWallets: Equatable, Sendable {
    public struct Wallet: Equatable, Sendable, Identifiable {
        public let network: Recipient.Network
        /// The owner's SIM it lives on, when its number is in.
        public let sim: Recipient?
        public var id: String { sim?.destination ?? network.rawValue }
    }

    /// In the carriers' own order (MTN, then Airtel), and by number on one
    /// carrier, so the menu keeps its order whichever SIM is the default.
    public let wallets: [Wallet]
    public let chosen: Recipient.Network
    /// The SIM the QR code carries and payments dial from: the first number.
    public let defaultSIM: Recipient?

    /// From the owner's numbers as typed, the default SIM first.
    public init(numbers: [String], chosen: Recipient.Network) {
        var sims: [Recipient] = []
        for sim in numbers.compactMap(Recipient.ownNumber) where !sims.contains(where: { $0.destination == sim.destination }) {
            sims.append(sim)
        }
        self.chosen = chosen
        defaultSIM = sims.first
        guard !sims.isEmpty else {
            wallets = Recipient.Network.allCases.map { Wallet(network: $0, sim: nil) }
            return
        }
        var found = sims.compactMap { sim in sim.network.map { Wallet(network: $0, sim: sim) } }
        if !found.contains(where: { $0.network == chosen }) { found.append(Wallet(network: chosen, sim: nil)) }
        let order = Recipient.Network.allCases
        wallets = found.sorted {
            let (a, b) = (order.firstIndex(of: $0.network) ?? 0, order.firstIndex(of: $1.network) ?? 0)
            return a != b ? a < b : ($0.sim?.destination ?? "") < ($1.sim?.destination ?? "")
        }
    }

    /// The wallet payments go from: the default SIM's when it is on the
    /// chosen carrier, otherwise the first on it.
    public var selected: Wallet? {
        wallets.first { $0.network == chosen && $0.sim != nil && $0.sim?.destination == defaultSIM?.destination }
            ?? wallets.first { $0.network == chosen }
    }

    /// Whether the owner has two SIMs with both numbers in, on one carrier
    /// or two: then which one is the default matters.
    public var hasTwoSIMs: Bool {
        wallets.filter { $0.sim != nil }.count > 1
    }

    /// Whether the owner has SIMs on both carriers.
    public var hasBothCarriers: Bool {
        Set(wallets.compactMap { $0.sim?.network }).count > 1
    }

    /// Whose messages confirm payments, for copy: "M‑Money", or
    /// "M‑Money or Airtel Money" with SIMs on both carriers.
    public var messagesName: String {
        guard hasBothCarriers else { return chosen.messagesName }
        let owned = Recipient.Network.allCases
        return String(kit: "\(owned[0].messagesName) or \(owned[1].messagesName)")
    }
}
