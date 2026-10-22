import StarHashKit
import SwiftUI

/// Transactions as rows straight on the page, after the owner's reference:
/// one month of Activity's list, or the search results. A row opens its
/// details; its context menu verifies it, marks it failed or deletes it
/// (asking first), and a swipe deletes it outright, the row sliding aside
/// and the trash beside it; deleted, it shrinks and fades as the rows under
/// it close up.
struct ActivityTransactionRows: View {
    let transactions: [StarHashKit.Transaction]
    let onOpen: (StarHashKit.Transaction) -> Void
    /// Verify, on a payment not yet confirmed.
    let onVerify: (StarHashKit.Transaction) -> Void
    /// Mark as Failed, on a pending payment.
    let onFail: (StarHashKit.Transaction) -> Void
    let onDelete: (StarHashKit.Transaction) -> Void
    /// The swipe's delete, which does not ask.
    let onSwipeDelete: (StarHashKit.Transaction) -> Void

    private let shape = RoundedRectangle(cornerRadius: ActivityLayout.rowRadius, style: .continuous)

    var body: some View {
        // Lazy, so a long list of results is built only as it scrolls in.
        LazyVStack(spacing: 0) {
            ForEach(transactions) { transaction in
                row(transaction)
            }
        }
    }

    private func row(_ transaction: StarHashKit.Transaction) -> some View {
        Button {
            // Here, not on touch-down: a long press opens the menu, which
            // has its own.
            TapHaptic.play()
            onOpen(transaction)
        } label: {
            ActivityTransactionRow(transaction: transaction)
                .contentShape(shape)
        }
        .buttonStyle(ActivityRowButtonStyle())
        .contentShape(.contextMenuPreview, shape)
        .contextMenu {
            // A failed payment can still be verified, in case it went
            // through after all.
            if transaction.status != .confirmed {
                Button {
                    onVerify(transaction)
                } label: {
                    Label("Verify", symbol: "checkmark.message")
                }
            }
            if transaction.status == .pending {
                Button {
                    onFail(transaction)
                } label: {
                    Label("Mark as Failed", symbol: "xmark.circle")
                }
            }
            Button(role: .destructive) {
                onDelete(transaction)
            } label: {
                DestructiveMenuLabel("Delete")
            }
        }
        .activitySwipeToDelete { onSwipeDelete(transaction) }
        .transition(.asymmetric(
            insertion: .scale(scale: 0.9, anchor: .top).combined(with: .opacity),
            removal: .scale(scale: 0.85).combined(with: .opacity)
        ))
    }
}

/// One transaction, after the owner's reference, with everything the
/// cards before it said: the tile, the name with its Pending or Failed
/// badge, under it what was bought or the number or code with the date and
/// time, and the amount on the right after its direction's arrow. At
/// accessibility text sizes the amount moves under the details so the name
/// keeps the width it needs.
struct ActivityTransactionRow: View {
    let transaction: StarHashKit.Transaction

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        let isLarge = dynamicTypeSize.isAccessibilitySize
        HStack(alignment: .top, spacing: ActivityLayout.tileGap) {
            TransactionTile(transaction: transaction, size: ActivityLayout.tileSize)
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(transaction.counterparty.shownName)
                        .starhashFont(17, relativeTo: .body)
                        .foregroundStyle(Color.starhashPrimaryText)
                        .lineLimit(isLarge ? 3 : 1)
                    ActivityStatusBadge(status: transaction.status)
                }
                Text(detailLine)
                    .starhashFont(14, relativeTo: .subheadline)
                    .foregroundStyle(Color.starhashSecondaryText)
                    .lineLimit(isLarge ? 2 : 1)
                    // Shrinks a little before the time is cut off beside a
                    // wide amount.
                    .minimumScaleFactor(0.8)
                if isLarge {
                    amount
                        .padding(.top, 4)
                }
            }
            .padding(.top, 1)
            if isLarge {
                Spacer(minLength: 0)
            } else {
                Spacer(minLength: 12)
                amount
                    .layoutPriority(1)
            }
        }
        .padding(.vertical, ActivityLayout.rowPadding)
        // A line under the row from where its words start to where the
        // amount ends.
        .overlay(alignment: .bottom) {
            SheetDivider()
                .padding(.leading, ActivityLayout.tileSize + ActivityLayout.tileGap)
        }
        .contentShape(Rectangle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(transaction.activityAccessibilityLabel)
        .accessibilityAddTraits(.isButton)
    }

    /// "0788 123 998 \u{00B7} 22 Oct, 13:12". A named merchant shows its code;
    /// an unnamed recipient already shows its number as the name, so only
    /// the date and time.
    private var detailLine: String {
        var parts: [String] = []
        if transaction.isPurchase {
            parts.append(String(localized: "Bought"))
        } else if transaction.isOwnTransfer {
            parts.append(String(localized: "Between your accounts"))
        } else if transaction.counterparty.name?.isEmpty == false, !transaction.counterparty.destination.isEmpty {
            parts.append(transaction.counterparty.formattedDestination)
        }
        parts.append(ActivitySummary.rowDate(for: transaction.date, now: .now, calendar: .autoupdatingCurrent)
            + ", " + transaction.date.formatted(date: .omitted, time: .shortened))
        return parts.joined(separator: " \u{00B7} ")
    }

    /// The direction arrow (the text colour out, green in, as on the
    /// details page), then the amount, struck through when it failed.
    private var amount: some View {
        HStack(alignment: .firstTextBaseline, spacing: 4) {
            Image(symbol: transaction.activityArrowSymbol)
                .starhashFont(13, weight: .bold, relativeTo: .footnote)
                .foregroundStyle(transaction.activityArrowColor)
            Text(Money.format(transaction.amount))
                .font(.starhashNumber(17, relativeTo: .body))
                .foregroundStyle(transaction.activityAmountColor)
                .strikethrough(transaction.status == .failed)
        }
        .lineLimit(1)
        .padding(.top, 1)
    }
}

/// A row dims a little as it is pressed. Silent: the tap plays its haptic
/// as it lands, since a long press opens the menu.
struct ActivityRowButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .opacity(configuration.isPressed ? 0.6 : 1)
            .animation(.snappy(duration: 0.18), value: configuration.isPressed)
    }
}
