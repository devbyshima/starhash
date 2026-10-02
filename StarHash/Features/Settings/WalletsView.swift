import StarHashKit
import SwiftUI

/// My Wallets: MTN MoMo and Airtel Money, one of them marked Main (the
/// one StarHash dials codes for; a tap on the other switches), and the
/// wallets it cannot use yet, listed as coming soon.
struct WalletsView: View {
    @AppStorage(PreferenceKey.wallet) private var wallet: Recipient.Network = .mtn

    /// Wallets with no USSD support in StarHash yet.
    private let upcoming: [(name: String, symbol: String)] = [
        ("Bank of Kigali", "building.columns.fill"),
        ("Equity Bank", "building.columns.fill"),
        ("I&M Bank", "building.columns.fill"),
    ]

    var body: some View {
        List {
            Section {
                ForEach(Array(Recipient.Network.allCases.enumerated()), id: \.element) { index, network in
                    Button {
                        withAnimation(.snappy(duration: 0.2)) { wallet = network }
                    } label: {
                        SettingsRow(symbol: network.symbol, title: network.walletName, caption: network.prefixes) {
                            if wallet == network {
                                SettingsBadge(text: "Main", filled: true)
                            }
                        }
                    }
                    .buttonStyle(HighlightRowButtonStyle())
                    .accessibilityAddTraits(wallet == network ? .isSelected : [])
                    .accessibilityHint(wallet == network ? "" : "Pay from \(network.walletName)")
                    .settingsCardRow(SettingsCardPosition(index: index, count: Recipient.Network.allCases.count))
                }
            } footer: {
                SettingsFootnote("StarHash pays from your main wallet by dialling its USSD codes for you.")
            }

            Section {
                SettingsSectionTitle("Coming soon")
                ForEach(Array(upcoming.enumerated()), id: \.offset) { index, wallet in
                    SettingsRow(symbol: wallet.symbol, title: wallet.name) {
                        SettingsBadge(text: "Coming soon")
                    }
                    .opacity(0.55)
                    .accessibilityElement(children: .combine)
                    .accessibilityAddTraits(.isStaticText)
                    .settingsCardRow(SettingsCardPosition(index: index, count: upcoming.count))
                }
            }
        }
        .settingsListStyle(sectionSpacing: 14)
        .settingsPage("My Wallets")
    }
}
