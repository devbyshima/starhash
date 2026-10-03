import MapKit
import StarHashKit
import SwiftUI
import UIKit

/// What tapping a transaction shows, a page pushed on Activity's stack: the
/// system bar with its back button (no menu: every action is on the page,
/// and a long press on the code copies it), then who and how much
/// with the category, the carrier's details in a card of dotted rows, where
/// it was paid on a small map, what this year has sent the same recipient,
/// and the actions (Pay Again, Mark as Confirmed, Delete Transaction). The
/// pieces are Beam's sheet language, on the page's cards.
struct TransactionDetailPage: View {
    let transactionID: UUID
    /// Pay Again: the caller pops this page and takes the recipient to Pay.
    let onPayAgain: (Recipient) -> Void

    @Environment(StarHashStore.self) private var store
    @Environment(AppRouter.self) private var router

    @AppStorage(PreferenceKey.enableContacts) private var enableContacts = true
    @AppStorage(PreferenceKey.confirmDeletes) private var confirmDeletes = true
    @State private var transactionToDelete: StarHashKit.Transaction?
    @State private var feedbackCount = 0

    private var transaction: StarHashKit.Transaction? { store.transaction(id: transactionID) }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                if let transaction {
                    hero(transaction)
                    detailsCard(transaction)
                    if let location = transaction.location {
                        locationSection(location, title: transaction.counterparty.displayName)
                    }
                    stats(transaction)
                    actions(transaction)
                }
            }
            .padding(.horizontal, StarHashMetrics.screenPadding)
            .padding(.top, 8)
            .padding(.bottom, 40)
        }
        .scrollIndicators(.hidden)
        .scrollBounceBehavior(.basedOnSize)
        // Activity's fade under the bar rather than the system's blur, so
        // the page reads as part of the same tab.
        .starhashHidesTopEdgeEffect()
        .starhashReadableScrollContent()
        .starhashTopFadeUnderNavigationBar()
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Color.starhashBackground.ignoresSafeArea())
        .navigationTitle("Transaction")
        .navigationBarTitleDisplayMode(.inline)
        // Deleted here or elsewhere: nothing left to show.
        .onChange(of: transaction == nil) { _, isGone in
            if isGone { router.openTransactionID = nil }
        }
        .sensoryFeedback(.success, trigger: feedbackCount)
        .deleteTransactionDialog($transactionToDelete, asAlert: true) { _ in delete() }
        #if DEBUG
        // -confirmDelete (with -openFirstTransaction): the delete question.
        .task {
            guard DebugLaunch.arguments.contains("-confirmDelete") else { return }
            try? await Task.sleep(for: .milliseconds(600))
            transactionToDelete = transaction
        }
        #endif
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
            TransactionAvatar(counterparty: transaction.counterparty, size: 72, isCircle: true)
                .overlay(alignment: .bottomTrailing) {
                    arrow
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(tint)
                        .frame(width: 24, height: 24)
                        .background(Color.starhashBackground, in: Circle())
                        .overlay(Circle().fill(tint.opacity(0.14)))
                        .offset(x: 4, y: 4)
                        .accessibilityHidden(true)
                }
        } else {
            arrow
                .font(.system(size: 24, weight: .bold))
                .foregroundStyle(tint)
                .frame(width: 72, height: 72)
                .background(tint.opacity(0.14), in: Circle())
                .accessibilityHidden(true)
        }
    }

    private func hero(_ transaction: StarHashKit.Transaction) -> some View {
        let outgoing = transaction.direction == .outgoing
        return VStack(spacing: 10) {
            heroBadge(transaction)
            VStack(spacing: 4) {
                Text(transaction.counterparty.displayName)
                    .font(.sheet(21, .bold, relativeTo: .title2))
                    .foregroundStyle(Color.starhashPrimaryText)
                    .multilineTextAlignment(.center)
                Text(outgoing ? (transaction.counterparty.kind == .merchant ? "Paid" : "Sent") : "Received")
                    .font(.sheetCaption)
                    .foregroundStyle(Color.sheetSecondaryText)
            }
            // One Text, so the amount and "RWF" shrink together.
            (Text(Money.format(transaction.amount))
                .foregroundStyle(transaction.activityAmountColor)
                .strikethrough(transaction.status == .failed)
                + Text(" " + Money.currency)
                .foregroundStyle(Color.sheetSecondaryText))
                .font(.sheet(44, .bold, relativeTo: .largeTitle))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.4)
            categoryPill(transaction)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 8)
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
            // One glass capsule and nothing round it, as Activity's period
            // menu is: the menu opens out of the label's own shape and
            // shrinks back into it, so a larger invisible frame round a
            // smaller drawn pill made it collapse to a blob, leave a ghost
            // outline and drift as it settled.
            HStack(spacing: 6) {
                Image(systemName: category?.symbol ?? (customTitle == nil ? "plus" : "tag.fill"))
                Text(category?.title ?? customTitle ?? "Add Category")
            }
            .font(.sheetSubheadline)
            .foregroundStyle(category == nil && customTitle == nil ? Color.sheetSecondaryText : Color.starhashPrimaryText)
            .lineLimit(1)
            .padding(.horizontal, 16)
            .frame(minHeight: 40)
            .fixedSize()
            .contentShape(Capsule())
            .starhashGlass(interactive: true)
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
        ]
        if let balance = transaction.balanceAfter {
            rows.append(("Balance after", Money.formatWithCurrency(balance)))
        }
        return VStack(spacing: 0) {
            ForEach(Array(rows.enumerated()), id: \.offset) { index, row in
                if index > 0 { SheetDivider() }
                SheetInfoRow(row.0, row.1)
            }
            SheetDivider()
            SheetInfoRow(label: "Status") { statusValue(transaction.status) }
        }
        .padding(.horizontal, 16)
        .sheetCard(fill: .starhashCard)
    }

    /// A dot and the word, in the status's colour, as Beam shows a state.
    private func statusValue(_ status: StarHashKit.Transaction.Status) -> some View {
        let color: Color = switch status {
        case .confirmed: .starhashIncoming
        case .pending: .sheetSecondaryText
        case .failed: .starhashDestructive
        }
        return HStack(spacing: 6) {
            Circle().fill(color).frame(width: 7, height: 7)
            Text(statusTitle(status))
                .font(.sheet(16, .medium))
                .foregroundStyle(color)
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
    /// (no panning or zooming inside a scrolling page).
    private func locationSection(_ location: StarHashKit.Transaction.Coordinate, title: String) -> some View {
        let coordinate = CLLocationCoordinate2D(latitude: location.latitude, longitude: location.longitude)
        return VStack(spacing: 8) {
            SheetSectionLabel("Location")
            Map(initialPosition: .camera(MapCamera(centerCoordinate: coordinate, distance: 900)), interactionModes: []) {
                Marker(title, coordinate: coordinate)
                    .tint(Color.starhashInk)
            }
            .mapStyle(.standard(pointsOfInterest: .excludingAll))
            .mapControlVisibility(.hidden)
            .frame(height: 170)
            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
            .allowsHitTesting(false)
            .accessibilityElement()
            .accessibilityLabel("Map showing where this was paid")
        }
    }

    // MARK: Stats

    /// What this year has sent the same recipient, as Beam's big-number
    /// stats: an oversized number over a small uppercase label.
    private func stats(_ transaction: StarHashKit.Transaction) -> some View {
        let ytd = store.yearToDate(for: transaction.counterparty)
        return VStack(spacing: 8) {
            SheetSectionLabel("This year")
            HStack(alignment: .top, spacing: 16) {
                stat(value: Money.format(ytd.amount), label: "\(Money.currency) sent")
                stat(value: String(ytd.count), label: ytd.count == 1 ? "Payment" : "Payments")
            }
            .padding(16)
            .sheetCard(fill: .starhashCard)
        }
    }

    private func stat(value: String, label: String) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(value)
                .font(.sheet(30, .bold, relativeTo: .title))
                .foregroundStyle(Color.starhashPrimaryText)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            Text(label.uppercased())
                .font(.sheetCaption2)
                .tracking(0.6)
                .foregroundStyle(Color.sheetSecondaryText)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }

    // MARK: Actions

    private func actions(_ transaction: StarHashKit.Transaction) -> some View {
        VStack(spacing: 12) {
            // A sender read from an SMS may be masked or have no number at
            // all; there is nothing safe to dial then.
            if transaction.counterparty.isPayable {
                Button(payTitle(transaction)) { payAgain(transaction) }
                    .buttonStyle(.sheetPrimary)
            }
            if transaction.status == .pending {
                Button("Mark as Confirmed") { markConfirmed(transaction) }
                    .buttonStyle(.sheetFilled)
            }
            SheetTextButton("Delete Transaction", role: .destructive) {
                requestDelete(transaction)
            }
        }
        .padding(.top, 14)
    }

    private func payTitle(_ transaction: StarHashKit.Transaction) -> String {
        transaction.direction == .outgoing ? "Pay Again" : "Send Money"
    }

    /// The caller pops this page and takes the recipient to Pay.
    private func payAgain(_ transaction: StarHashKit.Transaction) {
        onPayAgain(transaction.counterparty)
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

    /// Asks first, unless Don't Ask Again was chosen.
    private func requestDelete(_ transaction: StarHashKit.Transaction) {
        if confirmDeletes {
            transactionToDelete = transaction
        } else {
            delete()
        }
    }

    private func delete() {
        feedbackCount += 1
        withAnimation(.smooth(duration: 0.3)) {
            store.delete(id: transactionID)
        }
    }
}
