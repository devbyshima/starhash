import StarHashKit
import SwiftUI
import UIKit

/// The Activity tab, after the owner's reference: the title with the
/// report, search and the owner's photo, and every transaction grouped by
/// month. The spending summary and its chart are on the Report page, a tap
/// away. Search replaces the list with its own full-screen view while it is
/// open, and the tab bar steps aside meanwhile, as it does for a pushed
/// page.
///
/// A transaction's details are a page pushed on the tab's own stack, opened
/// through `AppRouter.openTransactionID`, so a route from a URL or an intent
/// opens the same page a tap does. Report and Profile push on the same
/// stack.
struct ActivityView: View {
    @Environment(StarHashStore.self) private var store
    @Environment(AppRouter.self) private var router
    @Environment(\.scenePhase) private var scenePhase

    /// The moment the totals and chart are worked out for. Refreshed on
    /// clock, day or time zone changes and on returning to the app, so
    /// "Today" and "This Week" roll over by themselves.
    @AppStorage(PreferenceKey.enableContacts) private var enableContacts = true
    @AppStorage(PreferenceKey.confirmDeletes) private var confirmDeletes = true
    @State private var now = Date.now
    /// Report or Profile, when one is pushed.
    @State private var page: ActivityRoute?

    @State private var isSearching = false
    @State private var searchText = ""
    @FocusState private var searchFocused: Bool

    @State private var transactionToDelete: StarHashKit.Transaction?
    @State private var transactionToVerify: StarHashKit.Transaction?
    @State private var feedbackCount = 0
    @State private var failedCount = 0
    @State private var swipeDeleteCount = 0
    #if DEBUG
    @State private var didApplyDebugLaunch = false
    #endif

    /// The user's calendar, so weeks start on their region's first weekday.
    private var calendar: Calendar { .autoupdatingCurrent }

