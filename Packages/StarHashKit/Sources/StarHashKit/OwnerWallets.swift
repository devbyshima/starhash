import Foundation

/// The wallets the owner can pay from, worked out from their SIMs: each
/// SIM's carrier from its number (078 and 079 are MTN, 072 and 073
/// Airtel), so two SIMs on different carriers give MTN MoMo and Airtel
/// Money, each with the number it lives on. The wallet chosen on Pay is
/// always among them, even before its SIM's number is in; with no number
/// known at all, both carriers are offered.
public struct OwnerWallets: Equatable, Sendable {
    public struct Wallet: Equatable, Sendable, Identifiable {
        public let network: Recipient.Network
        /// The owner's SIM it lives on, when its number is in.
        public let sim: Recipient?
        public var id: Recipient.Network { network }
    }

    /// In the carriers' own order (MTN, then Airtel).
    public let wallets: [Wallet]
    public let chosen: Recipient.Network

    /// From the owner's numbers as typed, main SIM first.
    public init(numbers: [String], chosen: Recipient.Network) {
        let sims = numbers.compactMap(Recipient.ownNumber)
        self.chosen = chosen
        wallets = Recipient.Network.allCases.compactMap { network in
            let sim = sims.first { $0.network == network }
            guard sim != nil || network == chosen || sims.isEmpty else { return nil }
            return Wallet(network: network, sim: sim)
        }
    }

    /// Whether the owner has SIMs on both carriers.
    public var hasBothCarriers: Bool {
        wallets.filter { $0.sim != nil }.count > 1
    }

    /// Whose messages confirm payments, for copy: "M‑Money", or
    /// "M‑Money or Airtel Money" with SIMs on both carriers.
    public var messagesName: String {
        let owned = hasBothCarriers ? wallets.filter { $0.sim != nil }.map(\.network) : [chosen]
        guard owned.count == 2 else { return chosen.messagesName }
        return String(kit: "\(owned[0].messagesName) or \(owned[1].messagesName)")
    }
}
