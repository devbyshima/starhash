import SwiftUI

/// What a confirmation sheet becomes once it has done what it asked, after
/// the owner's reference (a sent sheet in a distortion waves library): its
/// icon on a circle of the outcome's colour at the top, a small word for
/// what happened, the figure large, who it was with, the details on a
/// card, and Done. The sheet's Distortion Wave opens from the icon
/// (`DistortionWave.playOnSheet`, `iconCentre` from the top) as it comes
/// (`reveal`). The sheet keeps the height it had, Done at its foot where
/// the buttons were, at the owner's ask: nothing moves once the wave is
/// over. So the sheet opens tall enough for both (`outcomeSheet`): an
/// outcome taller than its question once overflowed the sheet, its icon
/// pushed up under the grabber.
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
        .padding(.bottom, Self.footMargin)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .accessibilityElement(children: .contain)
    }

    /// The space under a sheet's last button, the question's as Done's.
    static let footMargin: CGFloat = 28

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

extension View {
    /// The sheet a question turns into its `SheetOutcome` in, applied to
    /// the two (the question until `settled`, then the outcome). It opens
    /// as tall as the taller of the question and `outcome`, the outcome
    /// at its fullest, both measured off screen, so the outcome fits where
    /// the question was: its icon where the wave opens, Done at the foot.
    /// The question sits at the top, `SheetOutcome.footMargin` above the
    /// sheet's bottom when it fills it; one shorter than its outcome keeps
    /// its buttons at its foot with a `Spacer`, where Done comes.
    func outcomeSheet<Outcome: View>(settled: Bool, @ViewBuilder outcome: () -> Outcome) -> some View {
        modifier(OutcomeSheet(settled: settled, outcome: outcome()))
    }
}

private struct OutcomeSheet<Outcome: View>: ViewModifier {
    let settled: Bool
    let outcome: Outcome

    /// The question's height with its foot, and the outcome's.
    @State private var questionHeight: CGFloat = 0
    @State private var outcomeHeight: CGFloat = 0
    /// The home indicator's inset, which iOS adds to a height detent.
    @State private var bottomInset: CGFloat = 0
    /// The detent, kept once it settles: as the outcome comes in, the
    /// copy measured as the question is the outcome for a moment.
    @State private var height: CGFloat = 400

    func body(content: Content) -> some View {
        content
            .padding(.bottom, settled ? 0 : SheetOutcome.footMargin)
            // No height of its own to offer: iOS grows a sheet whose
            // content's ideal height comes within 8pt of it, which moved
            // a tall outcome up as it came in.
            .frame(maxWidth: .infinity, minHeight: 0, idealHeight: 0, maxHeight: .infinity, alignment: .top)
            .background {
                if !settled {
                    ZStack(alignment: .top) {
                        content
                            .padding(.bottom, SheetOutcome.footMargin)
                            .fixedSize(horizontal: false, vertical: true)
                            .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { questionHeight = $0 }
                        outcome
                            .fixedSize(horizontal: false, vertical: true)
                            .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { outcomeHeight = $0 }
                    }
                    .hidden()
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
                }
            }
            // Into the home indicator's inset: the content keeps its full
            // height, and the detent leaves the inset out.
            .ignoresSafeArea(.container, edges: .bottom)
            // Read outside, where it is still there.
            .onGeometryChange(for: CGFloat.self) { $0.safeAreaInsets.bottom } action: { bottomInset = $0 }
            .onChange(of: max(questionHeight, outcomeHeight) - bottomInset) { _, new in
                if !settled, new > 0 { height = new }
            }
            .sheetGlass(detents: [.height(height)])
    }
}
