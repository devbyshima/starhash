import StarHashKit
import SwiftUI

/// My Wallets: the MTN MoMo number StarHash pays from, marked Main, and
/// the wallets it cannot use yet, listed as coming soon.
struct WalletsView: View {
    @AppStorage(PreferenceKey.ownerNumber) private var ownerNumber = ""
    @State private var editsNumber = false

    /// Wallets with no USSD support in StarHash yet.
    private let upcoming: [(name: String, symbol: String)] = [
        ("Airtel Money", "antenna.radiowaves.left.and.right"),
        ("Bank of Kigali", "building.columns.fill"),
        ("Equity Bank", "building.columns.fill"),
        ("I&M Bank", "building.columns.fill"),
    ]

    var body: some View {
        List {
            Section {
                Button { editsNumber = true } label: {
                    SettingsRow(symbol: "simcard.fill", title: "MTN MoMo", caption: numberCaption) {
                        SettingsBadge(text: "Main", filled: true)
                    }
                }
                .buttonStyle(HighlightRowButtonStyle())
                .accessibilityHint("Change your MoMo number")
                .settingsCardRow(.single)
            } footer: {
                SettingsFootnote("StarHash pays from this wallet by dialling MTN MoMo's USSD codes for you.")
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
        .sheet(isPresented: $editsNumber) {
            MoMoNumberSheet()
        }
    }

    private var numberCaption: String {
        Recipient(input: ownerNumber)?.formattedDestination ?? "Add your MoMo number"
    }
}
