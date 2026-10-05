import StarHashKit
import SwiftUI
import UIKit

/// The Activity tab, modelled on Keaser's Home: the period picker and
/// search, the spending summary with its chart, and the period's
/// transactions grouped by day. Search replaces all of it with its own
/// full-screen view while it is open, and the tab bar steps aside meanwhile,
/// as it does for a transaction's page.
///
/// A transaction's details are a page pushed on the tab's own stack, opened
/// through `AppRouter.openTransactionID`, so a route from a URL or an intent
/// opens the same page a tap does.
struct ActivityView: View {
    @Environment(StarHashStore.self) private var store
    @Environment(AppRouter.self) private var router
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// The moment the totals and chart are worked out for. Refreshed on
    /// clock, day or time zone changes and on returning to the app, so
    /// "Today" and "This Week" roll over by themselves.
    @AppStorage(PreferenceKey.enableContacts) private var enableContacts = true
    @AppStorage(PreferenceKey.confirmDeletes) private var confirmDeletes = true
    @State private var now = Date.now
    @State private var period: ActivityPeriod = .week

    @State private var isSearching = false
    @State private var searchText = ""
    @FocusState private var searchFocused: Bool

    @State private var transactionToDelete: StarHashKit.Transaction?
    @State private var feedbackCount = 0
    @State private var failedCount = 0
    @State private var swipeDeleteCount = 0
    #if DEBUG
    @State private var didApplyDebugLaunch = false
    #endif

    /// The user's calendar, so weeks start on their region's first weekday.
    private var calendar: Calendar { .autoupdatingCurrent }

