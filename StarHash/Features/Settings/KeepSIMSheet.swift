import StarHashKit
import SwiftUI

/// Going back to one SIM with two numbers in: a sheet sized to its rows,
/// each SIM's number and network, and a tap keeps that one. A swipe down
/// keeps both, as they were.
struct KeepSIMSheet: View {
    let sims: [Recipient]
    let onKeep: (Recipient) -> Void

    @State private var height: CGFloat = 300

    var body: some View {
        VStack(spacing: 0) {
            SheetHeader("Which SIM do you keep?")

            VStack(spacing: 0) {
                ForEach(Array(sims.enumerated()), id: \.offset) { index, sim in
                    if index > 0 { SheetDivider().padding(.leading, 52) }
                    Button { onKeep(sim) } label: {
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
        .sheetHeight($height)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .ignoresSafeArea(.container, edges: .bottom)
        .sheetGlass(detents: [.height(height - 4)])
    }
}
