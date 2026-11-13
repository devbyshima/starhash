import StarHashKit
import SwiftUI

/// Shown once, the first time an owner with two SIMs changes the default
/// one: iOS dials a code on the iPhone's default voice line, and no app
/// can choose the SIM, so the SIM just chosen only answers when it is that
/// line. Both carriers use *182#, so a code on the wrong SIM would reach
/// the other wallet, or on one carrier the other SIM's account. The steps
/// to set it, as the Settings app names them, and Got It.
struct VoiceLineHintSheet: View {
    let wallet: OwnerWallets.Wallet
    /// Both SIMs on one carrier: the title names the number, not the carrier.
    var sharesCarrier = false

    @Environment(\.dismiss) private var dismiss
    @State private var height: CGFloat = 420

    private var steps: [(symbol: String, text: String)] {
        let sim = wallet.sim?.formattedDestination ?? wallet.network.name
        return [
            ("gearshape.fill", String(starhash: "Open Settings, then Cellular or Mobile Service")),
            ("phone.fill", String(starhash: "Tap Default Voice Line")),
            ("simcard.fill", String(starhash: "Choose the SIM with \(sim)")),
        ]
    }

    private var title: String {
        if sharesCarrier, let sim = wallet.sim {
            return String(starhash: "Dial from \(sim.formattedDestination)")
        }
        return String(starhash: "Dial from your \(wallet.network.name) SIM")
    }

    var body: some View {
        VStack(spacing: 0) {
            SheetHeader(title)

            VStack(spacing: 14) {
                VStack(spacing: 0) {
                    ForEach(Array(steps.enumerated()), id: \.offset) { index, step in
                        if index > 0 { SheetDivider().padding(.leading, 52) }
                        HStack(spacing: 14) {
                            SheetIconCircle(symbol: step.symbol)
                            Text(verbatim: step.text)
                                .font(.sheetBody)
                                .foregroundStyle(Color.starhashPrimaryText)
                                .fixedSize(horizontal: false, vertical: true)
                            Spacer(minLength: 0)
                        }
                        .padding(.vertical, 8)
                        .accessibilityElement(children: .combine)
                    }
                }
                .padding(.horizontal, 16)
                .sheetCard()

                Button("Got It") { dismiss() }
                    .buttonStyle(.sheetPrimary)
                    .padding(.top, 4)
            }
            .padding(.horizontal, 18)
            .padding(.bottom, 24)
        }
        .sheetHeight($height)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .ignoresSafeArea(.container, edges: .bottom)
        .sheetGlass(detents: [.height(height - 4)])
    }
}
