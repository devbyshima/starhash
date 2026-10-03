import SwiftUI

/// Asks before auto-verify goes off, in Beam's sheet language and sized to
/// its content: the question as the title, what it means under it, a card of the three things
/// that stop working, then Keep On (the filled button, the safe choice)
/// and Turn Off in red under it.
struct TurnOffAutoVerifySheet: View {
    let onTurnOff: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var height: CGFloat = 480

    private let losses: [(symbol: String, text: String)] = [
        ("clock", "Payments won't be confirmed"),
        ("arrow.down.left", "Money received won't be logged"),
        ("banknote", "Fees and balance won't fill in"),
    ]

    var body: some View {
        VStack(spacing: 0) {
            SheetHeader("Turn Off Auto-verify?")

            VStack(spacing: 14) {
                Text("StarHash will stop reading your M\u{2011}Money messages.")
                    .font(.sheetSubheadline)
                    .foregroundStyle(Color.sheetSecondaryText)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)

                VStack(spacing: 0) {
                    ForEach(Array(losses.enumerated()), id: \.offset) { index, loss in
                        if index > 0 { SheetDivider().padding(.leading, 52) }
                        HStack(spacing: 14) {
                            SheetIconCircle(symbol: loss.symbol)
                            Text(loss.text)
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

                VStack(spacing: 4) {
                    // The sheets' one button colour, as Buy's sheets have.
                    Button("Keep On") { dismiss() }
                        .buttonStyle(.sheetPrimary)
                    SheetTextButton("Turn Off", role: .destructive) {
                        onTurnOff()
                        dismiss()
                    }
                }
                .padding(.top, 4)
            }
            .padding(.horizontal, 18)
        }
        .sheetHeight($height)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        // Into the home indicator's inset, which otherwise sat as an empty
        // band under Turn Off. iOS adds that inset to the detent, so the
        // detent leaves it out; the content keeps its full height.
        .ignoresSafeArea(.container, edges: .bottom)
        .sheetGlass(detents: [.height(height - 4)])
    }
}
