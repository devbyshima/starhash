import StarHashKit
import SwiftUI

/// The Report, a tap from Activity's header: the spending summary and its
/// chart for the week, the month or the year, as the top of Activity once
/// held them. The period control sits across from the title, and a period
/// with nothing in it shows the empty calendar.
struct ReportPage: View {
    @Environment(StarHashStore.self) private var store
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var period: ActivityPeriod = .week
    /// The moment the totals and chart are worked out for, refreshed as on
    /// Activity, so "This Week" rolls over by itself.
    @State private var now = Date.now
    #if DEBUG
    @State private var didApplyDebugLaunch = false
    #endif

    /// The user's calendar, so weeks start on their region's first weekday.
    private var calendar: Calendar { .autoupdatingCurrent }

    var body: some View {
        let inPeriod = ActivitySummary.transactions(store.transactions, in: period, now: now, calendar: calendar)
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                header
                    .padding(.bottom, ActivityLayout.contentTop)
                if inPeriod.isEmpty {
                    EmptyStateView(doodle: .period, title: "No Transactions")
                        .frame(maxWidth: .infinity)
                        .padding(.top, 80)
                        .transition(.opacity)
                } else {
                    ActivitySummaryCard(
                        period: period,
                        totals: ActivitySummary.totals(of: inPeriod),
                        buckets: ActivitySummary.buckets(for: inPeriod, period: period, now: now, calendar: calendar),
                        calendar: calendar
                    )
                    .transition(.opacity)
                }
            }
            .padding(.horizontal, StarHashMetrics.screenPadding)
            .padding(.bottom, StarHashMetrics.screenPadding)
            .animation(.smooth(duration: 0.3), value: inPeriod.isEmpty)
        }
        .scrollIndicators(.hidden)
        .starhashSoftEdge()
        .starhashReadableScrollContent()
        .background(Color.starhashBackground.ignoresSafeArea())
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.significantTimeChangeNotification)) { _ in
            now = .now
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { now = .now }
        }
        .onChange(of: store.transactions.count) { now = .now }
        #if DEBUG
        .onAppear(perform: applyDebugLaunch)
        #endif
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 12) {
            Text("Report")
                .starhashFont(34, weight: .bold, relativeTo: .largeTitle)
                .foregroundStyle(Color.starhashPrimaryText)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .accessibilityAddTraits(.isHeader)
            Spacer(minLength: 0)
            GlassSegmentedControl(
                options: ActivityPeriod.choices,
                selection: period,
                onSelect: choosePeriod,
                label: \.shortLabel,
                accessibilityLabel: \.title
            )
        }
    }

    private func choosePeriod(_ new: ActivityPeriod) {
        withAnimation(reduceMotion ? .easeInOut(duration: 0.25) : .smooth(duration: 0.35)) { period = new }
    }

    #if DEBUG
    /// `-activityPeriod week|month|year`, for screenshots.
    private func applyDebugLaunch() {
        guard !didApplyDebugLaunch else { return }
        didApplyDebugLaunch = true
        if let value = DebugLaunch.value(after: "-activityPeriod"), let chosen = ActivityPeriod(rawValue: value) {
            period = chosen
        }
    }
    #endif
}
