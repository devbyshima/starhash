import StarHashKit
import SwiftUI

/// The wallet just above Pay's keypad, where the amount's currency once
/// sat: the carrier's logo alone, straight on the page with nothing behind
/// it, and a menu to switch to the other wallet. Payments and Balance dial the new
/// wallet's codes from the next tap. (Rwanda's one currency needs no pill
/// of its own; the amount reads out with it.)
struct WalletPill: View {
    @AppStorage(PreferenceKey.wallet) private var wallet: Recipient.Network = .mtn

    var body: some View {
        Menu {
            Picker("Wallet", selection: $wallet) {
                ForEach(Recipient.Network.allCases, id: \.self) { network in
                    Label(network.walletName, image: network.logoAsset)
                }
            }
        } label: {
            // The logo alone, on the page: the menu names the wallets. The
            // tap area keeps the pill's size it once had.
            Image(wallet.logoAsset)
                .resizable()
                .scaledToFit()
                .frame(width: 40, height: 22)
                .padding(.horizontal, 16)
                .frame(minWidth: 72, minHeight: 36)
                .contentShape(Capsule())
                .animation(.smooth(duration: 0.25), value: wallet)
        }
        .menuOrder(.fixed)
        .buttonStyle(.hapticPlain)
        .sensoryFeedback(.selection, trigger: wallet)
        .accessibilityLabel("Wallet: \(wallet.walletName)")
        .accessibilityHint("Switches the wallet you pay from")
    }
}

/// A wallet's own logo, in the carrier's colours: MTN's black oval and
/// letters on yellow, Airtel's red swirl and wordmark. Full-colour vectors,
/// so they stay sharp at any size and look the same in menus. Used to tell
/// the wallets apart, not to stand for StarHash.
struct WalletLogo: View {
    let wallet: Recipient.Network
    /// The logo's height. Airtel's is square, MTN's twice as wide as tall.
    var height: CGFloat

    var body: some View {
        logo
            .scaledToFit()
            // Airtel's is square with the wordmark under the swirl, so a
            // little taller than MTN's oval to read at the same weight.
            .frame(height: wallet == .airtel ? height * 1.4 : height)
            .accessibilityHidden(true)
    }

    private var logo: some View {
        Image(wallet.logoAsset)
            .resizable()
    }
}

extension Recipient.Network {
    /// The logo's image in the asset catalog.
    var logoAsset: String {
        switch self {
        case .mtn: "MTNLogo"
        case .airtel: "AirtelLogo"
        }
    }
}
