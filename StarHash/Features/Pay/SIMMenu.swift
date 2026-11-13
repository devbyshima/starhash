import StarHashKit
import SwiftUI

/// The owner's wallets as a menu, one for each SIM (both carriers before
/// any number is in), each with its logo, its name and its SIM's number,
/// the one in use checked: Pay's wallet and Settings' Default SIM. The one
/// chosen becomes the default SIM, the number the QR code carries and the
/// SIM payments dial from, and the wallet follows its carrier
/// (`Owner`). The first time an owner with two SIMs changes it, the
/// hint to make it the iPhone's default voice line, since iOS dials every
/// code there.
struct SIMMenu<Label: View>: View {
    /// Opens the hint for the wallet not in use, for screenshots
    /// (`-voiceLineHint`); one menu on screen answers it.
    var answersDebugHint = false
    @ViewBuilder let label: () -> Label

    @AppStorage(PreferenceKey.seenVoiceLineHint) private var seenVoiceLineHint = false
    @Environment(Owner.self) private var owner
    private var ownWallets: OwnerWallets { owner.wallets }
    /// The wallet just chosen, while the voice line hint is up.
    @State private var hintFor: OwnerWallets.Wallet?

    var body: some View {
        Menu {
            // Toggles rather than a picker: a picker's rows drop the second
            // line, and the SIM's number is what tells two wallets apart.
            ForEach(ownWallets.wallets) { option in
                Toggle(isOn: Binding(
                    get: { ownWallets.selected?.id == option.id },
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
            label()
        }
        .menuOrder(.fixed)
        .sensoryFeedback(.selection, trigger: ownWallets.selected?.id)
        .sheet(item: $hintFor) { option in
            VoiceLineHintSheet(wallet: option, sharesCarrier: ownWallets.hasTwoSIMs && !ownWallets.hasBothCarriers)
        }
        #if DEBUG
        .task {
            guard answersDebugHint, DebugLaunch.arguments.contains("-voiceLineHint") else { return }
            try? await Task.sleep(for: .milliseconds(500))
            hintFor = ownWallets.wallets.first { $0.id != ownWallets.selected?.id } ?? ownWallets.wallets.first
        }
        #endif
    }

    private func choose(_ option: OwnerWallets.Wallet) {
        guard option.id != ownWallets.selected?.id else { return }
        let twoSIMs = ownWallets.hasTwoSIMs
        owner.choose(option)
        if twoSIMs, option.sim != nil, !seenVoiceLineHint {
            seenVoiceLineHint = true
            hintFor = option
        }
    }
}
