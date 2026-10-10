import StarHashKit
import SwiftUI

/// Reports: a month of money, a page pushed on Activity (and where the
/// weekly and monthly summaries' notifications land), set in GO Club's
/// "Carbon" screens' type: numbers very large, bold and tight with their
/// unit small and close after them, tiny quiet labels under them, a thin
/// bar chart with one bar lit, bright solid cards, and rows like its
/// "Today's Summary". From the top: the month and the way back and forward
/// through the months with anything in them; what went out, against the
/// month before, and what came in, the fees and the payments; the month day
/// by day; a few sentences on it (written on the iPhone, by Apple
/// Intelligence where it can); the biggest share and the busiest day;
/// where the money went and who was paid the most; and, at the foot,
/// everything spent since the first payment, large and quiet.
struct ReportsView: View {
    @Environment(StarHashStore.self) private var store
    @Environment(AppRouter.self) private var router

    /// The month showing, by its first day.
    @State private var month: Date
    @State private var summary: ReportNarrator.Summary?

    private var calendar: Calendar { .autoupdatingCurrent }

    init(month: Date) {
        _month = State(initialValue: month)
    }

    private var report: MonthlyReport {
        MonthlyReport.make(for: month, from: store.transactions, calendar: calendar)
    }

    /// The months there is anything in, and this one, newest first.
    private var months: [Date] {
        var all = MonthlyReport.months(with: store.transactions, calendar: calendar)
        if let now = calendar.dateInterval(of: .month, for: .now)?.start, !all.contains(now) { all.insert(now, at: 0) }
        if !all.contains(month) { all.append(month) }
        return all.sorted(by: >)
    }

