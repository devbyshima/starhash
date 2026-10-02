import MapKit
import StarHashKit
import SwiftUI
import UIKit

/// What tapping a transaction shows, on the sheet look of Keaser's expense
/// details: who and how much at the top with its category, the carrier's
/// details in a card, where it was paid on a small map, what this year has
/// sent the same recipient, and the actions (Pay again, Mark as Confirmed,
/// Delete Transaction).
struct TransactionDetailSheet: View {
    let transactionID: UUID
    /// Pay Again: the caller hands the recipient to Pay once this sheet has
    /// gone, so Pay's own sheet never opens while this one is still closing.
    let onPayAgain: (Recipient) -> Void

    @Environment(StarHashStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    @AppStorage(PreferenceKey.enableContacts) private var enableContacts = true
    @State private var confirmingDelete = false
    @State private var feedbackCount = 0

    private var transaction: StarHashKit.Transaction? { store.transaction(id: transactionID) }

    var body: some View {
        VStack(spacing: 0) {
            StarHashSheetHeader(title: "Transaction") {
                StarHashCircleButton("xmark", label: "Close") { dismiss() }
                    .accessibilityShowsLargeContentViewer { Label("Close", systemImage: "xmark") }
            } trailing: {
                if let transaction { actionsMenu(transaction) }
            }
            .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
            .padding(.horizontal, 16)
            .padding(.top, 16)
            ScrollView {
                VStack(spacing: 16) {
                    if let transaction {
                        hero(transaction)
                            .padding(.bottom, 8)
                        detailsCard(transaction)
                        if let location = transaction.location {
                            locationCard(location, title: transaction.counterparty.displayName)
                        }
                        stats(transaction)
                        actions(transaction)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 45 - StarHashMetrics.sheetScrollEdge)
                .padding(.bottom, 24)
            }
            .starhashSheetScrollEdge()
            .scrollIndicators(.hidden)
            .scrollBounceBehavior(.basedOnSize)
            .starhashReadableScrollContent()
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.hidden)
        .starhashSheetChrome()
        // Deleted here or elsewhere: nothing left to show.
        .onChange(of: transaction == nil) { _, isGone in
            if isGone { dismiss() }
        }
        .sensoryFeedback(.success, trigger: feedbackCount)
        .confirmationDialog("Delete Transaction?", isPresented: $confirmingDelete, titleVisibility: .visible) {
            Button("Delete Transaction", role: .destructive, action: delete)
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("It is removed from StarHash only. MoMo keeps its own record.")
        }
    }

    // MARK: Header menu

    private func actionsMenu(_ transaction: StarHashKit.Transaction) -> some View {
        Menu {
            if transaction.counterparty.isPayable {
                Button {
                    payAgain(transaction)
                } label: {
                    Label(payTitle(transaction), systemImage: "arrow.uturn.forward")
                }
            }
            if transaction.status == .pending {
                Button {
                    markConfirmed(transaction)
                } label: {
                    Label("Mark as Confirmed", systemImage: "checkmark.circle")
                }
            }
            if let reference = transaction.reference {
                Button {
                    UIPasteboard.general.string = reference
                } label: {
                    Label("Copy Code", systemImage: "doc.on.doc")
                }
            }
            Button(role: .destructive) {
                confirmingDelete = true
            } label: {
                Label("Delete", systemImage: "trash")
            }
        } label: {
            StarHashCircleGlyph(symbol: "ellipsis")
        }
        .menuOrder(.fixed)
        .buttonStyle(.plain)
        .accessibilityLabel("More")
        .accessibilityShowsLargeContentViewer { Label("More", systemImage: "ellipsis") }
    }

    // MARK: Hero

    /// The contact's photo with the direction arrow on its corner when they
    /// are saved with one; otherwise the arrow alone in a tinted circle.
    @ViewBuilder
    private func heroBadge(_ transaction: StarHashKit.Transaction) -> some View {
        let outgoing = transaction.direction == .outgoing
        let tint = outgoing ? Color.starhashDestructive : Color.starhashIncoming
        let arrow = Image(systemName: outgoing ? "arrow.up.right" : "arrow.down.left")
        if enableContacts, PayContacts.shared.photoContactID(for: transaction.counterparty) != nil {
            TransactionAvatar(counterparty: transaction.counterparty, size: 64, isCircle: true)
                .overlay(alignment: .bottomTrailing) {
                    arrow
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(tint)
                        .frame(width: 24, height: 24)
                        .background(Color.starhashSheetBackground, in: Circle())
                        .overlay(Circle().fill(tint.opacity(0.14)))
                        .offset(x: 4, y: 4)
                        .accessibilityHidden(true)
                }
        } else {
            arrow
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(tint)
                .frame(width: 48, height: 48)
                .background(tint.opacity(0.14), in: Circle())
                .accessibilityHidden(true)
        }
    }

    private func hero(_ transaction: StarHashKit.Transaction) -> some View {
        let outgoing = transaction.direction == .outgoing
        return VStack(spacing: 0) {
            heroBadge(transaction)
            Text(transaction.counterparty.displayName)
                .starhashFont(20, weight: .semibold, relativeTo: .title3)
                .foregroundStyle(Color.starhashPrimaryText)
                .multilineTextAlignment(.center)
                .padding(.top, 12)
            Text(outgoing ? (transaction.counterparty.kind == .merchant ? "Paid" : "Sent") : "Received")
                .starhashFont(15, relativeTo: .subheadline)
                .foregroundStyle(Color.starhashSecondaryText)
                .padding(.top, 2)
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(Money.format(transaction.amount))
                    .starhashFont(56, weight: .bold, relativeTo: .largeTitle)
                    .foregroundStyle(transaction.activityAmountColor)
                    .strikethrough(transaction.status == .failed)
                Text(Money.currency)
                    .starhashFont(24, weight: .semibold, relativeTo: .title2)
                    .foregroundStyle(Color.starhashSecondaryText)
            }
            .lineLimit(1)
            .minimumScaleFactor(0.4)
            .padding(.top, 10)
            categoryPill(transaction)
                .padding(.top, 14)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .contain)
    }

    /// The category as a capsule that opens a menu of every category, and
    /// None to clear it.
    private func categoryPill(_ transaction: StarHashKit.Transaction) -> some View {
        let category = transaction.activityCategory
        let customTitle = category == nil ? transaction.category?.capitalized : nil
        return Menu {
            Picker("Category", selection: Binding(
                get: { transaction.category },
                set: { setCategory($0, of: transaction) }
            )) {
                Text("None").tag(String?.none)
                ForEach(TransactionCategory.allCases) { option in
                    Label(option.title, systemImage: option.symbol).tag(String?.some(option.rawValue))
                }
            }
            .pickerStyle(.inline)
        } label: {
            HStack(spacing: 6) {
                Image(systemName: category?.symbol ?? (customTitle == nil ? "plus" : "tag.fill"))
                    .font(.footnote.weight(.semibold))
                Text(category?.title ?? customTitle ?? "Add Category")
                    .starhashFont(15, weight: .medium, relativeTo: .subheadline)
            }
            .foregroundStyle(category == nil && customTitle == nil ? Color.starhashSecondaryText : Color.starhashPrimaryText)
            .padding(.horizontal, 14)
            .frame(minHeight: 34)
            .background(Color.homeSheetCard, in: Capsule())
            .frame(minHeight: 44)
            .contentShape(Capsule())
        }
        .menuOrder(.fixed)
        .buttonStyle(.plain)
        .accessibilityLabel("Category")
        .accessibilityValue(category?.title ?? customTitle ?? "None")
    }

    // MARK: Details

    private func detailsCard(_ transaction: StarHashKit.Transaction) -> some View {
        var rows: [(String, String)] = []
        // The fee only once MTN's SMS has confirmed it; until then the row
        // is left out rather than guessed.
        if transaction.status == .confirmed, let fee = transaction.fee {
            rows.append(("Fee", fee == 0 ? "Free" : Money.formatWithCurrency(fee)))
        }
        rows += [
            ("Date", transaction.date.formatted(.dateTime.weekday(.abbreviated).day().month(.abbreviated).year())),
            ("Time", transaction.date.formatted(date: .omitted, time: .shortened)),
            ("Code", transaction.reference ?? (transaction.status == .pending ? "Waiting for SMS" : "None")),
            (transaction.counterparty.kind == .phone ? "Number" : "Merchant code", transaction.counterparty.formattedDestination),
            ("Status", statusTitle(transaction.status)),
        ]
        if let balance = transaction.balanceAfter {
            rows.append(("Balance after", Money.formatWithCurrency(balance)))
        }
        return StarHashCard(fill: .homeSheetCard) {
            ForEach(Array(rows.enumerated()), id: \.offset) { index, row in
                if index > 0 { StarHashRowSeparator() }
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 12) {
                        Text(row.0).foregroundStyle(Color.starhashSecondaryText)
                        Spacer(minLength: 8)
                        Text(row.1).foregroundStyle(Color.starhashPrimaryText).multilineTextAlignment(.trailing)
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text(row.0).foregroundStyle(Color.starhashSecondaryText)
                        Text(row.1).foregroundStyle(Color.starhashPrimaryText)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .font(.body)
                .textSelection(.enabled)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .frame(minHeight: 50)
                .accessibilityElement(children: .combine)
            }
        }
    }

    private func statusTitle(_ status: StarHashKit.Transaction.Status) -> String {
        switch status {
        case .pending: "Pending"
        case .confirmed: "Confirmed"
        case .failed: "Failed"
        }
    }

    // MARK: Location

    /// Where it was paid: a still map with a marker, drawn like a snapshot
    /// (no panning or zooming inside a scrolling sheet).
    private func locationCard(_ location: StarHashKit.Transaction.Coordinate, title: String) -> some View {
        let coordinate = CLLocationCoordinate2D(latitude: location.latitude, longitude: location.longitude)
        return VStack(alignment: .leading, spacing: 8) {
            sectionTitle("Location")
            Map(initialPosition: .camera(MapCamera(centerCoordinate: coordinate, distance: 900)), interactionModes: []) {
                Marker(title, coordinate: coordinate)
                    .tint(Color.starhashInk)
            }
            .mapStyle(.standard(pointsOfInterest: .excludingAll))
            .mapControlVisibility(.hidden)
            .frame(height: 170)
            .clipShape(RoundedRectangle(cornerRadius: StarHashMetrics.cardRadius, style: .continuous))
            .allowsHitTesting(false)
            .accessibilityElement()
            .accessibilityLabel("Map showing where this was paid")
        }
    }

    // MARK: Stats

    private func stats(_ transaction: StarHashKit.Transaction) -> some View {
        let ytd = store.yearToDate(for: transaction.counterparty)
        return VStack(alignment: .leading, spacing: 8) {
            sectionTitle("Transactions sent")
            HStack(spacing: 12) {
                statTile(value: Money.format(ytd.amount), unit: Money.currency, caption: "Sent this year")
                statTile(value: String(ytd.count), unit: nil, caption: ytd.count == 1 ? "Payment this year" : "Payments this year")
            }
        }
    }

    private func statTile(value: String, unit: String?, caption: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(value)
                    .starhashFont(26, weight: .bold, relativeTo: .title)
                    .foregroundStyle(Color.starhashPrimaryText)
                if let unit {
                    Text(unit)
                        .starhashFont(14, weight: .semibold, relativeTo: .footnote)
                        .foregroundStyle(Color.starhashSecondaryText)
                }
            }
            .lineLimit(1)
            .minimumScaleFactor(0.5)
            Text(caption)
                .starhashFont(15, relativeTo: .subheadline)
                .foregroundStyle(Color.starhashSecondaryText)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.homeSheetCard, in: RoundedRectangle(cornerRadius: StarHashMetrics.cardRadius, style: .continuous))
        .accessibilityElement(children: .combine)
    }

    private func sectionTitle(_ title: String) -> some View {
        Text(title)
            .starhashFont(15, weight: .semibold, relativeTo: .subheadline)
            .foregroundStyle(Color.starhashCaptionText)
            .padding(.leading, 16)
            .accessibilityAddTraits(.isHeader)
    }

    // MARK: Actions

    @ViewBuilder
    private func actions(_ transaction: StarHashKit.Transaction) -> some View {
        // A sender read from an SMS may be masked or have no number at all;
        // there is nothing safe to dial then.
        if transaction.counterparty.isPayable {
            Button(payTitle(transaction)) { payAgain(transaction) }
                .buttonStyle(.starhashPrimary)
                .padding(.top, 8)
        }
        if transaction.status == .pending {
            StarHashActionCard("Mark as Confirmed") { markConfirmed(transaction) }
        }
        StarHashActionCard("Delete Transaction", role: .destructive) {
            confirmingDelete = true
        }
    }

    private func payTitle(_ transaction: StarHashKit.Transaction) -> String {
        transaction.direction == .outgoing ? "Pay Again" : "Send Money"
    }

    /// Closes the sheet; the caller then takes the recipient to Pay.
    private func payAgain(_ transaction: StarHashKit.Transaction) {
        onPayAgain(transaction.counterparty)
        dismiss()
    }

    private func markConfirmed(_ transaction: StarHashKit.Transaction) {
        var confirmed = transaction
        confirmed.status = .confirmed
        // Confirmed by hand, not by an SMS, so no fee is known.
        confirmed.fee = nil
        withAnimation(.smooth(duration: 0.3)) { store.update(confirmed) }
        feedbackCount += 1
    }

    private func setCategory(_ category: String?, of transaction: StarHashKit.Transaction) {
        var changed = transaction
        changed.category = category
        store.update(changed)
    }

    private func delete() {
        feedbackCount += 1
        withAnimation(.smooth(duration: 0.3)) {
            store.delete(id: transactionID)
        }
    }
}
