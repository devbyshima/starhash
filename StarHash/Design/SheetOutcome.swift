import SwiftUI

/// What a confirmation sheet becomes once it has done what it asked, after
/// the owner's reference (a sent sheet in a distortion waves library): its
/// icon on a circle of the outcome's colour at the top, a small word for
/// what happened, the figure large, who it was with, the details on a
/// card, and Done. The sheet's Distortion Wave opens from the icon
/// (`DistortionWave.playOnSheet`, `iconCentre` from the top) as it comes
/// (`reveal`). The sheet keeps the height it had, Done at its foot where
/// the buttons were, at the owner's ask: nothing moves once the wave is
/// over.
struct SheetOutcome: View {
    let symbol: String
    /// The icon's circle: `starhashConfirmed` for something confirmed.
    let tint: Color
    /// "Confirmed".
    let label: String
    /// "5,000 RWF".
    let title: String
    /// "John Doe".
    var detail: String?
    var rows: [(label: String, value: String)] = []
    let onDone: () -> Void

    /// The icon's middle, from the sheet's top edge.
    static let iconCentre: CGFloat = 60
    private static let iconSize: CGFloat = 52

    var body: some View {
        VStack(spacing: 0) {
            Image(symbol: symbol)
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(Color.waveGlyph)
                .frame(width: Self.iconSize, height: Self.iconSize)
                .background(tint, in: Circle())
                .padding(.top, Self.iconCentre - Self.iconSize / 2)
                .accessibilityHidden(true)
            Text(catalog: label)
                .font(.sheet(15, .semibold, relativeTo: .subheadline))
                .foregroundStyle(Color.sheetSecondaryText)
                .padding(.top, 12)
            Text(verbatim: title)
                .font(.starhashNumber(34, weight: .bold, relativeTo: .title))
                .foregroundStyle(Color.sheetBrandText)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .padding(.top, 2)
            if let detail {
                Text(verbatim: detail)
                    .font(.sheet(15, relativeTo: .subheadline))
                    .foregroundStyle(Color.sheetSecondaryText)
                    .lineLimit(1)
                    .padding(.top, 2)
            }
            if !rows.isEmpty {
                VStack(spacing: 0) {
                    ForEach(Array(rows.enumerated()), id: \.offset) { index, row in
                        if index > 0 { SheetDivider() }
                        SheetInfoRow(row.label, row.value)
                    }
                }
                .padding(.horizontal, 16)
                .sheetCard()
                .padding(.top, 20)
            }
            Spacer(minLength: 24)
            Button("Done", action: onDone)
                .buttonStyle(.sheetPrimary)
        }
        .padding(.horizontal, 18)
        .padding(.bottom, 28)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .accessibilityElement(children: .contain)
    }

    /// Turns a sheet into its outcome: `show` puts it in place under the
    /// sheet's wave in `tint`, felt as it starts. A fade under Reduce
    /// Motion.
    @MainActor
    static func reveal(
        tint: Color,
        dark: Bool,
        reduceMotion: Bool,
        feel: UINotificationFeedbackGenerator.FeedbackType,
        show: @escaping @MainActor () -> Void
    ) {
        guard !reduceMotion else {
            withAnimation(.smooth(duration: 0.3), show)
            UINotificationFeedbackGenerator().notificationOccurred(feel)
            return
        }
        DistortionWave.shared.playOnSheet(tint: tint, iconFromTop: iconCentre, dark: dark) {
            var transaction = SwiftUI.Transaction()
            transaction.disablesAnimations = true
            withTransaction(transaction, show)
            UINotificationFeedbackGenerator().notificationOccurred(feel)
        }
    }
}