    var body: some View {
        let report = report
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                monthBar
                if report.isEmpty {
                    EmptyStateView(
                        doodle: .period,
                        title: "Nothing This Month",
                        message: String(localized: "Nothing was paid or received in \(monthName(month)).")
                    )
                    .frame(maxWidth: .infinity)
                    .padding(.top, 80)
                } else {
                    hero(report)
                        .padding(.top, 26)
                    stats(report)
                        .padding(.top, 26)
                    dailyChart(report)
                        .padding(.top, 34)
                    summaryCard
                        .padding(.top, 30)
                    pairOfCards(report)
                        .padding(.top, 10)
                    if !report.groups.isEmpty {
                        list(String(localized: "Where it went"), rows: report.groups.prefix(6).map(groupRow))
                            .padding(.top, 38)
                    }
                    if !report.topRecipients.isEmpty {
                        list(String(localized: "Paid the most"), rows: report.topRecipients.map(recipientRow))
                            .padding(.top, 34)
                    }
                    lifetime
                        .padding(.top, 42)
                }
            }
            .padding(.horizontal, 22)
            .padding(.bottom, 40)
            .animation(.smooth(duration: 0.3), value: month)
        }
        .scrollIndicators(.hidden)
        .starhashSoftEdge()
        .starhashReadableScrollContent()
        .background(Color.starhashBackground.ignoresSafeArea())
        // The page is its own title, as GO's are.
        .navigationTitle(String(localized: "Reports"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) { Color.clear.frame(width: 1, height: 1) }
        }
        .task(id: TaskKey(month: month, count: store.transactions.count)) { await writeSummary(of: report) }
        .sensoryFeedback(.selection, trigger: month)
    }

    private struct TaskKey: Hashable {
        let month: Date
        let count: Int
    }

    // MARK: Month

    /// "October 2026" small and bold, as GO's "Today's Summary", with the
    /// months either side a tap away.
    private var monthBar: some View {
        let index = months.firstIndex(of: month) ?? 0
        let older = index + 1 < months.count ? months[index + 1] : nil
        let newer = index > 0 ? months[index - 1] : nil
        return HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Monthly report")
                    .starhashFont(13, weight: .medium, relativeTo: .footnote)
                    .foregroundStyle(Color.starhashSecondaryText)
                Text(monthName(month, withYear: true))
                    .starhashFont(20, weight: .bold, relativeTo: .title3)
                    .foregroundStyle(Color.starhashPrimaryText)
                    .contentTransition(.numericText())
                    .accessibilityAddTraits(.isHeader)
            }
            Spacer(minLength: 0)
            SwapGlassButton(symbol: "chevron.left", label: String(localized: "Previous month")) {
                if let older { step(to: older) }
            }
            .disabled(older == nil)
            .opacity(older == nil ? 0.35 : 1)
            SwapGlassButton(symbol: "chevron.right", label: String(localized: "Next month")) {
                if let newer { step(to: newer) }
            }
            .disabled(newer == nil)
            .opacity(newer == nil ? 0.35 : 1)
        }
        .padding(.top, 4)
    }

    private func step(to new: Date) {
        summary = nil
        withAnimation(.smooth(duration: 0.3)) { month = new }
    }

    // MARK: The total

    /// The month's spending, as GO sets "3,87,459 Steps": the number as
    /// large as the width allows, what it counts under it, and against the
    /// month before with a dot, as its "120% Over than yesterday".
    private func hero(_ report: MonthlyReport) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            ReportNumber(value: Money.format(report.spent), size: 76)
                .contentTransition(.numericText(value: Double(report.spent)))
            Text("RWF spent in \(monthName(month))")
                .starhashFont(22, weight: .bold, relativeTo: .title2)
                .foregroundStyle(Color.starhashPrimaryText)
            if let change = report.change {
                let percent = Int((abs(change) * 100).rounded())
                let previous = monthName(calendar.date(byAdding: .month, value: -1, to: month) ?? month)
                HStack(spacing: 6) {
                    Circle()
                        .fill(change > 0 ? Color.reportUp : Color.reportDown)
                        .frame(width: 8, height: 8)
                    Text(change > 0 ? "\(percent)% more than \(previous)" : "\(percent)% less than \(previous)")
                        .starhashFont(14, weight: .semibold, relativeTo: .subheadline)
                        .foregroundStyle(Color.starhashSecondaryText)
                }
                .padding(.top, 6)
                .accessibilityElement(children: .combine)
            }
        }
        .accessibilityElement(children: .combine)
    }

    /// GO's "0.12km Distance · 20kcal Calories · 0 Floors": three numbers
    /// with their units, a tiny label under each.
    private func stats(_ report: MonthlyReport) -> some View {
        HStack(alignment: .top, spacing: 0) {
            ReportStat(value: Money.compact(report.received), unit: Money.currency, label: String(localized: "Received"))
            ReportStat(value: Money.compact(report.fees), unit: Money.currency, label: String(localized: "Fees"))
            ReportStat(value: String(report.paymentCount), unit: nil, label: report.paymentCount == 1 ? String(localized: "Payment") : String(localized: "Payments"))
        }
    }

    // MARK: Day by day

    /// What went out on each day of the month, as GO's step bars: thin,
    /// rounded, quiet, with the biggest day lit and its two figures over
    /// the chart, as GO puts its limit and its "over" there.
    private func dailyChart(_ report: MonthlyReport) -> some View {
        let days = dailySpending()
        let top = max(days.max() ?? 0, 1)
        let biggest = days.indices.max { days[$0] < days[$1] }
        return VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 26) {
                if let biggest, days[biggest] > 0 {
                    chartFigure(
                        Money.format(days[biggest]),
                        dot: .reportHighlight,
                        label: String(localized: "Biggest day, \(dayName(biggest + 1))")
                    )
                }
                chartFigure(Money.format(report.dailyAverage), dot: .reportBar, label: String(localized: "Average a day"))
            }
            GeometryReader { proxy in
                let count = max(days.count, 1)
                let slot = proxy.size.width / CGFloat(count)
                let width = max(3, min(8, slot * 0.55))
                HStack(alignment: .bottom, spacing: 0) {
                    ForEach(Array(days.enumerated()), id: \.offset) { index, value in
                        Capsule()
                            .fill(index == biggest && value > 0 ? Color.reportHighlight : Color.reportBar)
                            .frame(width: width, height: max(width, proxy.size.height * CGFloat(value) / CGFloat(top)))
                            .frame(width: slot, alignment: .center)
                    }
                }
                .frame(maxHeight: .infinity, alignment: .bottom)
            }
            .frame(height: 150)
            .accessibilityElement()
            .accessibilityLabel(String(localized: "Spending day by day"))
            .accessibilityValue(biggest.map { String(localized: "Most on \(dayName($0 + 1)), \(Money.formatWithCurrency(days[$0]))") } ?? "")
            // The days along the foot, a week apart, each under its own bar:
            // the same slots as the bars, so the 8 sits under the 8th.
            GeometryReader { proxy in
                let slot = proxy.size.width / CGFloat(max(days.count, 1))
                ForEach([1, 8, 15, 22, 29].filter { $0 <= days.count }, id: \.self) { day in
                    Text(String(day))
                        .starhashFont(11, weight: .medium, relativeTo: .caption2, tracking: 0)
                        .foregroundStyle(Color.starhashTertiaryText)
                        .fixedSize()
                        .position(x: slot * (CGFloat(day) - 0.5), y: proxy.size.height / 2)
                }
            }
            .frame(height: 16)
            .accessibilityHidden(true)
        }
    }

    private func chartFigure(_ value: String, dot: Color, label: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            ReportNumber(value: value, unit: Money.currency, size: 20)
            HStack(spacing: 5) {
                Circle().fill(dot).frame(width: 7, height: 7)
                Text(label)
                    .starhashFont(12, weight: .medium, relativeTo: .caption)
                    .foregroundStyle(Color.starhashSecondaryText)
            }
        }
        .accessibilityElement(children: .combine)
    }

    // MARK: Cards

    /// The month in a few sentences, on a yellow card, as GO's "Invite".
    private var summaryCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "sparkles")
                    .font(.system(size: 22, weight: .bold))
                Text("Your month")
                    .starhashFont(30, weight: .bold, relativeTo: .title)
            }
            if let summary {
                Text(summary.text)
                    .starhashFont(16, weight: .medium, relativeTo: .callout)
                    .fixedSize(horizontal: false, vertical: true)
                    .transition(.opacity)
                if summary.byModel {
                    Text("Written on your iPhone by Apple Intelligence. Check the figures.")
                        .starhashFont(12, weight: .medium, relativeTo: .caption)
                        .opacity(0.7)
                }
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(0..<3, id: \.self) { line in
                        Capsule()
                            .fill(Color.brandNight.opacity(0.12))
                            .frame(height: 12)
                            .frame(maxWidth: line == 2 ? 170 : .infinity)
                    }
                }
                .accessibilityLabel(String(localized: "Writing your summary"))
            }
        }
        .foregroundStyle(Color.brandNight)
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .reportCard(.brandYellow)
        .animation(.smooth(duration: 0.3), value: summary)
    }

    /// Two cards side by side, as GO's: the biggest share large on green,
    /// and the busiest day large on the page's own card.
    private func pairOfCards(_ report: MonthlyReport) -> some View {
        HStack(alignment: .top, spacing: 10) {
            if let top = report.groups.first {
                VStack(alignment: .leading, spacing: 4) {
                    ReportNumber(value: String(Int((top.share * 100).rounded())), unit: "%", size: 44)
                    Text(top.group.title)
                        .starhashFont(16, weight: .bold, relativeTo: .headline)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                    Spacer(minLength: 10)
                    Text("Of what went out, \(Money.formatWithCurrency(top.amount))")
                        .starhashFont(12, weight: .medium, relativeTo: .caption)
                        .opacity(0.75)
                }
                .foregroundStyle(Color.brandNight)
                .padding(18)
                .frame(maxWidth: .infinity, minHeight: 168, alignment: .topLeading)
                .reportCard(.brandGreen)
                .accessibilityElement(children: .combine)
            }
            if let weekday = report.busiestWeekday {
                VStack(alignment: .leading, spacing: 4) {
                    ReportNumber(value: calendar.shortStandaloneWeekdaySymbols[weekday - 1], size: 44)
                    Text("Busiest day")
                        .starhashFont(16, weight: .bold, relativeTo: .headline)
                        .foregroundStyle(Color.starhashPrimaryText)
                    Spacer(minLength: 10)
                    Text("\(Money.formatWithCurrency(report.purchases)) on airtime, bundles and bills")
                        .starhashFont(12, weight: .medium, relativeTo: .caption)
                        .foregroundStyle(Color.starhashSecondaryText)
                }
                .padding(18)
                .frame(maxWidth: .infinity, minHeight: 168, alignment: .topLeading)
                .starhashContainer(.starhashCard, in: RoundedRectangle(cornerRadius: StarHashMetrics.cardRadius, style: .continuous))
                .accessibilityElement(children: .combine)
            }
        }
    }

    // MARK: Lists

    /// A list as GO's "Today's Summary": a bold title, then rows of a large
    /// amount with what it was under it, dashed lines between.
    private func list(_ title: String, rows: [ReportRow]) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(title)
                .starhashFont(20, weight: .bold, relativeTo: .title3)
                .foregroundStyle(Color.starhashPrimaryText)
                .accessibilityAddTraits(.isHeader)
                .padding(.bottom, 6)
            ForEach(Array(rows.enumerated()), id: \.offset) { index, row in
                if index > 0 { ReportDivider() }
                row
            }
        }
    }

    private func groupRow(_ group: MonthlyReport.GroupTotal) -> ReportRow {
        ReportRow(
            amount: Money.format(group.amount),
            symbol: group.group.symbol,
            detail: group.group.title,
            trailing: "\(Int((group.share * 100).rounded()))%"
        )
    }

    private func recipientRow(_ total: MonthlyReport.RecipientTotal) -> ReportRow {
        ReportRow(
            amount: Money.format(total.amount),
            symbol: total.recipient.kind == .phone ? "person.fill" : "storefront.fill",
            detail: total.recipient.shownName,
            trailing: total.count == 1 ? String(localized: "1 payment") : String(localized: "\(total.count) payments"),
            action: total.recipient.isPayable ? { router.pay(total.recipient) } : nil
        )
    }

    // MARK: Since the start

    /// Everything spent since the first payment StarHash knows, large and
    /// quiet, as GO's "23,56,673 Steps since Feb 10".
    @ViewBuilder
    private var lifetime: some View {
        let spent = store.transactions.filter { $0.direction == .outgoing && $0.status != .failed }
        if let first = spent.map(\.date).min() {
            VStack(alignment: .leading, spacing: 2) {
                ReportNumber(value: Money.format(spent.reduce(0) { $0 + $1.amount }), unit: Money.currency, size: 46)
                    .foregroundStyle(Color.starhashTertiaryText)
                Text("Spent with StarHash since \(first.formatted(.dateTime.month(.abbreviated).day().year()))")
                    .starhashFont(12, weight: .medium, relativeTo: .caption)
                    .foregroundStyle(Color.starhashTertiaryText)
            }
            .accessibilityElement(children: .combine)
        }
    }

    // MARK: Workings

    /// What went out on each day of the month showing.
    private func dailySpending() -> [Int] {
        guard let interval = calendar.dateInterval(of: .month, for: month),
              let count = calendar.range(of: .day, in: .month, for: month)?.count else { return [] }
        var days = Array(repeating: 0, count: count)
        for t in store.transactions where t.direction == .outgoing && t.status != .failed && interval.contains(t.date) && t.date < interval.end {
            let day = calendar.component(.day, from: t.date) - 1
            if days.indices.contains(day) { days[day] += t.amount }
        }
        return days
    }

    /// "Fri 9", a day of the month showing.
    private func dayName(_ day: Int) -> String {
        guard let date = calendar.date(bySetting: .day, value: day, of: month) else { return String(day) }
        return date.formatted(.dateTime.weekday(.abbreviated).day())
    }

    private func monthName(_ date: Date, withYear: Bool = false) -> String {
        let sameYear = calendar.component(.year, from: date) == calendar.component(.year, from: .now)
        return date.formatted(withYear || !sameYear ? .dateTime.month(.wide).year() : .dateTime.month(.wide))
    }

    private func writeSummary(of report: MonthlyReport) async {
        guard !report.isEmpty else { return }
        let previous = monthName(calendar.date(byAdding: .month, value: -1, to: month) ?? month)
        let written = await ReportNarrator.summary(of: report, monthName: monthName(month), previousName: previous)
        guard !Task.isCancelled else { return }
        summary = written
    }
}

