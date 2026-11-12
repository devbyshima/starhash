import StarHashKit
import SwiftUI

/// The Report, a tap from Activity's header, after the owner's two
/// references (an October report dashboard and an expense analytics page):
/// the total and how it compares, the top categories and payments, the
/// ring of categories, the chart, payment types, key metrics and a saving
/// to try, for a week, a month or a year.
///
/// The header is the page's own, as Activity's is, not the navigation
/// bar's: iOS lays a bar's items out again once a push has finished, and on
/// the iPhone the whole header then slid a little to the left. Its first
/// line is the back button, the title and the period control; its second
/// steps back and forth through periods, narrows the report to one
/// category, and exports it as a PDF.
struct ReportPage: View {
    @Environment(StarHashStore.self) private var store
    @Environment(AppRouter.self) private var router
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var period: ActivityPeriod = .month
    /// A date inside the period shown: now for the running one, earlier
    /// once the back arrow is pressed.
    @State private var anchor = Date.now
    /// The category the report is narrowed to; nil for all of them.
    @State private var category: TransactionCategory?
    /// The moment the report is worked out for, refreshed as on Activity,
    /// so "This Month" rolls over by itself.
    @State private var now = Date.now
    #if DEBUG
    @State private var didApplyDebugLaunch = false
    @State private var debugCard: ReportContent.Card?
    #endif

    /// The user's calendar, so weeks start on their region's first weekday.
    private var calendar: Calendar { .autoupdatingCurrent }

    private var report: SpendingReport {
        SpendingReport(transactions: store.transactions, period: period, anchor: anchor, now: now, calendar: calendar, category: category)
    }

    var body: some View {
        let report = report
        ScrollViewReader { scroller in
            ScrollView {
                VStack(spacing: ReportLayout.cardSpacing) {
                    if report.isEmpty {
                        EmptyStateView(doodle: .period, title: "No Transactions")
                            .frame(maxWidth: .infinity)
                            .padding(.top, 80)
                            .transition(.opacity)
                    } else {
                        ReportContent(report: report, calendar: calendar, rollsDigits: !reduceMotion, onOpen: open)
                            .transition(.opacity)
                    }
                }
                .padding(.horizontal, StarHashMetrics.screenPadding)
                .padding(.top, 12)
                .padding(.bottom, StarHashMetrics.screenPadding)
                .animation(.smooth(duration: 0.3), value: report.isEmpty)
            }
            #if DEBUG
            .onChange(of: debugCard) { _, card in
                if let card { scroller.scrollTo(card, anchor: .top) }
            }
            #endif
        }
        .scrollIndicators(.hidden)
        .starhashSoftEdge()
        .starhashReadableScrollContent()
        .background(Color.starhashBackground.ignoresSafeArea())
        .starhashSoftEdgeHeader { header(report) }
        .navigationTitle(String(starhash: "Report"))
        .navigationBarBackButtonHidden()
        .toolbar(.hidden, for: .navigationBar)
        // The swipe in from the left edge still goes back.
        .background(SwipeBackEnabler())
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.significantTimeChangeNotification)) { _ in
            refreshNow()
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { refreshNow() }
        }
        .onChange(of: store.transactions.count) { refreshNow() }
        #if DEBUG
        .onAppear(perform: applyDebugLaunch)
        #endif
    }

    // MARK: Header

    private func header(_ report: SpendingReport) -> some View {
        VStack(spacing: 10) {
            HStack(spacing: 12) {
                Button { dismiss() } label: {
                    StarHashCircleGlyph(symbol: "chevron.left")
                }
                .buttonStyle(.hapticPlain)
                .accessibilityLabel("Back")
                Text("Report")
                    .starhashFont(24, weight: .bold, relativeTo: .title2)
                    .foregroundStyle(Color.starhashPrimaryText)
                    .lineLimit(1)
                    .accessibilityAddTraits(.isHeader)
                Spacer(minLength: 8)
                GlassSegmentedControl(
                    options: ActivityPeriod.choices,
                    selection: period,
                    onSelect: choosePeriod,
                    label: \.shortLabel,
                    accessibilityLabel: \.title
                )
            }
            .frame(minHeight: ActivityLayout.topBarHeight)

            HStack(spacing: 8) {
                stepButton(-1, symbol: "chevron.left", label: "Earlier")
                Text(period.title(for: anchor, now: now, calendar: calendar, locale: .starhash))
                    .starhashFont(16, weight: .semibold, relativeTo: .headline)
                    .foregroundStyle(Color.starhashPrimaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .contentTransition(.opacity)
                    .accessibilityAddTraits(.updatesFrequently)
                stepButton(1, symbol: "chevron.right", label: "Later")
                    .disabled(report.isCurrent || report.interval.end > now)
                Spacer(minLength: 4)
                categoryMenu
                ShareLink(item: ReportPDF(report: report, title: exportTitle(report), calendar: calendar), preview: SharePreview(exportTitle(report))) {
                    StarHashCircleGlyph(symbol: "square.and.arrow.up.fill")
                }
                .buttonStyle(.hapticPlain)
                .disabled(report.isEmpty)
                .accessibilityLabel("Export Report")
            }
        }
        .padding(.horizontal, StarHashMetrics.screenPadding)
        .padding(.bottom, 4)
        .starhashReadableWidth()
        .starhashClearsWindowControls()
    }

    private func stepButton(_ steps: Int, symbol: String, label: LocalizedStringKey) -> some View {
        Button {
            withAnimation(reduceMotion ? .easeInOut(duration: 0.2) : .smooth(duration: 0.35)) {
                anchor = period.anchor(anchor, movedBy: steps, calendar: calendar)
            }
        } label: {
            Image(symbol: symbol)
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(Color.starhashPrimaryText)
                .frame(width: 32, height: 32)
                .starhashGlass(in: Circle(), interactive: true, tint: .clear)
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.hapticPlain)
        .accessibilityLabel(label)
    }

    /// Narrows the report to one category, or All Categories.
    private var categoryMenu: some View {
        Menu {
            Picker(selection: categoryBinding) {
                Text("All Categories").tag(TransactionCategory?.none)
                ForEach(TransactionCategory.choices) { choice in
                    Label(choice.title, symbol: choice.symbol).tag(TransactionCategory?.some(choice))
                }
            } label: {
                EmptyView()
            }
            .pickerStyle(.inline)
        } label: {
            HStack(spacing: 6) {
                // The chosen category's icon alone, as its name would not
                // fit beside the arrows; Total Spent names it.
                if let category {
                    ReportCategoryIcon(category: category, size: 24)
                } else {
                    Text("All")
                        .starhashFont(15, weight: .semibold, relativeTo: .subheadline)
                        .lineLimit(1)
                }
                Image(symbol: "chevron.up.chevron.down")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(Color.starhashSecondaryText)
            }
            .foregroundStyle(Color.starhashPrimaryText)
            .padding(.horizontal, 14)
            .frame(height: 44)
            .starhashGlass(interactive: true, tint: .clear)
        }
        .menuStyle(.button)
        .buttonStyle(.hapticPlain)
        .accessibilityLabel(String(starhash: "Category"))
        .accessibilityValue(category?.title ?? String(starhash: "All Categories"))
    }

    private var categoryBinding: Binding<TransactionCategory?> {
        Binding(
            get: { category },
            set: { new in withAnimation(.smooth(duration: 0.3)) { category = new } }
        )
    }

    // MARK: Actions

    private func choosePeriod(_ new: ActivityPeriod) {
        withAnimation(reduceMotion ? .easeInOut(duration: 0.25) : .smooth(duration: 0.35)) { period = new }
    }

    private func open(_ transaction: StarHashKit.Transaction) {
        router.openTransactionID = transaction.id
    }

    /// Moves on to the new day or month, keeping a report looked back on
    /// where it is but carrying the running one along with the clock.
    private func refreshNow() {
        let wasCurrent = report.isCurrent
        now = .now
        if wasCurrent { anchor = now }
    }

    private func exportTitle(_ report: SpendingReport) -> String {
        let name = period.name(for: anchor, calendar: calendar, locale: .starhash)
        guard let category = report.category else { return String(starhash: "StarHash Report, \(name)") }
        return String(starhash: "StarHash Report, \(name), \(category.title)")
    }

    #if DEBUG
    /// `-activityPeriod week|month|year`, `-reportBack <n>` (that many
    /// periods earlier), `-reportCategory <raw value>` and `-reportCard
    /// <card>` (scrolled to it), for screenshots.
    private func applyDebugLaunch() {
        guard !didApplyDebugLaunch else { return }
        didApplyDebugLaunch = true
        if let value = DebugLaunch.value(after: "-activityPeriod"), let chosen = ActivityPeriod(rawValue: value) {
            period = chosen
        }
        if let value = DebugLaunch.value(after: "-reportBack"), let steps = Int(value) {
            anchor = period.anchor(anchor, movedBy: -steps, calendar: calendar)
        }
        if let value = DebugLaunch.value(after: "-reportCategory") {
            category = TransactionCategory(rawValue: value)
        }
        if let value = DebugLaunch.value(after: "-reportCard"), let card = ReportContent.Card(rawValue: value) {
            Task {
                try? await Task.sleep(for: .milliseconds(600))
                debugCard = card
            }
        }
        // `-reportPDF`: writes Export's PDF and logs where, to check it
        // without the share sheet.
        if DebugLaunch.arguments.contains("-reportPDF") {
            let report = report
            do {
                let url = try ReportPDF(report: report, title: exportTitle(report), calendar: calendar).render()
                print("ReportPDF:", url.path)
            } catch {
                print("ReportPDF failed:", error)
            }
        }
    }
    #endif
}

