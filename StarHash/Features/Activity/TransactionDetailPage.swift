import MapKit
import StarHashKit
import SwiftUI
import UIKit

/// What tapping a transaction shows, a page pushed on Activity's stack,
/// after the owner's reference: the round back button, then who, when and
/// how much down the middle with the category under it, the details in
/// outlined cards grouped by what they say (how it went and how it was
/// paid; who to; the amount, its fee and the balance after), where it was
/// paid on a small map, what this year has sent the same recipient, and
/// the actions (Pay Again, Verify, Mark as Failed, Delete Transaction) as
/// one filled list.
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
            VStack(spacing: 16) {
                if let transaction {
                    hero(transaction)
                        .padding(.bottom, 16)
                    detailCards(transaction)
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
        .navigationTitle("Transaction")
        .navigationBarTitleDisplayMode(.inline)
        // The reference's page has no title in its bar: the hero says it.
        .toolbar {
            ToolbarItem(placement: .principal) { Color.clear.frame(width: 1, height: 1) }
        }
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

    /// The tile, the name in bold, the date and time in grey, then the
    /// amount large, struck through when it failed, with RWF after it at
    /// half its size on its baseline.
    private func hero(_ transaction: StarHashKit.Transaction) -> some View {
        VStack(spacing: 0) {
            TransactionTile(transaction: transaction, size: 64)
                .padding(.bottom, 18)
            Text(transaction.counterparty.shownName)
                .starhashFont(28, weight: .bold, relativeTo: .title)
                .foregroundStyle(Color.starhashPrimaryText)
                .multilineTextAlignment(.center)
                .padding(.bottom, 6)
            Text(transaction.date.formatted(.dateTime.month(.abbreviated).day().hour().minute().locale(.starhash)))
                .starhashFont(17, relativeTo: .body)
                .foregroundStyle(Color.starhashSecondaryText)
                .padding(.bottom, 14)
            // One Text, so the amount and "RWF" shrink together.
            (Text((transaction.direction == .incoming ? "+" : "") + Money.format(transaction.amount))
                .foregroundStyle(transaction.activityAmountColor)
                .strikethrough(transaction.status == .failed)
                + Text(" " + Money.currency)
                .font(.starhashNumber(20, relativeTo: .title3))
                .foregroundStyle(Color.starhashSecondaryText))
                .font(.starhashNumber(40, weight: .bold, relativeTo: .largeTitle))
                .lineLimit(1)
                .minimumScaleFactor(0.4)
                .padding(.bottom, 16)
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
                    Label(option.title, symbol: option.symbol).tag(String?.some(option.rawValue))
                }
            }
            .pickerStyle(.inline)
        } label: {
            // One glass capsule and nothing round it, as Activity's period
            // menu is: the menu opens out of the label's own shape and
            // shrinks back into it, so a larger invisible frame round a
            // smaller drawn pill made it collapse to a blob, leave a ghost
            // outline and drift as it settled.
            Text(category?.title ?? customTitle ?? "Add Category")
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

    /// The reference's three cards, with StarHash's details in them: how it
    /// went and the wallet it went through; who it went to and the
    /// carrier's code for it; and the money, the amount with its fee and
    /// the balance it left. A row with nothing to say is left out.
    private func detailCards(_ transaction: StarHashKit.Transaction) -> some View {
        VStack(spacing: 16) {
            VStack(spacing: 0) {
                DetailRow(label: "Status") { statusValue(transaction.status) }
                if transaction.status == .failed, let reason = failureText(transaction) {
                    DetailRow("Reason", reason)
                }
                if let wallet = transaction.wallet {
                    DetailRow("Payment", wallet.walletName)
                }
            }
            .starhashOutlinedCard()

            VStack(spacing: 0) {
                DetailRow(
                    transaction.counterparty.kind == .phone ? "Number" : "Merchant code",
                    transaction.counterparty.formattedDestination,
                    numeric: true
                )
                DetailRow(
                    "Code",
                    transaction.reference ?? (transaction.status == .pending ? "Waiting for SMS" : "None"),
                    numeric: transaction.reference != nil
                )
            }
            .starhashOutlinedCard()

            VStack(spacing: 0) {
                DetailRow("Amount", Money.formatWithCurrency(transaction.amount), numeric: true)
                // The fee only once the carrier's SMS has confirmed it;
                // until then the row is left out rather than guessed.
                // MoMoAdvance's access fee gets a row of its own, so the
                // wallet's fee reads as its message gave it.
                if transaction.status == .confirmed, let fee = transaction.walletFee {
                    DetailRow("Fee", fee == 0 ? "Free" : Money.formatWithCurrency(fee), numeric: fee != 0)
                    if let accessFee = transaction.accessFee {
                        DetailRow("MoMoAdvance fee", Money.formatWithCurrency(accessFee), numeric: true)
                    }
                    DetailRow("Total", Money.formatWithCurrency(transaction.amount + (transaction.fee ?? 0)), numeric: true)
                }
                if let balance = transaction.balanceAfter {
                    DetailRow("Balance after", Money.formatWithCurrency(balance), numeric: true)
                }
            }
            .starhashOutlinedCard()
        }
    }

    /// A dot and the word, in the status's colour.
    private func statusValue(_ status: StarHashKit.Transaction.Status) -> some View {
        let color: AnyShapeStyle = switch status {
        case .confirmed: AnyShapeStyle(Color.starhashIncoming)
        case .pending: AnyShapeStyle(Color.starhashUrgentText)
        case .failed: AnyShapeStyle(Color.starhashDestructive)
        }
        return HStack(spacing: 6) {
            Circle().fill(color).frame(width: 7, height: 7)
            Text(statusTitle(status))
                .starhashFont(17, relativeTo: .body)
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
                    .tint(Color.brandAccent)
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
                stat(value: Money.format(ytd.amount), label: String(starhash: "\(Money.currency) sent"))
                stat(value: String(ytd.count), label: ytd.count == 1 ? "Payment" : "Payments")
            }
            .starhashOutlinedCard(padding: EdgeInsets(top: 16, leading: 16, bottom: 16, trailing: 16))
        }
    }

    private func stat(value: String, label: String) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(value)
                .font(.starhashNumber(30, weight: .bold, relativeTo: .title))
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

    /// Every action in one filled list, after the reference's: Pay Again
    /// (Send Money for money received), Verify while it is not confirmed,
    /// Mark as Failed while pending, and Delete Transaction in red.
    private func actions(_ transaction: StarHashKit.Transaction) -> some View {
        ActionList {
            // A sender read from an SMS may be masked or have no number at
            // all; there is nothing safe to dial then.
            if transaction.counterparty.isPayable {
                ActionRow(payTitle(transaction), symbol: "arrow.uturn.backward.circle") { payAgain(transaction) }
            }
            // Settled by the wallet's own message. A failed payment can
            // still be verified, in case it went through after all.
            if transaction.status != .confirmed {
                ActionRow("Verify", symbol: "checkmark.message") { isVerifying = true }
            }
            if transaction.status == .pending {
                ActionRow("Mark as Failed", symbol: "xmark.circle") { markFailed(transaction) }
            }
            ActionRow("Delete Transaction", symbol: "trash", isDestructive: true) { requestDelete(transaction) }
        }
        .padding(.top, 8)
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