// MARK: - Pieces

/// A number in GO's display type: bold, drawn in tight, its unit small and
/// close after it on the same baseline ("1250ml", "20kcal").
struct ReportNumber: View {
    let value: String
    var unit: String?
    var size: CGFloat

    var body: some View {
        (Text(value)
            .font(.custom(Font.starhashFamily, size: size).weight(.bold))
            .tracking(-size * 0.045)
            + Text(unit.map { "\u{2009}" + $0 } ?? "")
            .font(.custom(Font.starhashFamily, size: max(size * 0.36, 11)).weight(.semibold))
            .tracking(0))
            .monospacedDigit()
            .lineLimit(1)
            .minimumScaleFactor(0.4)
            .dynamicTypeSize(...DynamicTypeSize.accessibility2)
    }
}

/// One of the three figures under the total: the number and its unit, a
/// tiny label under it.
private struct ReportStat: View {
    let value: String
    let unit: String?
    let label: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            ReportNumber(value: value, unit: unit, size: 28)
                .foregroundStyle(Color.starhashPrimaryText)
            Text(label)
                .starhashFont(12, weight: .medium, relativeTo: .caption)
                .foregroundStyle(Color.starhashSecondaryText)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }
}

/// A row of a report's list: the amount large, what it was under it with
/// its symbol, and a figure at the end. Tappable when it pays someone.
struct ReportRow: View {
    let amount: String
    let symbol: String
    let detail: String
    let trailing: String
    var action: (() -> Void)?

