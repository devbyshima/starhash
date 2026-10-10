import MapKit
import StarHashKit
import SwiftUI
import UIKit

/// What tapping a transaction shows, a page pushed on Activity's stack: the
/// system bar with its back button (no menu: every action is on the page,
/// and a long press on the code copies it), then who and how much
/// with the category, the carrier's details in a card of dotted rows, where
/// it was paid on a small map, what this year has sent the same recipient,
/// and the actions (Pay Again, Verify, Mark as Failed, Delete
/// Transaction). The
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
    @State private var isVerifying = false
    @State private var feedbackCount = 0
    @State private var failedCount = 0
    /// How far the page has scrolled under the bar, 0 to 1 over the first
    /// 24pt: the fade under the bar comes in with it.

    private var transaction: StarHashKit.Transaction? { store.transaction(id: transactionID) }

    private static let actionsID = "actions"

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                if let transaction {
                    hero(transaction)
                    detailsCard(transaction)
                    if let location = transaction.location {
                        locationSection(location, title: transaction.counterparty.shownName)
                    }
                    stats(transaction)
                    actions(transaction)
                        .id(Self.actionsID)
                }
            }
            .padding(.horizontal, StarHashMetrics.screenPadding)
            .padding(.top, 8)
            .padding(.bottom, 40)
            #if DEBUG
            .modifier(ScrolledToActions(id: Self.actionsID))
            #endif
        }
        .scrollIndicators(.hidden)
        .scrollBounceBehavior(.basedOnSize)
        .starhashSoftEdge()
        .starhashReadableScrollContent()
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Color.starhashBackground.ignoresSafeArea())
        .starhashNavigationTitle("Transaction")
        // Deleted here or elsewhere: nothing left to show.
        .onChange(of: transaction == nil) { _, isGone in
            if isGone { router.openTransactionID = nil }
        }
        .sensoryFeedback(.success, trigger: feedbackCount)
        .sensoryFeedback(.warning, trigger: failedCount)
        .deleteTransactionDialog($transactionToDelete, asAlert: true) { _ in delete() }
        .sheet(isPresented: $isVerifying) { VerifyPaymentSheet(transactionID: transactionID) }
        // Verify on a reminder opens this page with its sheet.
        .onChange(of: router.verifyTransactionID, initial: true) { _, id in
            guard id == transactionID else { return }
            router.verifyTransactionID = nil
            isVerifying = true
        }
        #if DEBUG
        // -confirmDelete (with -openFirstTransaction): the delete question;
        // -verify (with -openPendingTransaction or -openFailedTransaction):
        // Verify's sheet.
        .task {
            if DebugLaunch.arguments.contains("-verify") {
                try? await Task.sleep(for: .milliseconds(600))
                isVerifying = true
            }
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
        let tint = outgoing ? AnyShapeStyle(Color.starhashDestructiveOnPage) : AnyShapeStyle(Color.starhashIncoming)
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
        VStack(spacing: 10) {
            heroBadge(transaction)
            Text(transaction.counterparty.shownName)
                .font(.sheet(21, .bold, relativeTo: .title2))
                .foregroundStyle(Color.starhashPrimaryText)
                .multilineTextAlignment(.center)
            // One Text, so the amount and "RWF" shrink together. The unit
            // is half the number's size on its baseline, as GO Club sets
            // "ml" after an amount, and as Activity's total does.
            (Text(Money.format(transaction.amount))
                .foregroundStyle(transaction.activityAmountColor)
                .strikethrough(transaction.status == .failed)
                + Text(" " + Money.currency)
                .font(.sheet(22, .semibold, relativeTo: .title2))
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
                ForEach(TransactionCategory.choices) { option in
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
        .buttonStyle(.hapticPlain)
        .sensoryFeedback(.selection, trigger: transaction.category)
        .accessibilityLabel("Category")
        .accessibilityValue(category?.title ?? customTitle ?? "None")
    }

    // MARK: Details

    private func detailsCard(_ transaction: StarHashKit.Transaction) -> some View {
        var rows: [(String, String)] = []
        // The fee only once the carrier's SMS has confirmed it; until then
        // the row is left out rather than guessed.
        // MoMoAdvance's access fee gets a row of its own, so the wallet's
        // fee reads as its message gave it.
        if transaction.status == .confirmed, let fee = transaction.walletFee {
            rows.append(("Fee", fee == 0 ? "Free" : Money.formatWithCurrency(fee)))
            if let accessFee = transaction.accessFee {
                rows.append(("MoMoAdvance fee", Money.formatWithCurrency(accessFee)))
            }
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
            if transaction.status == .failed, let reason = failureText(transaction) {
                SheetDivider()
                SheetInfoRow("Reason", reason)
            }
        }
        .padding(.horizontal, 16)
        .sheetCard(fill: .starhashCard)
    }

    /// A dot and the word, in the status's colour, as Beam shows a state.
    private func statusValue(_ status: StarHashKit.Transaction.Status) -> some View {
        let color: AnyShapeStyle = switch status {
        case .confirmed: AnyShapeStyle(Color.starhashIncoming)
        case .pending: AnyShapeStyle(Color.starhashUrgentText)
        case .failed: AnyShapeStyle(Color.starhashDestructive)
        }
        return HStack(spacing: 6) {
            Circle().fill(color).frame(width: 7, height: 7)
            Text(statusTitle(status))
                .font(.sheet(16, .medium))
                .foregroundStyle(color)
        }
    }

    /// Why StarHash failed it, when it did rather than its owner.
    private func failureText(_ transaction: StarHashKit.Transaction) -> String? {
        switch transaction.failureReason {
        case .noMessage: "No message within an hour"
        case .message: "The wallet said it failed"
        case nil: nil
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
            SheetSectionLabel("Location", onPage: true)
            Map(initialPosition: .camera(MapCamera(centerCoordinate: coordinate, distance: 900)), interactionModes: []) {
                Marker(title, coordinate: coordinate)
                    .tint(Color.brandBlue)
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
            SheetSectionLabel("This year", onPage: true)
            HStack(alignment: .top, spacing: 16) {
                stat(value: Money.format(ytd.amount), label: String(localized: "\(Money.currency) sent"))
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
                Button(LocalizedStringKey(payTitle(transaction))) { payAgain(transaction) }
                    .buttonStyle(.sheetPrimary)
            }
            // Settled by the wallet's own message. A failed payment can
            // still be verified, in case it went through after all.
            if transaction.status != .confirmed {
                Button("Verify") { isVerifying = true }
                    .buttonStyle(.sheetConfirm)
            }
            // The quiet one: most pending payments go through.
            if transaction.status == .pending {
                SheetTextButton("Mark as Failed", onPage: true) { markFailed(transaction) }
            }
            DeleteButton("Delete Transaction") { requestDelete(transaction) }
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

    /// The payment did not go through: it stays, struck through, and
    /// counts towards nothing.
    private func markFailed(_ transaction: StarHashKit.Transaction) {
        withAnimation(.smooth(duration: 0.3)) { store.update(transaction.markedFailed()) }
        failedCount += 1
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

#if DEBUG
/// `-transactionScrolled`: the page scrolled to its foot, to see the
/// actions, as `-settingsScrolled` does for Settings.
private struct ScrolledToActions: ViewModifier {
    let id: String

    func body(content: Content) -> some View {
        ScrollViewReader { proxy in
            content.task {
                guard DebugLaunch.arguments.contains("-transactionScrolled") else { return }
                try? await Task.sleep(for: .milliseconds(800))
                proxy.scrollTo(id, anchor: .bottom)
            }
        }
    }
}
#endif
