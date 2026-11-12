import StarHashKit
import SwiftUI

/// Going back to one SIM with two numbers in: a sheet sized to its rows,
/// each SIM's number and network, and a tap keeps that one, the sheet's
/// Distortion Wave turning it into the SIM kept, with Done. A swipe down
/// keeps both, as they were.
struct KeepSIMSheet: View {
    let sims: [Recipient]
    let onKeep: (Recipient) -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var height: CGFloat = 300
    @State private var kept: Recipient?

    var body: some View {
        Group {
            if let kept {
                SheetOutcome(
                    symbol: "checkmark",
                    tint: .starhashConfirmed,
                    label: String(starhash: "Kept"),
                    title: kept.formattedDestination,
                    detail: kept.network?.walletName,
                    onDone: { dismiss() }
                )
            } else {
                question
            }
        }
        .sheetHeight(kept == nil ? $height : .constant(height))
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .ignoresSafeArea(.container, edges: .bottom)
        .sheetGlass(detents: [.height(height - 4)])
    }

    private func keep(_ sim: Recipient) {
        onKeep(sim)
        SheetOutcome.reveal(
            tint: .waveConfirmed,
            dark: colorScheme == .dark,
            reduceMotion: reduceMotion,
            feel: .success,
            show: { kept = sim }
        )
    }

    private var question: some View {
        VStack(spacing: 0) {
            SheetHeader("Which SIM do you keep?")

            VStack(spacing: 0) {
                ForEach(Array(sims.enumerated()), id: \.offset) { index, sim in
                    if index > 0 { SheetDivider().padding(.leading, 52) }
                    Button { keep(sim) } label: {
                        HStack(spacing: 14) {
                            SheetIconCircle(symbol: "simcard.fill")
                            VStack(alignment: .leading, spacing: 2) {
                                Text(verbatim: sim.formattedDestination)
                                    .font(.starhashNumber(17, relativeTo: .body))
                                    .foregroundStyle(Color.starhashPrimaryText)
                                if let network = sim.network {
                                    Text(verbatim: network.walletName)
                                        .font(.sheetSubheadline)
                                        .foregroundStyle(Color.sheetSecondaryText)
                                }
                            }
                            Spacer(minLength: 0)
                        }
                        .padding(.vertical, 8)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.hapticPlain)
                }
            }
            .padding(.horizontal, 16)
            .sheetCard()
            .padding(.horizontal, 18)
            .padding(.bottom, 24)
        }
    }
}
