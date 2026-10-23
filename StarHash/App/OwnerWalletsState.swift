import StarHashKit
import SwiftUI

/// The owner's wallets (`OwnerWallets`) as a view's own value, worked out
/// afresh whenever a number, the count of SIMs or the wallet changes.
@propertyWrapper
struct OwnWallets: DynamicProperty {
    @AppStorage(PreferenceKey.profileNumber) private var profileNumber = ""
    @AppStorage(PreferenceKey.secondNumber) private var secondNumber = ""
    @AppStorage(PreferenceKey.simCount) private var simCount = 1
    @AppStorage(PreferenceKey.wallet) private var wallet: Recipient.Network = .mtn

    var wrappedValue: OwnerWallets {
        OwnerWallets(numbers: [profileNumber] + (simCount == 2 ? [secondNumber] : []), chosen: wallet)
    }
}

extension StarHashPreferences {
    /// The owner's SIMs and wallet as Settings keeps them, nil before
    /// onboarding has asked for the wallet.
    static var ownerSIMs: OwnerSIMs? {
        let defaults = UserDefaults.standard
        guard let wallet = chosenWallet else { return nil }
        return OwnerSIMs(
            number: defaults.string(forKey: PreferenceKey.profileNumber) ?? "",
            otherNumber: defaults.integer(forKey: PreferenceKey.simCount) == 2 ? defaults.string(forKey: PreferenceKey.secondNumber) ?? "" : nil,
            wallet: wallet
        )
    }

    /// Writes back what changed of `sims`.
    static func save(_ sims: OwnerSIMs) {
        guard sims != ownerSIMs else { return }
        let defaults = UserDefaults.standard
        defaults.set(sims.number, forKey: PreferenceKey.profileNumber)
        if let other = sims.otherNumber { defaults.set(other, forKey: PreferenceKey.secondNumber) }
        defaults.set(sims.wallet.rawValue, forKey: PreferenceKey.wallet)
    }

    /// The wallet chosen on Pay or in Settings: with a SIM, it becomes the
    /// default SIM, the one the QR code carries and payments dial from.
    static func choose(_ wallet: OwnerWallets.Wallet) {
        guard var sims = ownerSIMs else {
            UserDefaults.standard.set(wallet.network.rawValue, forKey: PreferenceKey.wallet)
            return
        }
        if let sim = wallet.sim { sims.makeDefault(sim) } else { sims.wallet = wallet.network }
        save(sims)
    }
}

extension View {
    /// Keeps the default SIM on the wallet's carrier however either
    /// changes (Pay's menu, Settings, Profile, a backup): a new wallet
    /// makes the SIM on it the default, and a new number moves the wallet
    /// to the default SIM's carrier. At launch the wallet leads too, so one
    /// chosen before there was a default SIM stands.
    func keepsDefaultSIMInStep() -> some View {
        modifier(DefaultSIMInStep())
    }
}

private struct DefaultSIMInStep: ViewModifier {
    @AppStorage(PreferenceKey.profileNumber) private var profileNumber = ""
    @AppStorage(PreferenceKey.secondNumber) private var secondNumber = ""
    @AppStorage(PreferenceKey.simCount) private var simCount = 1
    @AppStorage(PreferenceKey.wallet) private var wallet = ""

    func body(content: Content) -> some View {
        content
            // The wallet leads; one on a carrier neither SIM is on goes to
            // the default SIM's.
            .onChange(of: wallet, initial: true) {
                update {
                    $0.followWallet()
                    $0.followDefaultSIM()
                }
            }
            .onChange(of: [profileNumber, secondNumber, String(simCount)]) { update { $0.followDefaultSIM() } }
    }

    private func update(_ change: (inout OwnerSIMs) -> Void) {
        guard var sims = StarHashPreferences.ownerSIMs else { return }
        change(&sims)
        StarHashPreferences.save(sims)
    }
}
