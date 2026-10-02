import SwiftUI

/// Asks before auto-verify goes off, as a compact bottom sheet sized to its
/// content: a line of context, then "This is what won't work:" and the
/// three things that stop, one short sentence each. Keep On is the
/// prominent, safe choice; Turn Off is the red one under it.
struct TurnOffAutoVerifySheet: View {
    let onTurnOff: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var height: CGFloat = 420

    private let losses: [(symbol: String, text: String)] = [
        ("clock", "Payments won't be confirmed."),
        ("arrow.down.left", "Money received won't be logged."),
        ("banknote", "Fees and balance won't fill in."),
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 10) {
                Text("Turn off auto-verify?")
                    .starhashFont(26, weight: .bold, relativeTo: .title)
                    .foregroundStyle(Color.starhashPrimaryText)
                    .accessibilityAddTraits(.isHeader)
                Text("StarHash will stop reading your M\u{2011}Money messages. This is what won't work:")
                    .font(.subheadline)
                    .foregroundStyle(Color.starhashSecondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, 8)
            .padding(.top, 24)

            StarHashCard {
                ForEach(Array(losses.enumerated()), id: \.offset) { index, loss in
                    if index > 0 { StarHashRowSeparator(leading: 60) }
                    HStack(spacing: 14) {
                        RecipientTile(tile: .symbol(loss.symbol), size: 32)
                        Text(loss.text)
                            .font(.body)
                            .foregroundStyle(Color.starhashPrimaryText)
                            .fixedSize(horizontal: false, vertical: true)
                        Spacer(minLength: 0)
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .frame(minHeight: 52)
                    .accessibilityElement(children: .combine)
                }
            }
            .padding(.top, 16)

            VStack(spacing: 10) {
                Button("Keep On") { dismiss() }
                    .buttonStyle(.starhashPrimary)
                Button("Turn Off") {
                    onTurnOff()
                    dismiss()
                }
                .buttonStyle(.starhashDestructive)
            }
            .padding(.top, 20)
        }
        .padding(.horizontal, StarHashMetrics.screenPadding)
        .padding(.bottom, StarHashMetrics.screenPadding)
        // The sheet is exactly as tall as its content: the title sits just
        // under the drag handle, and the last button as far from the
        // sheet's bottom edge as from its sides.
        .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { height = $0 }
        .ignoresSafeArea(.container, edges: .vertical)
        .presentationDetents([.height(height)])
        .presentationDragIndicator(.visible)
        .starhashSheetChrome()
    }
}
