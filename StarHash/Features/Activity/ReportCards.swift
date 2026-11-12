import StarHashKit
import SwiftUI

// The Report's cards, after the owner's two references (an October report
// dashboard and an expense analytics page): each a titled card on the
// cards' fill, its figures on tiles of the page's own colour, and the
// categories in their own colours. Every card takes a `SpendingReport` and
// nothing from the environment, so the same views draw the page and the
// PDF that Export makes.

/// The Report's measurements, on a 402pt wide screen.
enum ReportLayout {
    static let cardSpacing: CGFloat = 14
    static let cardInset: CGFloat = 8
    static let tileRadius: CGFloat = 18
    static let tileSpacing: CGFloat = 6
    static let iconSize: CGFloat = 50
    /// Rows of Spending by Category shown before Show More.
    static let collapsedCategories = 4
}

// MARK: Pieces

/// A titled card: the title and a grey line under it, then `content`.
struct ReportCard<Content: View>: View {
    let title: LocalizedStringKey
    var subtitle: Text?
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .starhashFont(18, weight: .semibold, relativeTo: .headline)
                    .foregroundStyle(Color.starhashPrimaryText)
                    .accessibilityAddTraits(.isHeader)
                if let subtitle {
                    subtitle
                        .starhashFont(13, relativeTo: .footnote)
                        .foregroundStyle(Color.starhashSecondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(.horizontal, 8)
            .padding(.top, 8)
            content
        }
        .padding(ReportLayout.cardInset)
        .frame(maxWidth: .infinity, alignment: .leading)
        .starhashContainer(.starhashCard, in: RoundedRectangle(cornerRadius: StarHashMetrics.cardRadius, style: .continuous))
    }
}

extension View {
    /// One of a card's tiles: the page's colour, rounded inside the card.
    func reportTile() -> some View {
        background(Color.reportTile, in: RoundedRectangle(cornerRadius: ReportLayout.tileRadius, style: .continuous))
    }
}

/// A category's icon, white on a circle of its colours.
struct ReportCategoryIcon: View {
    let category: TransactionCategory
    var size: CGFloat = ReportLayout.iconSize

    var body: some View {
        let colours = Color.reportCategory(category)
        Image(symbol: category.symbol)
            .font(.system(size: size * 0.4, weight: .semibold))
            .foregroundStyle(Color.reportIconGlyph)
            .frame(width: size, height: size)
            .background(LinearGradient(colors: [colours.light, colours.deep], startPoint: .top, endPoint: .bottom), in: Circle())
            .shadow(color: .reportIconShadow, radius: size * 0.1, y: size * 0.06)
            .accessibilityHidden(true)
    }
}

/// A grey label over its value, as the reference's "Avg. Daily Spending".
private struct ReportFigure: View {
    let label: LocalizedStringKey
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(label)
                .starhashFont(13, relativeTo: .footnote)
                .foregroundStyle(Color.starhashSecondaryText)
            Text(value)
                .starhashFont(15, weight: .semibold, relativeTo: .subheadline)
                .foregroundStyle(Color.starhashPrimaryText)
                .lineLimit(2)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }
}

extension SpendingReport {
    /// "+5.6%", "-12.0%".
    static func changeText(_ change: Double) -> String {
        change.formatted(.percent.precision(.fractionLength(1)).sign(strategy: .always(includingZero: false)).locale(.starhash))
    }

    /// "70%".
    static func shareText(_ share: Double) -> String {
        share.formatted(.percent.precision(.fractionLength(0)).locale(.starhash))
    }

    /// "Nov 2".
    static func dayText(_ day: Date) -> String {
        day.formatted(.dateTime.month(.abbreviated).day().locale(.starhash))
    }
}

extension ActivityPeriod {
    /// The comparison under the Report's total: "vs. last month".
    var comparisonLabel: LocalizedStringKey {
        switch self {
        case .today: "vs. yesterday"
        case .week: "vs. last week"
        case .month: "vs. last month"
        case .year: "vs. last year"
        case .allTime: "vs. before"
        }
    }

