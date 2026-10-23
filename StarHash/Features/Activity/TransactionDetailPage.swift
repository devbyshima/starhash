import MapKit
import StarHashKit
import SwiftUI
import UIKit

/// What tapping a transaction shows, a page pushed on Activity's stack,
/// after the owner's reference: the round back button, then who, when and
/// how much down the middle, the details in outlined cards grouped by what
/// they say (how it went, its category and how it was paid; who to; the
/// amount, its fee and the balance after), where it was
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
                    TransactionHero(transaction: transaction)
                        .padding(.bottom, 16)
                    TransactionDetailCards(transaction: transaction) {
                        categoryRow(transaction)
                    }
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

    /// The category, a row under Status that opens a menu of every
    /// category, and None to clear it; its value ends in the up-and-down
    /// chevron, as Settings' choices do.
    private func categoryRow(_ transaction: StarHashKit.Transaction) -> some View {
        Menu {
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
            // Laid out as a DetailRow, but not one: its combined
            // accessibility element kept the menu from opening on a tap.
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                Text("Category")
                    .starhashFont(17, relativeTo: .body)
                    .foregroundStyle(Color.starhashPrimaryText)
                    .lineLimit(1)
                Spacer(minLength: 8)
                Text(catalog: transaction.activityCategoryTitle)
                    .starhashFont(17, relativeTo: .body)
                    .foregroundStyle(Color.starhashSecondaryText)
                    .lineLimit(1)
                Image(symbol: "chevron.up.chevron.down")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color.starhashTertiaryText)
            }
            .padding(.vertical, 11)
            .contentShape(Rectangle())
        }
        .menuOrder(.fixed)
        .buttonStyle(.hapticPlain)
        .sensoryFeedback(.selection, trigger: transaction.category)
        .accessibilityLabel("Category")
        .accessibilityValue(transaction.activityCategoryTitle)
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
