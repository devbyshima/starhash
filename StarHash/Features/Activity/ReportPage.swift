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
    /// The category chosen in Categories' ring, or from the summary.
    @State private var chosenCategory: TransactionCategory?
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
        #if DEBUG
        if let page = DebugLaunch.value(after: "-reportSummaries").flatMap(Int.init) {
            ReportGallery(page: page)
                .background(Color.starhashBackground.ignoresSafeArea())
                .toolbar(.hidden, for: .navigationBar)
        } else {
            page
        }
        #else
        page
        #endif
    }

    private var page: some View {
        let report = report
        return ScrollViewReader { scroller in
            ScrollView {
                VStack(spacing: ReportLayout.cardSpacing) {
                    if report.isEmpty {
                        EmptyStateView(doodle: .period, title: "No Transactions")
                            .frame(maxWidth: .infinity)
                            .padding(.top, 80)
                            .transition(.opacity)
                    } else {
                        ReportContent(
                            report: report,
                            calendar: calendar,
                            period: periodPhrase,
                            chosenCategory: $chosenCategory,
                            rollsDigits: !reduceMotion,
                            onOpen: open,
                            onShowCategory: { shown in
                                withAnimation(.easeOut(duration: 0.2)) { chosenCategory = shown }
                                withAnimation(.smooth(duration: 0.45)) { scroller.scrollTo(ReportContent.Card.breakdown, anchor: .top) }
                            },
                            onNarrow: { narrowed in
                                withAnimation(.smooth(duration: 0.3)) { category = narrowed }
                            }
                        )
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
        // A category chosen belongs to the report it was chosen in.
        .onChange(of: [period.rawValue, anchor.description, category?.rawValue ?? ""]) { chosenCategory = nil }
        #if DEBUG
        .onAppear(perform: applyDebugLaunch)
        #endif
    }

    // MARK: Header

    /// Two buttons only, at the owner's ask: back, and More, which holds
    /// everything else. The title carries the period and the category
    /// under it, as they are no longer on buttons.
    private func header(_ report: SpendingReport) -> some View {
        HStack(spacing: 12) {
            Button { dismiss() } label: {
                StarHashCircleGlyph(symbol: "chevron.left")
            }
            .buttonStyle(.hapticPlain)
            .accessibilityLabel("Back")
            Spacer(minLength: 8)
            moreMenu(report)
        }
        .frame(minHeight: ActivityLayout.topBarHeight)
        // The title centred on the screen at the size of every other
        // page's (`PageTitle`), clear of the two buttons.
        .overlay {
            VStack(spacing: 0) {
                PageTitle(text: "Report")
                // The period is the summary's first words; only a category
                // narrowed to is said here.
                if let category {
                    Text(String(starhash: "\(category.title) only"))
                        .reportFont(.detail)
                        .foregroundStyle(Color.starhashSecondaryText)
                        .transition(.opacity)
                }
            }
            .lineLimit(1)
            .minimumScaleFactor(0.8)
            .padding(.horizontal, 44 + 12)
        }
        .padding(.horizontal, StarHashMetrics.screenPadding)
        .padding(.bottom, 4)
        .starhashReadableWidth()
        .starhashClearsWindowControls()
    }

    /// What the summary opens with: "This month", "In October 2026", "In
    /// the week of Nov 2".
    private var periodPhrase: String {
        guard let interval = period.interval(now: anchor, calendar: calendar), !interval.contains(now) else {
            return switch period {
            case .week, .today: String(starhash: "This week")
            case .year, .allTime: String(starhash: "This year")
            case .month: String(starhash: "This month")
            }
        }
        if period == .week {
            return String(starhash: "In the week of \(SpendingReport.dayText(interval.start))")
        }
        return String(starhash: "In \(period.name(for: anchor, calendar: calendar, locale: .starhash, inSentence: true))")
    }

    /// The period (week, month or year), stepping back and forth through
    /// them, the category, and Export.
    private func moreMenu(_ report: SpendingReport) -> some View {
        Menu {
            Picker(selection: periodBinding) {
                ForEach(ActivityPeriod.choices) { choice in
                    Text(choice.unitTitle).tag(choice)
                }
            } label: {
                EmptyView()
            }
            .pickerStyle(.inline)
            Section {
                Button { step(-1) } label: {
                    Label(String(starhash: "Earlier"), symbol: "chevron.left")
                }
                Button { step(1) } label: {
                    Label(String(starhash: "Later"), symbol: "chevron.right")
                }
                .disabled(report.isCurrent || report.interval.end > now)
                if !report.isCurrent {
                    Button { withAnimation(.smooth(duration: 0.35)) { anchor = now } } label: {
                        Label(period.title, symbol: "calendar")
                    }
                }
            }
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
                Label(String(starhash: "Category"), symbol: category?.symbol ?? "chart.bar.fill")
            }
            Section {
                ShareLink(item: ReportPDF(report: report, title: exportTitle(report), period: periodPhrase, calendar: calendar), preview: SharePreview(exportTitle(report))) {
                    Label(String(starhash: "Export Report"), symbol: "square.and.arrow.up.fill")
                }
                .disabled(report.isEmpty)
            }
        } label: {
            StarHashCircleGlyph(symbol: "ellipsis")
        }
        .menuStyle(.button)
        .buttonStyle(.hapticPlain)
        .accessibilityLabel(String(starhash: "More"))
    }

    private var periodBinding: Binding<ActivityPeriod> {
        Binding(get: { period }, set: choosePeriod)
    }

    private func step(_ steps: Int) {
        withAnimation(reduceMotion ? .easeInOut(duration: 0.2) : .smooth(duration: 0.35)) {
            anchor = period.anchor(anchor, movedBy: steps, calendar: calendar)
        }
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
                let url = try ReportPDF(report: report, title: exportTitle(report), period: periodPhrase, calendar: calendar).render()
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
        case summary, overview, breakdown, expenses, types, chart
    }

    let report: SpendingReport
    let calendar: Calendar
    /// "This month": what the summary opens with.
    let period: String
    @Binding var chosenCategory: TransactionCategory?
    var rollsDigits = true
    /// Opens a payment's page; nil in the PDF.
    var onOpen: ((StarHashKit.Transaction) -> Void)?
    /// Shows a category in Categories; nil in the PDF.
    var onShowCategory: ((TransactionCategory) -> Void)?
    /// Narrows the report to a category; nil in the PDF.
    var onNarrow: ((TransactionCategory) -> Void)?
    var isExport = false

    var body: some View {
        VStack(spacing: ReportLayout.cardSpacing) {
            ReportSummary(report: report, period: period, onCategory: onShowCategory)
                .id(Card.summary)
            ReportOverviewCard(report: report, rollsDigits: rollsDigits)
            .id(Card.overview)
            if !report.categories.isEmpty {
                ReportBreakdownCard(report: report, chosen: $chosenCategory, onNarrow: onNarrow, showsEverything: isExport)
                    .id(Card.breakdown)
                ReportLargestCard(report: report, onOpen: onOpen)
                    .id(Card.expenses)
            }
            if !report.types.isEmpty {
                ReportTypesCard(report: report, isStill: isExport)
                    .id(Card.types)
            }
            ReportChartCard(report: report, calendar: calendar, isStill: isExport)
                .id(Card.chart)
        }
    }
}
