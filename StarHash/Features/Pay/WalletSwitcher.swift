import StarHashKit
import SwiftUI

/// The button at the top right of Pay: the main wallet's logo alone, in
/// the same 44pt glass circle as the menu button opposite, and a menu to switch to
/// the other wallet, as My Wallets does. Payments and Balance dial the new
/// wallet's codes from the next tap.
struct WalletSwitcher: View {
    @AppStorage(PreferenceKey.wallet) private var wallet: Recipient.Network = .mtn

    var body: some View {
        Menu {
            Picker("Wallet", selection: $wallet) {
                ForEach(Recipient.Network.allCases, id: \.self) { network in
                    Label(network.name, image: network.logoAsset)
                }
            }
        } label: {
            // Fitted inside the circle: MTN's oval by its width, Airtel's
            // square by its height, so both sit with the same margin.
            Image(wallet.logoAsset)
                .resizable()
                .scaledToFit()
                .frame(width: 30, height: 26)
                .starhashCircleButton()
                .animation(.smooth(duration: 0.25), value: wallet)
        }
        .menuOrder(.fixed)
        .buttonStyle(.plain)
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
        Image(wallet.logoAsset)
            .resizable()
            .scaledToFit()
            // Airtel's is square with the wordmark under the swirl, so a
            // little taller than MTN's oval to read at the same weight.
            .frame(height: wallet == .airtel ? height * 1.4 : height)
            .accessibilityHidden(true)
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
