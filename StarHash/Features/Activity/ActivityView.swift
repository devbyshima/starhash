import StarHashKit
import SwiftUI
import UIKit

/// The Activity tab, modelled on Keaser's Home: the period picker and
/// search, the spending summary with its chart, and the period's
/// transactions grouped by day. Search replaces all of it with its own
/// full-screen view while it is open, and the tab bar hides meanwhile.
///
/// A transaction's details open through `AppRouter.openTransactionID`, so a
/// route from a URL or an intent opens the same sheet a tap does.
struct ActivityView: View {
    @Environment(StarHashStore.self) private var store
    @Environment(AppRouter.self) private var router
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// The moment the totals and chart are worked out for. Refreshed on
    /// clock, day or time zone changes and on returning to the app, so
    /// "Today" and "This Week" roll over by themselves.
    @AppStorage(PreferenceKey.enableContacts) private var enableContacts = true
    @State private var now = Date.now
    @State private var period: ActivityPeriod = .week

    @State private var isSearching = false
    @State private var searchText = ""
    @FocusState private var searchFocused: Bool

    @State private var transactionToDelete: StarHashKit.Transaction?
    @State private var feedbackCount = 0
    /// Chosen with Pay Again on the details sheet, handed to Pay once the
    /// sheet has closed.
    @State private var payAgainRecipient: Recipient?
    #if DEBUG
    @State private var didApplyDebugLaunch = false
    #endif

    /// The user's calendar, so weeks start on their region's first weekday.
    private var calendar: Calendar { .autoupdatingCurrent }

