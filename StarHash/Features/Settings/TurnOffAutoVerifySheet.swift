import SwiftUI

/// Asks before auto-verify goes off, in Beam's sheet language and sized to
/// its content: the title and the question at the left, a card of the three things
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
            SheetHeader("Auto-verify", leading: true)
                .padding(.horizontal, -2)

            VStack(spacing: 20) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Turn off auto-verify?")
                        .font(.sheetHeadline)
                        .foregroundStyle(Color.starhashPrimaryText)
                    Text("StarHash will stop reading your M\u{2011}Money messages.")
                        .font(.sheetSubheadline)
                        .foregroundStyle(Color.sheetSecondaryText)
                }
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)
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
                        .padding(.vertical, 11)
                        .accessibilityElement(children: .combine)
                    }
                }
                .padding(.horizontal, 16)
                .sheetCard()

                VStack(spacing: 4) {
                    // Neutral rather than the blue, so the safe choice
                    // does not look like the one being urged.
                    Button("Keep On") { dismiss() }
                        .buttonStyle(.sheetFilled)
                    SheetTextButton("Turn Off", role: .destructive) {
                        onTurnOff()
                        dismiss()
                    }
                }
                .padding(.top, 14)
            }
            .padding(.horizontal, 18)
            .padding(.top, 4)
            .padding(.bottom, 16)
        }
        .sheetHeight($height)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .sheetGlass(detents: [.height(height + 8)])
    }
}