    /// Under Spending Over Time: what one bar is.
    var barCaption: LocalizedStringKey {
        switch self {
        case .today: "Each bar is four hours."
        case .week, .month: "Each bar is a day. Press and hold one to see it."
        case .year: "Each bar is a month. Press and hold one to see it."
        case .allTime: "Each bar is a year."
        }
    }
}

// MARK: Total Spent

/// The reference's Total Amount Spent and Monthly Spending Overview in
/// one: the span, the total and how it compares with the period before,
/// then the average a day, the top category, what came in and the fees.
struct ReportOverviewCard: View {
    let report: SpendingReport
    let rangeText: String
    var rollsDigits = true

    var body: some View {
        ReportCard(title: "Total Spent", subtitle: Text(verbatim: subtitle)) {
            VStack(alignment: .leading, spacing: ReportLayout.tileSpacing) {
                VStack(alignment: .leading, spacing: 0) {
                    Text("Total spent")
                        .starhashFont(13, relativeTo: .footnote)
                        .foregroundStyle(Color.starhashSecondaryText)
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Text(Money.format(report.totals.spent))
                            .font(.starhashNumber(42, weight: .bold, relativeTo: .largeTitle))
                            .foregroundStyle(Color.starhashPrimaryText)
                            .contentTransition(rollsDigits ? .numericText(value: Double(report.totals.spent)) : .opacity)
                        Text(Money.currency)
                            .starhashFont(18, weight: .semibold, relativeTo: .title3)
                            .foregroundStyle(Color.starhashSecondaryText)
                    }
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                    .padding(.top, 4)
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(Money.formatWithCurrency(report.totals.spent))
                    SheetDivider()
                        .padding(.vertical, 12)
                    HStack {
                        Text(report.period.comparisonLabel)
                            .starhashFont(14, relativeTo: .subheadline)
                            .foregroundStyle(Color.starhashSecondaryText)
                        Spacer(minLength: 8)
                        if let change = report.change {
                            HStack(spacing: 3) {
                                Image(symbol: change >= 0 ? "arrow.up.right" : "arrow.down.left")
                                    .font(.system(size: 11, weight: .bold))
                                    .accessibilityHidden(true)
                                Text(SpendingReport.changeText(change))
                            }
                            .starhashFont(15, weight: .semibold, relativeTo: .subheadline)
                            .foregroundStyle(Color.starhashPrimaryText)
                        } else {
                            Text("Nothing spent then")
                                .starhashFont(14, relativeTo: .subheadline)
                                .foregroundStyle(Color.starhashSecondaryText)
                        }
                    }
                    .accessibilityElement(children: .combine)
                }
                .padding(16)
                .reportTile()

                Grid(horizontalSpacing: 12, verticalSpacing: 14) {
                    GridRow {
                        ReportFigure(label: "Average a day", value: Money.formatWithCurrency(report.averageDaily))
                        ReportFigure(label: "Top category", value: topCategoryText)
                    }
                    GridRow {
                        ReportFigure(label: "Received", value: Money.formatWithCurrency(report.totals.received))
                        ReportFigure(label: "Fees", value: Money.formatWithCurrency(report.totals.fees))
                    }
                }
                .padding(16)
                .reportTile()
            }
        }
    }

    /// The span and its days, and the category when the report is
    /// narrowed to one: "Nov 1 – 30, 2026 · day 12 of 30 · Restaurants".
    private var subtitle: String {
        [rangeText, daysText, report.category?.title].compactMap { $0 }.joined(separator: " · ")
    }

    private var daysText: String {
        report.isCurrent
            ? String(starhash: "day \(report.elapsedDays) of \(report.dayCount)")
            : String(starhash: "\(report.dayCount) days")
    }

    private var topCategoryText: String {
        guard let top = report.topCategory else { return String(starhash: "None yet") }
        return "\(top.category.title) (\(Money.format(top.total)))"
    }
}