    var body: some View {
        NavigationStack(path: openTransactionPath) {
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
            // One bar for both, as on the recipient screen: searching only
            // swaps what is in it. With nothing logged there is nothing to
            // pick a period of or search, so the bar steps aside (unless a
            // search is open, so it can still be closed).
            .starhashSoftEdgeHeader {
                if !store.transactions.isEmpty || isSearching {
                    topBar
                        .transition(.opacity)
                }
            }
            .animation(.smooth(duration: 0.3), value: store.transactions.isEmpty)
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(for: UUID.self) { id in
                TransactionDetailPage(transactionID: id, onPayAgain: payAgain)
                    .starhashBackButton()
            }
        }
        .onChange(of: !openTransactionPath.wrappedValue.isEmpty || isSearching, initial: true) { _, covers in
            router.setHidesTabBar(covers, on: .activity)
        }
        // A link to a transaction that is not there (deleted, or from
        // another phone) opens nothing, and is forgotten.
        .onChange(of: router.openTransactionID, initial: true) { _, id in
            if let id, store.transaction(id: id) == nil { router.openTransactionID = nil }
        }
        // Contact photos for the rows, read once access is already granted.
        .task(id: enableContacts) {
            if enableContacts { await PayContacts.shared.loadIfAllowed() }
        }
        .deleteTransactionDialog($transactionToDelete, onDelete: delete)
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.significantTimeChangeNotification)) { _ in
            now = .now
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { now = .now }
        }
        .sensoryFeedback(.success, trigger: feedbackCount)
        .sensoryFeedback(.warning, trigger: failedCount)
        .sensoryFeedback(.impact(flexibility: .rigid), trigger: swipeDeleteCount)
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

    /// Nothing logged yet: the doodle and its words alone, centred between
    /// the status bar and the tab bar; the page has no top bar then.
    private var emptyScreen: some View {
        EmptyStateView(
            doodle: .transactions,
            title: "No Transactions",
            message: "Pay someone from Pay, or set up Auto-verify in Settings to log MoMo messages."
        )
        .padding(.horizontal, StarHashMetrics.screenPadding)
        .starhashCentredOverTabBar()
    }

    /// Nothing in the chosen period: the empty state alone, centred between
    /// the top bar (kept, to choose another period) and the tab bar, with
    /// no summary over it.
    private func emptyPeriodScreen() -> some View {
        EmptyStateView(
            doodle: .period,
            title: "No Transactions",
            message: "Nothing was paid or received \(period.emptyPhrase)."
        )
        .padding(.horizontal, StarHashMetrics.screenPadding)
        .starhashCentredOverTabBar()
    }

    @ViewBuilder
    private var listScreen: some View {
        let all = store.transactions
        let inPeriod = ActivitySummary.transactions(all, in: period, now: now, calendar: calendar)
        let sections = ActivitySummary.groupedByDay(inPeriod, calendar: calendar)
        if sections.isEmpty {
            emptyPeriodScreen()
                .transition(.opacity)
        } else {
            periodList(inPeriod: inPeriod, sections: sections)
                .transition(.opacity)
        }
    }

    private func periodList(inPeriod: [StarHashKit.Transaction], sections: [ActivitySummary.DaySection]) -> some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0) {
                Group {
                    ActivitySummaryCard(
                        period: period,
                        totals: ActivitySummary.totals(of: inPeriod),
                        buckets: ActivitySummary.buckets(for: inPeriod, period: period, now: now, calendar: calendar),
                        calendar: calendar
                    )
                    ForEach(sections) { section in
                        dayHeader(section)
                        ActivityTransactionRows(
                            transactions: section.transactions,
                            onOpen: open,
                            onConfirm: markConfirmed,
                            onFail: markFailed,
                            onDelete: requestDelete,
                            onSwipeDelete: swipeDelete
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
        .starhashSoftEdge()
        .starhashTabBarClearance()
        .starhashTabBarFollowsScroll()
        .activitySwipeActionsContainer()
        .starhashReadableScrollContent()
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

    private var topBar: some View {
        ActivityTopBar(
            period: period,
            onPeriod: choosePeriod,
            isSearching: isSearching,
            searchText: $searchText,
            searchFocused: $searchFocused,
            onSearch: beginSearch,
            onCloseSearch: endSearch
        )
    }

    private var searchScreen: some View {
        ActivitySearchView(
            results: ActivitySummary.search(searchText, in: store.transactions),
            text: searchText,
            onOpen: open,
            onConfirm: markConfirmed,
            onFail: markFailed,
            onDelete: requestDelete,
            onSwipeDelete: swipeDelete
        )
    }

    // MARK: Details

    /// The router's open transaction as the stack's path. A transaction that
    /// no longer exists opens nothing.
    private var openTransactionPath: Binding<[UUID]> {
        Binding(
            get: {
                guard let id = router.openTransactionID, store.transaction(id: id) != nil else { return [] }
                return [id]
            },
            set: { router.openTransactionID = $0.last }
        )
    }

    // MARK: Actions

    private func open(_ transaction: StarHashKit.Transaction) {
        router.openTransactionID = transaction.id
    }

    /// Pay Again on the details page: back to the list, and the recipient
    /// to Pay.
    private func payAgain(_ recipient: Recipient) {
        router.openTransactionID = nil
        router.pay(recipient)
    }

    private func choosePeriod(_ new: ActivityPeriod) {
        withAnimation(reduceMotion ? .easeInOut(duration: 0.25) : .smooth(duration: 0.35)) { period = new }
    }

    /// Its fee from the carriers' prices, for the wallet it was dialled
    /// with (the one that pays now for payments saved before that was kept).
    private func markConfirmed(_ transaction: StarHashKit.Transaction) {
        let confirmed = transaction.confirmedByHand(wallet: StarHashPreferences.wallet)
        withAnimation(.smooth(duration: 0.3)) { store.update(confirmed) }
        feedbackCount += 1
    }

    /// The payment did not go through: it stays in Activity, struck
    /// through, and counts towards nothing.
    private func markFailed(_ transaction: StarHashKit.Transaction) {
        withAnimation(.smooth(duration: 0.3)) { store.update(transaction.markedFailed()) }
        failedCount += 1
    }

    /// Asks first, unless Don't Ask Again was chosen.
    private func requestDelete(_ transaction: StarHashKit.Transaction) {
        if confirmDeletes {
            transactionToDelete = transaction
        } else {
            delete(transaction)
        }
    }

    /// A full swipe, or the trash it reveals: gone at once with a firm tap,
    /// as Beam deletes a copied item. The swipe is the deliberate gesture,
    /// so it does not ask.
    private func swipeDelete(_ transaction: StarHashKit.Transaction) {
        withAnimation(.smooth(duration: 0.3)) { store.delete(id: transaction.id) }
        swipeDeleteCount += 1
    }

    private func delete(_ transaction: StarHashKit.Transaction) {
        withAnimation(.smooth(duration: 0.3)) { store.delete(id: transaction.id) }
        feedbackCount += 1
    }

    private func beginSearch() {
        searchText = ""
        withAnimation(.smooth(duration: 0.32)) { isSearching = true }
        // The field only exists after this update, so focus it on the next.
        Task { @MainActor in searchFocused = true }
    }

    private func endSearch() {
        searchFocused = false
        withAnimation(.smooth(duration: 0.32)) {
            isSearching = false
            searchText = ""
        }
    }

    #if DEBUG
    /// `-activityPeriod today|week|month|year|all`, `-activitySearch <text>`,
    /// `-openFirstTransaction` and `-openPendingTransaction`, for screenshots.
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
        if DebugLaunch.arguments.contains("-openPendingTransaction"),
           let pending = store.transactions.first(where: { $0.status == .pending }) {
            router.openTransactionID = pending.id
        }
    }
    #endif
}
