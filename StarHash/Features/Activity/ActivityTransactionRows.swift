import StarHashKit
import SwiftUI

/// Transactions as the rows of one card, with a hairline under each name
/// between them: one day of Activity's list, or the search results. A row
/// opens its details; its context menu confirms or deletes it (asking
/// first), and a swipe deletes it outright, as Beam's clipboard rows do.
///
/// The card is one container (`starhashContainer`), white glass in light
/// mode and black glass in dark, as every other card is; its rows sit in a
/// lazy stack, so a long list of results is still built only as it
/// scrolls in.
struct ActivityTransactionRows: View {
    let transactions: [StarHashKit.Transaction]
    /// Search results come from many days, so their rows show the date as
    /// well as the time.
    var showsDate = false
    let onOpen: (StarHashKit.Transaction) -> Void
    let onConfirm: (StarHashKit.Transaction) -> Void
    let onDelete: (StarHashKit.Transaction) -> Void
    /// The swipe's delete, which does not ask.
    let onSwipeDelete: (StarHashKit.Transaction) -> Void
    /// Rows being deleted, which fold away before they go (`ActivityView`).
    var leaving: Set<UUID> = []

    /// The card's width, for a row lifted into its menu.
    @State private var width: CGFloat = 0

    /// The card's own space, where a swiped row's offset shows.
    static let space = "activityCard"

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: StarHashMetrics.cardRadius, style: .continuous)
        LazyVStack(spacing: 0) {
            rows
        }
        .coordinateSpace(.named(Self.space))
        .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { width = $0 }
        // A pressed row's tint follows the card's corners.
        .clipShape(shape)
        .starhashContainer(.starhashCard, in: shape)
    }

    private var rows: some View {
        ForEach(Array(transactions.enumerated()), id: \.element.id) { index, transaction in
            Button {
                // Here, not on touch-down: a long press opens the menu,
                // which has its own.
                TapHaptic.play()
                onOpen(transaction)
            } label: {
                ActivityTransactionRow(transaction: transaction, showsDate: showsDate)
                    .modifier(RowSlab(isLeaving: leaving.contains(transaction.id)))
            }
            .buttonStyle(ActivityRowButtonStyle())
            .contextMenu {
                if transaction.status == .pending {
                    Button {
                        onConfirm(transaction)
                    } label: {
                        Label("Mark as Confirmed", systemImage: "checkmark.circle")
                    }
                }
                Button(role: .destructive) {
                    onDelete(transaction)
                } label: {
                    DestructiveMenuLabel("Delete")
                }
            } preview: {
                // The card is drawn behind all its rows, not each one, so
                // the lifted row brings the card's colour of its own.
                ActivityTransactionRow(transaction: transaction, showsDate: showsDate)
                    .frame(width: width > 0 ? width : nil)
                    .background(Color.starhashCard)
            }
            // Outside the button, so a lifted row does not carry it. Only
            // under a row that stays: the first row folding away takes the
            // line with it.
            .overlay(alignment: .top) {
                if transactions[..<index].contains(where: { !leaving.contains($0.id) }) {
                    StarHashRowSeparator(leading: ActivityLayout.rowSeparatorLeading)
                }
            }
            .activitySwipeToDelete { onSwipeDelete(transaction) }
            .modifier(FoldAway(isFolded: leaving.contains(transaction.id)))
            .transition(.opacity)
        }
    }
}

/// A row being deleted folds away: its height closes to nothing as the rows
/// under it rise into the space, so nothing of it is left to show through
/// them, as it would if it faded where it stood. Its height is measured
/// as it is, so the fold starts from it.
private struct FoldAway: ViewModifier {
    let isFolded: Bool

    @State private var height: CGFloat = 0

    func body(content: Content) -> some View {
        content
            .fixedSize(horizontal: false, vertical: true)
            .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { height = $0 }
            .frame(height: isFolded ? 0 : (height > 0 ? height : nil), alignment: .top)
            .clipped()
            .opacity(isFolded ? 0 : 1)
    }
}

/// The card is drawn once behind all its rows, so a row has no background of
/// its own; while it is swiped aside or leaving, it takes the card's colour
/// (white, or black glass's near black), and slides as a whole row would
/// rather than as loose text.
private struct RowSlab: ViewModifier {
    let isLeaving: Bool

    @State private var isAside = false

    func body(content: Content) -> some View {
        content
            .background(Color.starhashCard.opacity(isAside || isLeaving ? 1 : 0))
            .onGeometryChange(for: Bool.self) { proxy in
                abs(proxy.frame(in: .named(ActivityTransactionRows.space)).minX) > 0.5
            } action: { isAside = $0 }
    }
}

/// One transaction: their contact photo or a person or shop tile, name,
/// number or code with the
/// time, and the signed amount. At accessibility text sizes the amount
/// moves under the details so the name keeps the width it needs.
struct ActivityTransactionRow: View {
    let transaction: StarHashKit.Transaction
    var showsDate = false

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        let isLarge = dynamicTypeSize.isAccessibilitySize
        HStack(spacing: 16) {
            TransactionAvatar(counterparty: transaction.counterparty, size: 42)
            VStack(alignment: .leading, spacing: 1) {
                HStack(spacing: 6) {
                    Text(transaction.counterparty.displayName)
                        .starhashFont(17, weight: .semibold, relativeTo: .headline)
                        .foregroundStyle(Color.starhashPrimaryText)
                        .lineLimit(isLarge ? 3 : 1)
                    ActivityStatusBadge(status: transaction.status)
                }
                Text(detailLine)
                    .starhashFont(15, relativeTo: .subheadline)
                    .foregroundStyle(Color.starhashSecondaryText)
                    .lineLimit(isLarge ? 2 : 1)
                    // Shrinks a little before the time is cut off beside a
                    // wide amount.
                    .minimumScaleFactor(0.85)
                if isLarge {
                    amount
                        .padding(.top, 4)
                }
            }
            if isLarge {
                Spacer(minLength: 0)
            } else {
                Spacer(minLength: 8)
                amount
                    .layoutPriority(1)
            }
        }
        .padding(16)
        .contentShape(Rectangle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(transaction.activityAccessibilityLabel)
        .accessibilityAddTraits(.isButton)
    }

    /// "0788 123 998 · 13:12". A named merchant shows its code; an unnamed
    /// recipient already shows its number as the name, so only the time.
    private var detailLine: String {
        var parts: [String] = []
        if transaction.counterparty.name?.isEmpty == false {
            parts.append(transaction.counterparty.formattedDestination)
        }
        parts.append(showsDate
            ? transaction.date.formatted(.dateTime.day().month(.abbreviated).hour().minute())
            : transaction.date.formatted(date: .omitted, time: .shortened))
        return parts.joined(separator: " \u{00B7} ")
    }

    /// The direction arrow (red out, green in, as on the details page),
    /// then the amount.
    private var amount: some View {
        HStack(alignment: .firstTextBaseline, spacing: 4) {
            Image(systemName: transaction.activityArrowSymbol)
                .starhashFont(13, weight: .bold, relativeTo: .footnote)
                .foregroundStyle(transaction.activityArrowColor)
            Text(Money.format(transaction.amount))
                .starhashFont(17, weight: .semibold, relativeTo: .headline)
                .foregroundStyle(transaction.activityAmountColor)
                .strikethrough(transaction.status == .failed)
        }
        .lineLimit(1)
    }
}

/// A row tints while pressed, like a list cell; the card clips the tint to
/// its corners.
struct ActivityRowButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(Color.starhashPrimaryText.opacity(configuration.isPressed ? 0.06 : 0))
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}