// MARK: Spending Over Time

/// The chart the Report always had: what was sent each day or month.
struct ReportChartCard: View {
    let report: SpendingReport
    let buckets: [ActivitySummary.Bucket]
    let calendar: Calendar

    var body: some View {
        ReportCard(title: "Spending Over Time", subtitle: Text(report.period.barCaption)) {
            ActivitySpendingChart(buckets: buckets, period: report.period, calendar: calendar)
                .frame(height: 190)
                .padding(.horizontal, 14)
                .padding(.top, 20)
                .padding(.bottom, 14)
                .reportTile()
        }
    }
}

// MARK: Top Spending Categories

struct ReportTopCategoriesCard: View {
    let report: SpendingReport

    var body: some View {
        ReportCard(title: "Top Spending Categories", subtitle: Text("The categories you spent the most on.")) {
            HStack(alignment: .top, spacing: ReportLayout.tileSpacing) {
                ForEach(report.categories.prefix(3)) { item in
                    ReportIconTile(category: item.category, name: item.category.title, amount: item.total)
                }
            }
        }
    }
}

/// A category's icon over a name and an amount, on a tile.
private struct ReportIconTile: View {
    let category: TransactionCategory
    let name: String
    let amount: Int

    var body: some View {
        VStack(spacing: 0) {
            ReportCategoryIcon(category: category)
                .padding(.bottom, 12)
            Text(name)
                .starhashFont(14, weight: .semibold, relativeTo: .subheadline)
                .foregroundStyle(Color.starhashPrimaryText)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
            Text(Money.formatWithCurrency(amount))
                .font(.starhashNumber(14, relativeTo: .subheadline))
                .foregroundStyle(Color.starhashSecondaryText)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .padding(.top, 2)
        }
        .padding(.vertical, 18)
        .padding(.horizontal, 6)
        .frame(maxWidth: .infinity)
        .reportTile()
        .accessibilityElement(children: .ignore)
        .accessibilityLabel([name, Money.formatWithCurrency(amount)].joined(separator: ", "))
    }
}

// MARK: Top 3 Expenses

/// The three largest payments, each opening its page.
struct ReportTopExpensesCard: View {
    let report: SpendingReport
    /// Nil where nothing can open (the PDF).
    var onOpen: ((StarHashKit.Transaction) -> Void)?

    var body: some View {
        ReportCard(title: "Top 3 Expenses", subtitle: Text("Your largest payments in this report.")) {
            HStack(alignment: .top, spacing: ReportLayout.tileSpacing) {
                ForEach(report.topExpenses) { transaction in
                    let tile = ReportIconTile(
                        category: transaction.knownCategory ?? .other,
                        name: transaction.counterparty.shownName,
                        amount: transaction.amount
                    )
                    if let onOpen {
                        Button { onOpen(transaction) } label: { tile }
                            .buttonStyle(PressScaleButtonStyle())
                            .accessibilityHint(String(starhash: "Opens the payment"))
                    } else {
                        tile
                    }
                }
            }
        }
    }
}

// MARK: Spending by Category

/// The reference's Expense Breakdown by Category: the ring, then every
/// category with its share, four of them until Show More.
struct ReportBreakdownCard: View {
    let report: SpendingReport
    /// The PDF lists every category, with nothing to press.
    var showsEverything = false

    @State private var showsAll = false