    var body: some View {
        ZStack {
            Color.starhashBackground.ignoresSafeArea()
            if isSearching {
                searchScreen
                    .transition(.opacity)
            } else {
                mainScreen
                    .transition(.opacity)
            }
        }
        // Contact photos for the rows, read once access is already granted.
        .task(id: enableContacts) {
            if enableContacts { await PayContacts.shared.loadIfAllowed() }
        }
        .sheet(item: openTransaction, onDismiss: handOffPayAgain) { item in
            TransactionDetailSheet(transactionID: item.id) { payAgainRecipient = $0 }
        }
        .confirmationDialog(
            "Delete Transaction?",
            isPresented: Binding(get: { transactionToDelete != nil }, set: { if !$0 { transactionToDelete = nil } }),
            titleVisibility: .visible,
            presenting: transactionToDelete
        ) { transaction in
            Button("Delete Transaction", role: .destructive) { delete(transaction) }
            Button("Cancel", role: .cancel) {}
        } message: { transaction in
            Text("\(Money.formatWithCurrency(transaction.amount)) with \(transaction.counterparty.displayName) is removed from StarHash. MoMo keeps its own record.")
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.significantTimeChangeNotification)) { _ in
            now = .now
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { now = .now }
        }
        .sensoryFeedback(.success, trigger: feedbackCount)
        #if DEBUG
        .onAppear(perform: applyDebugLaunch)
        #endif
    }

    // MARK: Screens

    @ViewBuilder
    private var mainScreen: some View {
        if store.transactions.isEmpty {
            emptyScreen
        } else {
            listScreen
        }
    }

    /// Nothing logged yet: the message centred in the space between the
    /// top bar and the bottom of the screen.
    private var emptyScreen: some View {
        EmptyStateView(
            symbol: "list.bullet.rectangle",
            title: "No Transactions",
            message: "Pay someone from Pay, or set up Auto-verify in Settings to log MoMo messages.",
            style: .large
        )
        .padding(.horizontal, StarHashMetrics.screenPadding)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .ignoresSafeArea(.container, edges: .bottom)
        .safeAreaInset(edge: .top, spacing: 0) {
            ActivityTopBar(period: period, onPeriod: choosePeriod, onSearch: beginSearch)
        }
    }

    private var listScreen: some View {
        let all = store.transactions
        let inPeriod = ActivitySummary.transactions(all, in: period, now: now, calendar: calendar)
        let sections = ActivitySummary.groupedByDay(inPeriod, calendar: calendar)

        return ScrollView {
            LazyVStack(alignment: .leading, spacing: 0) {
                Group {
                    ActivitySummaryCard(
                        period: period,
                        totals: ActivitySummary.totals(of: inPeriod),
                        buckets: ActivitySummary.buckets(for: inPeriod, period: period, now: now, calendar: calendar),
                        calendar: calendar
                    )
                    if sections.isEmpty {
                        Text("No transactions \(period.emptyPhrase).")
                            .font(.subheadline)
                            .foregroundStyle(Color.starhashSecondaryText)
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 32)
                    }
                    ForEach(sections) { section in
                        dayHeader(section)
                        ActivityTransactionRows(
                            transactions: section.transactions,
                            onOpen: open,
                            onConfirm: markConfirmed,
                            onDelete: { transactionToDelete = $0 }
                        )
                    }
                }
            }
            .padding(.horizontal, StarHashMetrics.screenPadding)
            .padding(.top, ActivityLayout.contentTop)
            .padding(.bottom, StarHashMetrics.screenPadding)
            .animation(.smooth(duration: 0.3), value: inPeriod.map(\.id))
        }
        .scrollIndicators(.hidden)
        .starhashSoftBottomEdge()
        .activitySwipeActionsContainer()
        .starhashReadableScrollContent()
        .safeAreaInset(edge: .top, spacing: 0) {
            ActivityTopBar(period: period, onPeriod: choosePeriod, onSearch: beginSearch)
        }
    }

    /// "Today", "Yesterday", "Fri 2 Oct", in Keaser's "Latest" style.
    private func dayHeader(_ section: ActivitySummary.DaySection) -> some View {
        Text(ActivitySummary.dayTitle(for: section.day, now: now, calendar: calendar))
            .starhashFont(17, weight: .semibold, relativeTo: .headline)
            .foregroundStyle(Color.starhashSecondaryText)
            .accessibilityAddTraits(.isHeader)
            .padding(.leading, 16)
            .padding(.top, 28)
            .padding(.bottom, 9.5)
    }

    private var searchScreen: some View {
        ActivitySearchView(
            results: ActivitySummary.search(searchText, in: store.transactions),
            text: $searchText,
            isFocused: $searchFocused,
            onOpen: open,
            onConfirm: markConfirmed,
            onDelete: { transactionToDelete = $0 },
            onClose: endSearch
        )
    }

    // MARK: Sheet

    /// The router's open transaction, as a sheet item. A transaction that
    /// no longer exists opens nothing.
    private var openTransaction: Binding<OpenTransaction?> {
        Binding(
            get: {
                router.openTransactionID
                    .flatMap { store.transaction(id: $0) == nil ? nil : OpenTransaction(id: $0) }
            },
            set: { router.openTransactionID = $0?.id }
        )
    }

    // MARK: Actions

    private func open(_ transaction: StarHashKit.Transaction) {
        router.openTransactionID = transaction.id
    }

    /// After the details sheet closes: Pay Again's recipient goes to Pay,
    /// which may open a sheet of its own.
    private func handOffPayAgain() {
        guard let recipient = payAgainRecipient else { return }
        payAgainRecipient = nil
        router.pay(recipient)
    }

    private func choosePeriod(_ new: ActivityPeriod) {
        withAnimation(reduceMotion ? .easeInOut(duration: 0.25) : .smooth(duration: 0.35)) { period = new }
    }

    private func markConfirmed(_ transaction: StarHashKit.Transaction) {
        var confirmed = transaction
        confirmed.status = .confirmed
        // Confirmed by hand, not by an SMS, so no fee is known.
        confirmed.fee = nil
        withAnimation(.smooth(duration: 0.3)) { store.update(confirmed) }
        feedbackCount += 1
    }

    private func delete(_ transaction: StarHashKit.Transaction) {
        withAnimation(.smooth(duration: 0.3)) { store.delete(id: transaction.id) }
        feedbackCount += 1
    }

    private func beginSearch() {
        searchText = ""
        withAnimation(.smooth(duration: 0.25)) { isSearching = true }
        // The field only exists after this update, so focus it on the next.
        Task { @MainActor in searchFocused = true }
    }

    private func endSearch() {
        searchFocused = false
        withAnimation(.smooth(duration: 0.25)) {
            isSearching = false
            searchText = ""
        }
    }

    #if DEBUG
    /// `-activityPeriod today|week|month|year|all`, `-activitySearch <text>`
    /// and `-openFirstTransaction`, for screenshots.
    private func applyDebugLaunch() {
        guard !didApplyDebugLaunch else { return }
        didApplyDebugLaunch = true
        if let value = DebugLaunch.value(after: "-activityPeriod") {
            period = ActivityPeriod(rawValue: value) ?? (value == "allTime" ? .allTime : period)
        }
        if let text = DebugLaunch.value(after: "-activitySearch") {
            isSearching = true
            searchText = text
        }
        if DebugLaunch.arguments.contains("-openFirstTransaction"), let first = store.transactions.first {
            router.openTransactionID = first.id
        }
    }
    #endif
}

/// `AppRouter.openTransactionID` as an identifiable sheet item.
private struct OpenTransaction: Identifiable {
    let id: UUID
}
