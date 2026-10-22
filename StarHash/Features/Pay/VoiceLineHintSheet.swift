import StarHashKit
import SwiftUI

/// Shown once, the first time an owner with SIMs on both carriers switches
/// wallet: iOS dials a code on the iPhone's default voice line, and no app
/// can choose the SIM, so the wallet just chosen only answers when its SIM
/// is that line. Both carriers use *182#, so a code on the wrong SIM would
/// reach the other wallet. The steps to set it, as the Settings app names
/// them, and Got It.
struct VoiceLineHintSheet: View {
    let wallet: OwnerWallets.Wallet

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

    var body: some View {
        VStack(spacing: 0) {
            SheetHeader(String(starhash: "Dial from your \(wallet.network.name) SIM"))

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