    var body: some View {
        let all = report.categories
        let shown = showsAll || showsEverything ? all : Array(all.prefix(ReportLayout.collapsedCategories))
        ReportCard(title: "Spending by Category", subtitle: Text("Where your money went.")) {
            VStack(spacing: 0) {
                ReportRing(categories: all, total: report.totals.spent, animates: !showsEverything)
                    .frame(width: 210, height: 210)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 22)
                ForEach(shown) { item in
                    SheetDivider()
                    row(item)
                        .transition(.opacity)
                }
                if all.count > ReportLayout.collapsedCategories, !showsEverything {
                    SheetDivider()
                    Button {
                        withAnimation(.smooth(duration: 0.3)) { showsAll.toggle() }
                    } label: {
                        Text(showsAll ? "Show Less" : "Show More")
                            .starhashFont(15, weight: .semibold, relativeTo: .subheadline)
                            .foregroundStyle(Color.starhashAccentText)
                            .frame(maxWidth: .infinity, minHeight: 48)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.hapticPlain)
                }
            }
            .padding(.horizontal, 16)
            .reportTile()
        }
    }

    private func row(_ item: SpendingReport.CategoryTotal) -> some View {
        HStack(spacing: 10) {
            Circle()
                .fill(Color.reportCategory(item.category).deep)
                .frame(width: 10, height: 10)
            Text(item.category.title)
                .starhashFont(15, relativeTo: .subheadline)
                .foregroundStyle(Color.starhashPrimaryText)
                .lineLimit(1)
            Spacer(minLength: 8)
            Text(SpendingReport.shareText(item.share))
                .font(.starhashNumber(14, relativeTo: .subheadline))
                .foregroundStyle(Color.starhashSecondaryText)
            Text(Money.formatWithCurrency(item.total))
                .font(.starhashNumber(15, weight: .semibold, relativeTo: .subheadline))
                .foregroundStyle(Color.starhashPrimaryText)
                .lineLimit(1)
        }
        .frame(minHeight: 48)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(item.category.title)
        .accessibilityValue([Money.formatWithCurrency(item.total), SpendingReport.shareText(item.share)].joined(separator: ", "))
    }
}

/// The ring of categories, each slice its colour with its icon on it, the
/// total in the middle. Drawn by hand rather than with Charts' sectors, so
/// each icon sits on its slice's arc, as in the reference.
struct ReportRing: View {
    let categories: [SpendingReport.CategoryTotal]
    let total: Int
    var animates = true

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var progress: CGFloat = 0

    private static let lineWidth: CGFloat = 24
    /// Slices smaller than this carry no icon: it would cover them.
    private static let iconShare = 0.06

    private struct Slice: Identifiable {
        let category: TransactionCategory
        let start: Double
        let end: Double
        var id: TransactionCategory { category }
    }

    private var slices: [Slice] {
        let sum = Double(categories.reduce(0) { $0 + $1.total })
        guard sum > 0 else { return [] }
        var start = 0.0
        return categories.map { item in
            let end = start + Double(item.total) / sum
            defer { start = end }
            return Slice(category: item.category, start: start, end: end)
        }
    }

