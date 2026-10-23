import StarHashKit
import SwiftUI

/// The wallet just above Pay's keypad, where the amount's currency once
/// sat: the carrier's logo alone, straight on the page with nothing behind
/// it, and a menu of the owner's wallets, each with the SIM it lives on
/// (two SIMs on different carriers give both). Payments and Balance dial
/// the new wallet's codes from the next tap. (Rwanda's one currency needs
/// no pill of its own; the amount reads out with it.)
struct WalletPill: View {
    @AppStorage(PreferenceKey.wallet) private var wallet: Recipient.Network = .mtn
    @AppStorage(PreferenceKey.seenVoiceLineHint) private var seenVoiceLineHint = false
    @OwnWallets private var ownWallets
    /// The wallet just switched to, while the voice line hint is up.
    @State private var hintFor: OwnerWallets.Wallet?

    var body: some View {
        Menu {
            // Toggles rather than a picker: a picker's rows drop the second
            // line, and the SIM's number is what tells two wallets apart.
            ForEach(ownWallets.wallets) { option in
                Toggle(isOn: Binding(
                    get: { wallet == option.network },
                    set: { if $0 { choose(option) } }
                )) {
                    // Straight in the row, so the menu reads the logo as its
                    // icon and the number as the line under the name.
                    Image(option.network.logoAsset)
                    Text(verbatim: option.network.walletName)
                    if let sim = option.sim {
                        Text(verbatim: sim.formattedDestination)
                    }
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
        .sheet(item: $hintFor) { option in
            VoiceLineHintSheet(wallet: option)
        }
        #if DEBUG
        // -voiceLineHint: the hint for the wallet not chosen, for screenshots.
        .task {
            guard DebugLaunch.arguments.contains("-voiceLineHint") else { return }
            try? await Task.sleep(for: .milliseconds(500))
            hintFor = ownWallets.wallets.first { $0.network != wallet } ?? ownWallets.wallets.first
        }
        #endif
    }

    /// The wallet switched to, and the first time an owner with SIMs on both
    /// carriers switches, the hint to make that SIM the iPhone's voice line.
    private func choose(_ option: OwnerWallets.Wallet) {
        guard option.network != wallet else { return }
        wallet = option.network
        if ownWallets.hasBothCarriers, !seenVoiceLineHint {
            seenVoiceLineHint = true
            hintFor = option
        }
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
