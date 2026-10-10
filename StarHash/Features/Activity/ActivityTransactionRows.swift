import StarHashKit
import SwiftUI

/// Transactions as cards of their own, as Buy's codes are: one day of
/// Activity's list, or the search results. A card opens its details; its
/// context menu verifies it, marks it failed or deletes it (asking first),
/// and a swipe deletes
/// it outright, the whole card sliding aside and the trash beside it, as a
/// code does on Buy; deleted, it shrinks and fades as the cards under it
/// close up.
struct ActivityTransactionRows: View {
    let transactions: [StarHashKit.Transaction]
    /// Search results come from many days, so their rows show the date as
    /// well as the time.
    var showsDate = false
    let onOpen: (StarHashKit.Transaction) -> Void
    /// Verify, on a payment not yet confirmed.
    let onVerify: (StarHashKit.Transaction) -> Void
    /// Mark as Failed, on a pending payment.
    let onFail: (StarHashKit.Transaction) -> Void
    let onDelete: (StarHashKit.Transaction) -> Void
    /// The swipe's delete, which does not ask.
    let onSwipeDelete: (StarHashKit.Transaction) -> Void

    private let shape = RoundedRectangle(cornerRadius: ActivityLayout.cardRadius, style: .continuous)

    var body: some View {
        // Lazy, so a long list of results is built only as it scrolls in.
        LazyVStack(spacing: ActivityLayout.cardSpacing) {
            ForEach(transactions) { transaction in
                card(transaction)
            }
        }
    }

    private func card(_ transaction: StarHashKit.Transaction) -> some View {
        Button {
            // Here, not on touch-down: a long press opens the menu, which
            // has its own.
            TapHaptic.play()
            onOpen(transaction)
        } label: {
            ActivityTransactionRow(transaction: transaction, showsDate: showsDate)
                .contentShape(shape)
                .starhashContainer(.starhashCard, in: shape)
        }
        .buttonStyle(ActivityCardButtonStyle())
        .contentShape(.contextMenuPreview, shape)
        .contextMenu {
            // A failed payment can still be verified, in case it went
            // through after all.
            if transaction.status != .confirmed {
                Button {
                    onVerify(transaction)
                } label: {
                    Label("Verify", systemImage: "checkmark.message")
                }
            }
            if transaction.status == .pending {
                Button {
                    onFail(transaction)
                } label: {
                    Label("Mark as Failed", systemImage: "xmark.circle")
                }
            }
            Button(role: .destructive) {
                onDelete(transaction)
            } label: {
                DestructiveMenuLabel("Delete")
            }
        }
        .activitySwipeToDelete { onSwipeDelete(transaction) }
        // Buy's codes' own.
        .transition(.asymmetric(
            insertion: .scale(scale: 0.9, anchor: .top).combined(with: .opacity),
            removal: .scale(scale: 0.85).combined(with: .opacity)
        ))
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
            if transaction.isPurchase, let category = transaction.knownCategory {
                // Bought, not sent: what was bought stands for who.
                SymbolTile(symbol: category.symbol, size: 42)
                    .accessibilityHidden(true)
            } else {
                TransactionAvatar(counterparty: transaction.counterparty, size: 42)
            }
            VStack(alignment: .leading, spacing: 1) {
                HStack(spacing: 6) {
                    Text(transaction.counterparty.shownName)
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
        if transaction.isPurchase {
            parts.append(String(localized: "Bought"))
        } else if transaction.counterparty.name?.isEmpty == false, !transaction.counterparty.destination.isEmpty {
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

/// A card gives a little as it is pressed, as Buy's codes do. Silent: the
/// tap plays its haptic as it lands, since a long press opens the menu.
struct ActivityCardButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
            .opacity(configuration.isPressed ? 0.88 : 1)
            .animation(.snappy(duration: 0.18), value: configuration.isPressed)
    }
}