    var body: some View {
        Button {
            TapHaptic.play()
            action?()
        } label: {
            HStack(alignment: .center, spacing: 12) {
                VStack(alignment: .leading, spacing: 3) {
                    ReportNumber(value: amount, unit: Money.currency, size: 28)
                        .foregroundStyle(Color.starhashPrimaryText)
                    HStack(spacing: 5) {
                        Image(systemName: symbol)
                            .font(.system(size: 11, weight: .semibold))
                        Text(detail)
                            .starhashFont(13, weight: .medium, relativeTo: .footnote)
                            .lineLimit(1)
                    }
                    .foregroundStyle(Color.starhashSecondaryText)
                }
                Spacer(minLength: 8)
                Text(trailing)
                    .starhashFont(15, weight: .semibold, relativeTo: .subheadline, tracking: 0)
                    .foregroundStyle(Color.starhashSecondaryText)
                if action != nil {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Color.starhashTertiaryText)
                }
            }
            .padding(.vertical, 14)
            .contentShape(Rectangle())
        }
        .buttonStyle(PressScaleButtonStyle())
        .disabled(action == nil)
        .accessibilityElement(children: .combine)
    }
}

/// The dashed line between a report's rows, GO's 3pt on and 3pt off, in
/// the page's own quiet colour.
private struct ReportDivider: View {
    var body: some View {
        Line()
            .stroke(Color.starhashPrimaryText.opacity(0.22), style: StrokeStyle(lineWidth: 1, dash: [3, 3]))
            .frame(height: 1)
            .accessibilityHidden(true)
    }

    private struct Line: Shape {
        func path(in rect: CGRect) -> Path {
            var path = Path()
            path.move(to: CGPoint(x: rect.minX, y: rect.midY))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
            return path
        }
    }
}

private extension View {
    /// A report's bright card: a solid colour in either appearance, as
    /// GO's yellow, green and blue cards, with a container's dark words.
    func reportCard(_ fill: Color) -> some View {
        starhashContainerSurface()
            .background(fill, in: RoundedRectangle(cornerRadius: StarHashMetrics.cardRadius, style: .continuous))
    }
}