    var body: some View {
        NavigationStack(path: activityPath) {
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
            // search, so the bar steps aside (unless a
            // search is open, so it can still be closed).
            .starhashSoftEdgeHeader {
                if !store.transactions.isEmpty || isSearching {
                    topBar
                        .transition(.opacity)
                }
            }
            .animation(.smooth(duration: 0.3), value: store.transactions.isEmpty)
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(for: ActivityRoute.self) { route in
                switch route {
                case .transaction(let id):
                    TransactionDetailPage(transactionID: id, onPayAgain: payAgain)
                        .starhashBackButton()
                case .report:
                    // Its title and period control sit up beside the back
                    // button, so it brings its own.
                    ReportPage()
                }
            }
        }
        .onChange(of: !activityPath.wrappedValue.isEmpty || isSearching, initial: true) { _, covers in
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
        .sheet(item: $transactionToVerify) { VerifyPaymentSheet(transactionID: $0.id) }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.significantTimeChangeNotification)) { _ in
            now = .now
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { now = .now }
        }
        // A payment logged while the page is up (a message through
        // auto-verify, one made on Pay) can fall after the last refresh,
        // past midnight or into a new month: the headings move on with it.
        .onChange(of: store.transactions.count) { now = .now }
        .onAppear { now = .now }
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
            title: "No Transactions"
        )
        .padding(.horizontal, StarHashMetrics.screenPadding)
        .starhashCentredOverTabBar()
    }

    private var listScreen: some View {
        let sections = ActivitySummary.groupedByMonth(store.transactions, calendar: calendar)
        return ScrollView {
            LazyVStack(alignment: .leading, spacing: 0) {
                ForEach(sections) { section in
                    monthHeader(section, isFirst: section.id == sections.first?.id)
                    // Each day of the month under its own heading.
                    ForEach(ActivitySummary.groupedByDay(section.transactions, calendar: calendar)) { day in
                        dayHeader(day)
                        ActivityTransactionRows(
                            transactions: day.transactions,
                            onOpen: open,
                            onVerify: verify,
                            onFail: markFailed,
                            onPayAgain: payAgain,
                            onDelete: requestDelete,
                            onSwipeDelete: swipeDelete,
                            showsDate: false
                        )
                    }
                }
            }
            .padding(.horizontal, StarHashMetrics.screenPadding)
            .padding(.bottom, StarHashMetrics.screenPadding)
            .animation(.smooth(duration: 0.3), value: store.transactions.map(\.id))
        }
        .scrollIndicators(.hidden)
        .starhashSoftEdge()
        .starhashTabBarClearance()
        .starhashTabBarFollowsScroll()
        .activitySwipeActionsContainer()
        .starhashReadableScrollContent()
    }

    /// "August", "July", "December 2025": bold, as the reference's.
    private func monthHeader(_ section: ActivitySummary.DaySection, isFirst: Bool) -> some View {
        Text(ActivitySummary.monthTitle(for: section.day, now: now, calendar: calendar, locale: .starhash))
            .starhashFont(22, weight: .bold, relativeTo: .title2)
            .foregroundStyle(Color.starhashPrimaryText)
            .accessibilityAddTraits(.isHeader)
            .padding(.top, isFirst ? ActivityLayout.contentTop : ActivityLayout.monthTop)
            .padding(.bottom, ActivityLayout.monthBottom)
    }

    /// "Today", "Yesterday", "Mon, Oct 20": a day's heading under its month,
    /// in the quieter text, smaller than the month's.
    private func dayHeader(_ day: ActivitySummary.DaySection) -> some View {
        Text(ActivitySummary.dayTitle(for: day.day, now: now, calendar: calendar, locale: .starhash))
            .starhashFont(15, weight: .semibold, relativeTo: .subheadline)
            .foregroundStyle(Color.starhashSecondaryText)
            .accessibilityAddTraits(.isHeader)
            .padding(.top, ActivityLayout.dayTop)
            .padding(.bottom, ActivityLayout.dayBottom)
    }

    private var topBar: some View {
        ActivityTopBar(
            isSearching: isSearching,
            searchText: $searchText,
            searchFocused: $searchFocused,
            onReport: { page = .report },
            onSearch: beginSearch,
            onCloseSearch: endSearch
        )
    }

    private var searchScreen: some View {
        ActivitySearchView(
            results: ActivitySummary.search(searchText, in: store.transactions),
            text: searchText,
            onOpen: open,
            onVerify: verify,
            onFail: markFailed,
            onPayAgain: payAgain,
            onDelete: requestDelete,
            onSwipeDelete: swipeDelete
        )
    }

    // MARK: Details

    /// Report or Profile, then the router's open transaction, as the
    /// stack's path. A transaction that no longer exists opens nothing.
    private var activityPath: Binding<[ActivityRoute]> {
        Binding(
            get: {
                var path = page.map { [$0] } ?? []
                if let id = router.openTransactionID, store.transaction(id: id) != nil {
                    path.append(.transaction(id))
                }
                return path
            },
            set: { path in
                page = path.first { $0.transactionID == nil }
                router.openTransactionID = path.lazy.compactMap(\.transactionID).last
            }
        )
    }

    // MARK: Actions

    private func open(_ transaction: StarHashKit.Transaction) {
        router.openTransactionID = transaction.id
    }

    /// Pay Again on the details page or a row's menu: back to the list, and
    /// the recipient to Pay.
    private func payAgain(_ recipient: Recipient) {
        router.openTransactionID = nil
        router.pay(recipient)
    }

    /// Verify's sheet, over the list: the payment is settled by its
    /// wallet's message.
    private func verify(_ transaction: StarHashKit.Transaction) {
        transactionToVerify = transaction
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
    /// `-openReport`, `-activitySearch <text>`, `-openFirstTransaction`,
    /// `-openPendingTransaction` and `-openFailedTransaction`, for
    /// screenshots (`-activityPeriod` picks the Report's period).
    private func applyDebugLaunch() {
        guard !didApplyDebugLaunch else { return }
        didApplyDebugLaunch = true
        if DebugLaunch.arguments.contains("-openReport") { page = .report }
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
        if DebugLaunch.arguments.contains("-openFailedTransaction"),
           let failed = store.transactions.first(where: { $0.status == .failed }) {
            router.openTransactionID = failed.id
        }
    }
    #endif
}

/// The pages Activity pushes.
enum ActivityRoute: Hashable {
    case transaction(UUID)
    case report

    var transactionID: UUID? {
        if case .transaction(let id) = self { id } else { nil }
    }
}