    var body: some View {
        let slices = slices
        let shown = animates ? progress : 1
        // A hair of page between slices, none for a ring of one.
        let gap = slices.count > 1 ? 0.004 : 0
        GeometryReader { geometry in
            let side = min(geometry.size.width, geometry.size.height)
            let radius = (side - Self.lineWidth) / 2
            let centre = CGPoint(x: geometry.size.width / 2, y: geometry.size.height / 2)
            ZStack {
                Circle()
                    .stroke(Color.starhashCard, lineWidth: Self.lineWidth)
                    .frame(width: radius * 2, height: radius * 2)
                ForEach(slices) { slice in
                    Circle()
                        .trim(from: (slice.start + gap) * shown, to: max((slice.end - gap) * shown, (slice.start + gap) * shown))
                        .stroke(Color.reportCategory(slice.category).deep, style: StrokeStyle(lineWidth: Self.lineWidth, lineCap: .butt))
                        .frame(width: radius * 2, height: radius * 2)
                        .rotationEffect(.degrees(-90))
                }
                ForEach(slices.filter { $0.end - $0.start >= Self.iconShare }) { slice in
                    let angle = Angle.degrees(-90 + 360 * (slice.start + slice.end) / 2)
                    Image(symbol: slice.category.symbol)
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(Color.reportIconGlyph)
                        .frame(width: 22, height: 22)
                        .background(Color.reportCategory(slice.category).deep, in: Circle())
                        .overlay(Circle().stroke(Color.reportTile, lineWidth: 2))
                        .position(x: centre.x + radius * cos(angle.radians), y: centre.y + radius * sin(angle.radians))
                        .opacity(shown >= 1 ? 1 : 0)
                }
                VStack(spacing: 2) {
                    Text("Spent")
                        .starhashFont(13, relativeTo: .footnote)
                        .foregroundStyle(Color.starhashSecondaryText)
                    Text(Money.format(total))
                        .font(.starhashNumber(24, weight: .bold, relativeTo: .title2))
                        .foregroundStyle(Color.starhashPrimaryText)
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                    Text(Money.currency)
                        .starhashFont(12, weight: .semibold, relativeTo: .caption)
                        .foregroundStyle(Color.starhashSecondaryText)
                }
                .frame(width: radius * 2 - Self.lineWidth - 16)
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(String(starhash: "Spending by category"))
        .accessibilityValue(categories.prefix(3).map { $0.category.title + " " + SpendingReport.shareText($0.share) }.joined(separator: ", "))
        .onAppear {
            guard animates, progress < 1 else { return }
            withAnimation(reduceMotion ? .easeInOut(duration: 0.2) : .smooth(duration: 0.8)) { progress = 1 }
        }
    }
}

// MARK: By Payment Type

/// The reference's Expenses by Payment Method, for MoMo: what went to
/// shops, to people, and on airtime, bundles and bills. Its bubbles grow
/// with their rank and carry their share.
struct ReportTypesCard: View {
    let report: SpendingReport

    var body: some View {
        ReportCard(title: "By Payment Type", subtitle: Text("Shops, people and what you bought.")) {
            HStack(alignment: .center, spacing: 12) {
                ReportBubbles(types: report.types)
                    .frame(width: 160, height: 160)
                VStack(alignment: .leading, spacing: 16) {
                    ForEach(report.types) { item in
                        HStack(alignment: .top, spacing: 8) {
                            Image(symbol: item.type.symbol)
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(Color.starhashSecondaryText)
                                .frame(width: 18)
                                .padding(.top, 1)
                                .accessibilityHidden(true)
                            VStack(alignment: .leading, spacing: 1) {
                                Text(item.type.title)
                                    .starhashFont(15, weight: .semibold, relativeTo: .subheadline)
                                    .foregroundStyle(Color.starhashPrimaryText)
                                Text(Money.formatWithCurrency(item.total))
                                    .font(.starhashNumber(13, relativeTo: .footnote))
                                    .foregroundStyle(Color.starhashSecondaryText)
                            }
                        }
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel(item.type.title)
                        .accessibilityValue([Money.formatWithCurrency(item.total), SpendingReport.shareText(item.share)].joined(separator: ", "))
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(14)
            .reportTile()
        }
    }
}

/// Up to three bubbles, largest top right, as the reference lays them.
private struct ReportBubbles: View {
    let types: [SpendingReport.TypeTotal]

    /// Each rank's diameter and centre in a 160pt square, worked out so
    /// none touches another.
    private static let places: [(size: CGFloat, x: CGFloat, y: CGFloat)] = [
        (92, 110, 56), (64, 50, 118), (52, 36, 44),
    ]

    var body: some View {
        ZStack {
            ForEach(Array(types.prefix(3).enumerated()), id: \.element.id) { rank, item in
                let place = Self.places[rank]
                let lead = rank == 0
                VStack(spacing: 2) {
                    Image(symbol: item.type.symbol)
                        .font(.system(size: lead ? 16 : 12, weight: .semibold))
                    Text(SpendingReport.shareText(item.share))
                        .font(.starhashNumber(lead ? 14 : 11, weight: .semibold, relativeTo: .caption))
                }
                .foregroundStyle(lead ? Color.reportIconGlyph : Color.reportBubbleOnWash)
                .frame(width: place.size, height: place.size)
                .background(lead ? Color.reportBubble : Color.reportBubbleWash, in: Circle())
                .position(x: place.x, y: place.y)
            }
        }
        .frame(width: 160, height: 160)
        .accessibilityHidden(true)
    }
}

extension SpendingReport.PaymentType {
    var title: String {
        switch self {
        case .merchants: String(starhash: "Shops")
        case .people: String(starhash: "People")
        case .purchases: String(starhash: "Bought")
        }
    }

    var symbol: String {
        switch self {
        case .merchants: "storefront.fill"
        case .people: "person.2.fill"
        case .purchases: "bag.fill"
        }
    }
}

// MARK: Key Metrics

struct ReportMetricsCard: View {
    let report: SpendingReport

    var body: some View {
        ReportCard(title: "Key Metrics", subtitle: Text("A quick look at this period.")) {
            VStack(spacing: ReportLayout.tileSpacing) {
                if let day = report.highestDay {
                    metric("chart.bar.fill", "Highest spending day", "\(SpendingReport.dayText(day.day)), \(Money.formatWithCurrency(day.total))")
                }
                if let top = report.topCategory {
                    metric("star.fill", "Most spent on", "\(top.category.title), \(Money.formatWithCurrency(top.total))")
                }
                metric("calendar", "Average a day", Money.formatWithCurrency(report.averageDaily))
                if let day = report.lowestDay {
                    metric("hourglass", "Lowest spending day", "\(SpendingReport.dayText(day.day)), \(Money.formatWithCurrency(day.total))")
                }
                metric("receipt.fill", "Payments", report.totals.count.formatted(.number.locale(.starhash)))
            }
        }
    }

    private func metric(_ symbol: String, _ label: LocalizedStringKey, _ value: String) -> some View {
        HStack(spacing: 14) {
            Image(symbol: symbol)
                .font(.system(size: 17, weight: .medium))
                .foregroundStyle(Color.starhashTertiaryText)
                .frame(width: 24)
                .accessibilityHidden(true)
            ReportFigure(label: label, value: value)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .reportTile()
    }
}

// MARK: Savings Potential

/// The reference's Savings Potential: one sentence, its figures and the
/// category on chips of the page's colour.
struct ReportSavingCard: View {
    let saving: SpendingReport.Saving

    var body: some View {
        let spent = ReportChipSentence.chip(Money.formatWithCurrency(saving.spent))
        let category = ReportChipSentence.chip(saving.category.title)
        let percent = ReportChipSentence.chip(saving.percent.formatted(.number.locale(.starhash)) + "%")
        let amount = ReportChipSentence.chip(Money.formatWithCurrency(saving.amount))
        ReportCard(title: "Savings Potential", subtitle: Text("A small change to try next time.")) {
            ReportChipSentence(
                text: String(starhash: "You spent \(spent) on \(category) in this report. A \(percent) smaller budget for it next time would leave you an extra \(amount)."),
                category: saving.category
            )
            .padding(.horizontal, 8)
            .padding(.bottom, 10)
        }
    }
}

/// Words that wrap as text does, with some of them on chips. The chips
/// are marked inside the translated sentence, so every language keeps its
/// own word order.
private struct ReportChipSentence: View {
    let text: String
    /// The chip naming this category also wears its icon.
    let category: TransactionCategory

    private static let open: Character = "\u{E000}"
    private static let close: Character = "\u{E001}"

    /// `value` marked as a chip, for the sentence's placeholders.
    static func chip(_ value: String) -> String { "\(open)\(value)\(close)" }

    private struct Token: Identifiable {
        let id: Int
        let text: String
        let isChip: Bool
        /// Punctuation straight after a chip, with no space before it.
        let gluesToPrevious: Bool
    }

    private var tokens: [Token] {
        var tokens: [Token] = []
        var buffer = ""
        var lastWasChip = false
        func flushWords() {
            let startsWithSpace = buffer.first?.isWhitespace ?? true
            let words = buffer.split(whereSeparator: \.isWhitespace)
            for (index, word) in words.enumerated() {
                let glues = index == 0 && lastWasChip && !startsWithSpace
                tokens.append(Token(id: tokens.count, text: String(word), isChip: false, gluesToPrevious: glues))
            }
            if !words.isEmpty { lastWasChip = false }
            buffer = ""
        }
        for character in text {
            switch character {
            case Self.open:
                flushWords()
            case Self.close:
                tokens.append(Token(id: tokens.count, text: buffer, isChip: true, gluesToPrevious: false))
                buffer = ""
                lastWasChip = true
            default:
                buffer.append(character)
            }
        }
        flushWords()
        return tokens
    }

    var body: some View {
        ReportFlowLayout(spacing: 5, lineSpacing: 8) {
            ForEach(tokens) { token in
                Group {
                    if token.isChip {
                        HStack(spacing: 5) {
                            if token.text == category.title {
                                ReportCategoryIcon(category: category, size: 20)
                            }
                            Text(token.text)
                                .foregroundStyle(Color.starhashPrimaryText)
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Color.reportTile, in: RoundedRectangle(cornerRadius: 9, style: .continuous))
                    } else {
                        Text(token.text)
                            .foregroundStyle(Color.starhashSecondaryText)
                    }
                }
                .starhashFont(20, weight: .medium, relativeTo: .title3)
                .layoutValue(key: GluesToPrevious.self, value: token.gluesToPrevious)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(text.filter { $0 != Self.open && $0 != Self.close })
    }
}

private struct GluesToPrevious: LayoutValueKey {
    static let defaultValue = false
}

/// Lays its views out left to right, wrapping to a new line as words do,
/// each line's views centred on one another.
private struct ReportFlowLayout: Layout {
    var spacing: CGFloat
    var lineSpacing: CGFloat

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        arrange(width: proposal.width ?? .infinity, subviews: subviews).size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let arrangement = arrange(width: bounds.width, subviews: subviews)
        for (index, point) in arrangement.points.enumerated() {
            subviews[index].place(at: CGPoint(x: bounds.minX + point.x, y: bounds.minY + point.y), proposal: .unspecified)
        }
    }

    private func arrange(width: CGFloat, subviews: Subviews) -> (size: CGSize, points: [CGPoint]) {
        let sizes = subviews.map { $0.sizeThatFits(.unspecified) }
        var lines: [[Int]] = [[]]
        var x: CGFloat = 0
        for (index, size) in sizes.enumerated() {
            let glued = subviews[index][GluesToPrevious.self]
            let gap = lines[lines.count - 1].isEmpty ? 0 : (glued ? 1 : spacing)
            if x + gap + size.width > width, !lines[lines.count - 1].isEmpty, !glued {
                lines.append([index])
                x = size.width
            } else {
                lines[lines.count - 1].append(index)
                x += gap + size.width
            }
        }
        var points = Array(repeating: CGPoint.zero, count: sizes.count)
        var y: CGFloat = 0
        var widest: CGFloat = 0
        for line in lines where !line.isEmpty {
            let height = line.map { sizes[$0].height }.max() ?? 0
            var x: CGFloat = 0
            for (position, index) in line.enumerated() {
                if position > 0 { x += subviews[index][GluesToPrevious.self] ? 1 : spacing }
                points[index] = CGPoint(x: x, y: y + (height - sizes[index].height) / 2)
                x += sizes[index].width
            }
            widest = max(widest, x)
            y += height + lineSpacing
        }
        return (CGSize(width: min(widest, width), height: max(y - lineSpacing, 0)), points)
    }
}
