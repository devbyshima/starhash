import StarHashKit
import SwiftUI

/// Transactions as rows straight on the page, after the owner's reference:
/// one month of Activity's list, or the search results. A row opens its
/// details. A long press lifts it as the system's context menu does,
/// after the owner's references: a confirmed transaction lifts the top of
/// its page and nothing more; one not yet confirmed lifts the row itself
/// with its menu under it (verify it, mark it failed, pay again, or delete
/// it, asking first). A swipe deletes it outright, the row sliding aside
/// and the trash beside it; deleted, it shrinks and fades as the rows under
/// it close up.
///
/// The rows reach past the page's padding to the screen's edges, so a
/// press fills the width as a list's highlight does; the caller pads them
/// by `StarHashMetrics.screenPadding`.
struct ActivityTransactionRows: View {
    let transactions: [StarHashKit.Transaction]
    let onOpen: (StarHashKit.Transaction) -> Void
    /// Verify, on a payment not yet confirmed.
    let onVerify: (StarHashKit.Transaction) -> Void
    /// Mark as Failed, on a pending payment.
    let onFail: (StarHashKit.Transaction) -> Void
    /// Pay Again, or Send Money for money received.
    let onPayAgain: (Recipient) -> Void
    let onDelete: (StarHashKit.Transaction) -> Void
    /// The swipe's delete, which does not ask.
    let onSwipeDelete: (StarHashKit.Transaction) -> Void
    /// The date on each row; under a day's heading, the time is enough.
    var showsDate = true

    /// The list's width inside the page's padding: the lifted card's.
    @State private var width: CGFloat = 0

    var body: some View {
        // Lazy, so a long list of results is built only as it scrolls in.
        LazyVStack(spacing: 0) {
            ForEach(transactions) { transaction in
                row(transaction)
            }
        }
        .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { width = $0 }
    }

    private func row(_ transaction: StarHashKit.Transaction) -> some View {
        Button {
            // Here, not on touch-down: a long press opens the menu, which
            // has its own.
            TapHaptic.play()
            onOpen(transaction)
        } label: {
            ActivityTransactionRow(transaction: transaction, showsDate: showsDate)
                .padding(.horizontal, StarHashMetrics.screenPadding)
                .contentShape(Rectangle())
        }
        .buttonStyle(ActivityRowButtonStyle())
        .contentShape(.contextMenuPreview, Rectangle())
        // Empty for a confirmed row, which opens no menu here: its preview
        // is lifted by the one below.
        .contextMenu {
            if transaction.status != .confirmed {
                menu(transaction)
            }
        } preview: {
            TransactionRowPreview(transaction: transaction, width: width, showsDate: showsDate)
        }
        .previewContextMenu(
            isEnabled: transaction.status == .confirmed,
            size: CGSize(width: width, height: ActivityLayout.previewHeight),
            highlight: .starhashRowHighlight,
            onOpen: { onOpen(transaction) }
        ) {
            TransactionPreview(transaction: transaction, width: width)
        }
        .activitySwipeToDelete { onSwipeDelete(transaction) }
        .padding(.horizontal, -StarHashMetrics.screenPadding)
        .transition(.asymmetric(
            insertion: .scale(scale: 0.9, anchor: .top).combined(with: .opacity),
            removal: .scale(scale: 0.85).combined(with: .opacity)
        ))
    }

    /// The pending row's menu, in groups as Contacts' is: settling it (a
    /// failed payment can still be verified, in case it went through after
    /// all), paying again, and deleting it.
    @ViewBuilder
    private func menu(_ transaction: StarHashKit.Transaction) -> some View {
        Section {
            Button("Verify", symbol: "checkmark.message") { onVerify(transaction) }
            if transaction.status == .pending {
                Button("Mark as Failed", symbol: "xmark.circle") { onFail(transaction) }
            }
        }
        // A sender read from an SMS may be masked or have no number at
        // all; there is nothing safe to dial then.
        if transaction.counterparty.isPayable {
            Section {
                if transaction.direction == .outgoing {
                    Button("Pay Again", symbol: "arrow.uturn.backward.circle") { onPayAgain(transaction.counterparty) }
                } else {
                    Button("Send Money", symbol: "arrow.uturn.backward.circle") { onPayAgain(transaction.counterparty) }
                }
            }
        }
        Section {
            Button(role: .destructive) {
                onDelete(transaction)
            } label: {
                DestructiveMenuLabel("Delete")
            }
        }
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
    var showsDate = true
    /// The line under it; not on the card a long press lifts.
    var showsDivider = true

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        let isLarge = dynamicTypeSize.isAccessibilitySize
        // The amount halfway down the row, beside both lines; at the
        // largest sizes it goes under them and the row keeps to the top.
        HStack(alignment: isLarge ? .top : .center, spacing: ActivityLayout.tileGap) {
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
            if showsDivider {
                SheetDivider()
                    .padding(.leading, ActivityLayout.tileSize + ActivityLayout.tileGap)
            }
        }
        .contentShape(Rectangle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(transaction.activityAccessibilityLabel)
        .accessibilityAddTraits(.isButton)
    }

    /// "0788 123 998 \u{00B7} 22 Oct, 13:12". A named merchant shows its code;
    /// an unnamed recipient already shows its number as the name, so only
    /// the date and time; under a day's heading, the time alone.
    private var detailLine: String {
        var parts: [String] = []
        if transaction.isPurchase {
            parts.append(String(starhash: "Bought"))
        } else if transaction.isOwnTransfer {
            parts.append(String(starhash: "Between your accounts"))
        } else if transaction.counterparty.name?.isEmpty == false, !transaction.counterparty.destination.isEmpty {
            parts.append(transaction.counterparty.formattedDestination)
        }
        let time = transaction.date.formatted(Date.FormatStyle(date: .omitted, time: .shortened, locale: .starhash))
        if showsDate {
            parts.append(ActivitySummary.rowDate(for: transaction.date, now: .now, calendar: .autoupdatingCurrent, locale: .starhash) + ", " + time)
        } else {
            parts.append(time)
        }
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

/// A row turns grey edge to edge as it is pressed, at once, and fades
/// back as it is let go or lifts, as a system list's cell highlights.
/// Silent: the tap plays its haptic as it lands, since a long press opens
/// the menu.
struct ActivityRowButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(Color.starhashRowHighlight.opacity(configuration.isPressed ? 1 : 0))
            .animation(configuration.isPressed ? nil : .easeOut(duration: 0.25), value: configuration.isPressed)
    }
}