/// Every card of a report, in the references' order. The page and the
/// PDF both draw it.
struct ReportContent: View {
    /// Each card, by name, for `-reportCard`.
    enum Card: String {
        case overview, categories, expenses, breakdown, chart, types, metrics, saving
    }

    let report: SpendingReport
    let calendar: Calendar
    var rollsDigits = true
    /// Opens a payment's page; nil in the PDF.
    var onOpen: ((StarHashKit.Transaction) -> Void)?
    var isExport = false

    var body: some View {
        VStack(spacing: ReportLayout.cardSpacing) {
            ReportOverviewCard(
                report: report,
                rangeText: report.period.rangeText(for: report.interval.start, calendar: calendar, locale: .starhash) ?? "",
                rollsDigits: rollsDigits
            )
            .id(Card.overview)
            if !report.categories.isEmpty {
                ReportTopCategoriesCard(report: report)
                    .id(Card.categories)
                ReportTopExpensesCard(report: report, onOpen: onOpen)
                    .id(Card.expenses)
                ReportBreakdownCard(report: report, showsEverything: isExport)
                    .id(Card.breakdown)
            }
            ReportChartCard(
                report: report,
                buckets: ActivitySummary.buckets(for: report.transactions, period: report.period, now: report.interval.start, calendar: calendar, locale: .starhash),
                calendar: calendar
            )
            .id(Card.chart)
            if !report.types.isEmpty {
                ReportTypesCard(report: report)
                    .id(Card.types)
            }
            ReportMetricsCard(report: report)
                .id(Card.metrics)
            if let saving = report.saving {
                ReportSavingCard(saving: saving)
                    .id(Card.saving)
            }
        }
    }
}
