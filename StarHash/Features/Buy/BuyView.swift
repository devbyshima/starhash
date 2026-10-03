import StarHashKit
import SwiftUI

/// Buy: airtime, data bundles and electricity, paid from the wallet. Each
/// opens its menu in the wallet itself (`USSD.purchase`), whose own prompts
/// ask for the number, the amount or the meter, and the PIN; StarHash
/// dials only the paths an operator has published, so no amount is filled
/// in for it. The code each one dials shows on its card, so it is never a
/// surprise. Nothing is logged in Activity: StarHash never learns the
/// amount.
struct BuyView: View {
    @AppStorage(PreferenceKey.wallet) private var wallet: Recipient.Network = .mtn

    /// A code the system would not dial (the simulator, an iPad), shown in
    /// an alert so it can be dialled by hand.
    @State private var undialledCode: String?

    var body: some View {
        VStack(spacing: 0) {
            PageHeader(page: .buy) { PageTitle(text: "Buy") } trailing: { WalletSwitcher() }

            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    ForEach(USSD.Purchase.allCases) { purchase in
                        BuyCard(purchase: purchase, code: USSD.purchase(purchase, from: wallet)) {
                            dial(USSD.purchase(purchase, from: wallet))
                        }
                    }
                    Text(footnote)
                        .starhashFont(13.5, weight: .medium, relativeTo: .footnote)
                        .foregroundStyle(Color.starhashSecondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.horizontal, 8)
                        .padding(.top, 8)
                }
                .padding(.horizontal, StarHashMetrics.screenPadding)
                .padding(.top, 20)
                .padding(.bottom, 16)
                .starhashReadableWidth(StarHashMetrics.narrowReadableWidth)
            }
            .scrollIndicators(.hidden)
            .scrollBounceBehavior(.basedOnSize)
            .starhashTabBarFollowsScroll()
        }
        .starhashTabBarClearance()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.starhashBackground.ignoresSafeArea())
        .animation(.smooth(duration: 0.25), value: wallet)
        .alert(
            "Can't dial on this device",
            isPresented: Binding(get: { undialledCode != nil }, set: { if !$0 { undialledCode = nil } }),
            presenting: undialledCode
        ) { code in
            Button("Copy Code") {
                UIPasteboard.general.string = code
                UINotificationFeedbackGenerator().notificationOccurred(.success)
            }
            Button("OK", role: .cancel) {}
        } message: { code in
            Text("Dial \(code) on your phone to buy.")
        }
    }

    /// The same for every wallet: electricity opens Rwanda Energy Group's
    /// menu rather than the wallet's, so it names neither.
    private var footnote: String {
        "Each opens its menu in your phone's dialler. It asks for the number, the amount or the meter, then your PIN, and nothing is paid until you confirm there."
    }

    private func dial(_ code: String) {
        Task {
            if await !USSDDialer.dial(code) {
                undialledCode = code
            }
        }
    }
}

/// One thing to buy: its symbol on a tile, what it is, a line on what the
/// wallet will ask for, and the code it dials, in a card the width of the
/// page. The whole card is the button.
private struct BuyCard: View {
    let purchase: USSD.Purchase
    let code: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                SymbolTile(symbol: purchase.symbol, size: 46)
                VStack(alignment: .leading, spacing: 3) {
                    Text(purchase.title)
                        .starhashFont(18, weight: .bold, relativeTo: .headline)
                        .foregroundStyle(Color.starhashPrimaryText)
                    Text(purchase.caption)
                        .starhashFont(14, weight: .medium, relativeTo: .subheadline)
                        .foregroundStyle(Color.starhashTertiaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 8)
                VStack(alignment: .trailing, spacing: 6) {
                    Image(systemName: "arrow.up.right")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Color.starhashTertiaryText)
                    Text(code)
                        .starhashFont(13, weight: .medium, relativeTo: .footnote)
                        .foregroundStyle(Color.starhashTertiaryText)
                        .lineLimit(1)
                        .contentTransition(.opacity)
                }
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.starhashCard, in: RoundedRectangle(cornerRadius: StarHashMetrics.cardRadius, style: .continuous))
            .contentShape(RoundedRectangle(cornerRadius: StarHashMetrics.cardRadius, style: .continuous))
        }
        .buttonStyle(PressScaleButtonStyle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Buy \(purchase.title)")
        .accessibilityHint("Dials \(code) and opens your wallet's menu")
        .accessibilityAddTraits(.isButton)
    }
}

extension USSD.Purchase {
    var title: String {
        switch self {
        case .airtime: "Airtime"
        case .bundles: "Data bundles"
        case .electricity: "Electricity"
        }
    }

    var caption: String {
        switch self {
        case .airtime: "For your number or someone else's"
        case .bundles: "Internet, from the bundles on offer"
        case .electricity: "Cash Power, with your meter number"
        }
    }

    var symbol: String {
        switch self {
        case .airtime: "phone.fill"
        case .bundles: "antenna.radiowaves.left.and.right"
        case .electricity: "bolt.fill"
        }
    }
}
