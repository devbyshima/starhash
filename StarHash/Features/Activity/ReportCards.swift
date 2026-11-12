import StarHashKit
import SwiftUI

// The Report's pieces, after the owner's references (a "Check" summary, a
// money outlook of sentence cards, and the "Your mix" orbs): the summary
// first, straight on the page, then minimal cards, each a small grey label,
// one sentence that says what matters, and one picture of it. Every piece
// takes a `SpendingReport` and nothing from the environment, so the same
// views draw the page and the PDF that Export makes.

/// The Report's one type scale, after the owner's money outlook reference:
/// inside each card a small bold label, one large sentence, the rows and
/// figures of its picture, and a grey line of small print at its foot.
enum ReportType {
    case label, headline, body, bodyNumber, detail, detailNumber, footnote
    /// The two the owner kept large: the summary's sentence, and the total.
    case summary, total
    /// The summary a size and two smaller, for a sentence that would
    /// otherwise run past five lines.
    case summaryLong, summaryLongest

    var isSummary: Bool { [.summary, .summaryLong, .summaryLongest].contains(self) }

    /// The size each is drawn at, at the default text size.
    var size: CGFloat {
        switch self {
        case .label, .footnote: 15
        case .headline: 26
        case .body, .bodyNumber: 16
        case .detail, .detailNumber: 14
        case .summary: 28
        case .summaryLong: 26
        case .summaryLongest: 24
        case .total: 44
        }
    }
}

extension View {
    /// One of the Report's type sizes, following Dynamic Type.
    @ViewBuilder
    func reportFont(_ type: ReportType) -> some View {
        switch type {
        case .label: starhashFont(type.size, weight: .bold, relativeTo: .subheadline, tracking: 0)
        case .headline: starhashFont(type.size, weight: .medium, relativeTo: .title2, tracking: -0.3)
        case .body: starhashFont(type.size, weight: .medium, relativeTo: .callout)
        case .bodyNumber: font(.starhashNumber(type.size, weight: .semibold, relativeTo: .callout))
        case .detail, .footnote: starhashFont(type.size, relativeTo: .subheadline)
        case .detailNumber: font(.starhashNumber(type.size, relativeTo: .subheadline))
        case .summary, .summaryLong, .summaryLongest: starhashFont(type.size, weight: .medium, relativeTo: .title, tracking: -0.3)
        case .total: font(.starhashNumber(type.size, weight: .bold, relativeTo: .largeTitle))
        }
    }
}

/// The Report's measurements, on a 402pt wide screen.
enum ReportLayout {
    static let cardSpacing: CGFloat = 12
    /// Inside a card, from its sides, as the reference keeps its words.
    static let cardPadding: CGFloat = 20
    /// Rows of the categories shown before Show More.
    static let collapsedCategories = 4
}

// MARK: Pieces

/// A card after the money outlook reference, outlined as Settings' cards
/// are: its label inside at the top, small and bold, then what it says,
/// and its small print grey at the foot.
struct ReportCard<Content: View>: View {
    let label: LocalizedStringKey
    /// The grey line at the card's foot, as the reference's "ETFs drove
    /// most of the gains."
    var footnote: String?
    @ViewBuilder var content: Content

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: StarHashMetrics.outlinedCardRadius, style: .continuous)
        VStack(alignment: .leading, spacing: 0) {
            Text(label)
                .reportFont(.label)
                .foregroundStyle(Color.starhashPrimaryText)
                .contentTransition(.opacity)
                .accessibilityAddTraits(.isHeader)
                .padding(.bottom, 10)
            VStack(alignment: .leading, spacing: 10) {
                content
            }
            if let footnote {
                Text(footnote)
                    .reportFont(.footnote)
                    .foregroundStyle(Color.starhashSecondaryText)
                    .fixedSize(horizontal: false, vertical: true)
                    .contentTransition(.opacity)
                    .padding(.top, 14)
            }
        }
        .padding(.horizontal, ReportLayout.cardPadding)
        .padding(.top, 20)
        .padding(.bottom, 22)
        .frame(maxWidth: .infinity, alignment: .leading)
        .overlay(shape.strokeBorder(Color.starhashOutline, lineWidth: 1))
        .starhashContainerSurface()
    }
}

/// A card's sentence, large and set close, as the reference's: what
/// matters in the text colour, a name in its category's colour, and any
/// rest after it in grey.
struct ReportHeadline: View {
    let lead: String
    var tail: String?
    /// The category a name marked with `ReportSentence.coloured` takes
    /// its colour from.
    var category: TransactionCategory?

    var body: some View {
        ReportSentence(lead: lead, tail: tail ?? "", category: category, type: .headline)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// A row that can be pressed, as Activity's rows are: tinted at once
/// under the finger, the tint fading as it lifts.
struct ReportRowStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color.starhashRowHighlight)
                    .padding(.horizontal, -10)
                    .opacity(configuration.isPressed ? 1 : 0)
            }
            .animation(configuration.isPressed ? nil : .easeOut(duration: 0.2), value: configuration.isPressed)
            .starhashPressHaptic(configuration.isPressed, weight: .light)
    }
}

/// An orb giving under the finger; its choosing plays the haptic.
private struct ReportOrbPressStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.96 : 1)
            .opacity(configuration.isPressed && reduceMotion ? 0.85 : 1)
            .animation(.easeOut(duration: 0.16), value: configuration.isPressed)
    }
}

/// A category's icon, white on a circle of its colours.
struct ReportCategoryIcon: View {
    let category: TransactionCategory
    var size: CGFloat = 36

    var body: some View {
        let colours = Color.reportCategory(category)
        Image(symbol: category.symbol)
            .font(.system(size: size * 0.42, weight: .semibold))
            .foregroundStyle(Color.reportIconGlyph)
            .frame(width: size, height: size)
            .background(LinearGradient(colors: [colours.light, colours.deep], startPoint: .top, endPoint: .bottom), in: Circle())
            .shadow(color: .reportIconShadow, radius: size * 0.1, y: size * 0.06)
            .accessibilityHidden(true)
    }
}

extension SpendingReport {
    /// "70%".
    static func shareText(_ share: Double) -> String {
        share.formatted(.percent.precision(.fractionLength(0)).locale(.starhash))
    }

    /// "Nov 2".
    static func dayText(_ day: Date) -> String {
        day.formatted(.dateTime.month(.abbreviated).day().locale(.starhash))
    }
}

// MARK: Summary

/// The reference's "Check": one sentence about the period, the category
/// on an outlined chip in it, then what the owner could keep. Straight on
/// the page, the first thing the Report says.
struct ReportSummary: View {
    let insight: SpendingReport.Insight?
    /// The period the advice looks ahead by ("next week").
    let unit: ActivityPeriod
    /// Every category's total, for what a share comes to.
    let categories: [SpendingReport.CategoryTotal]
    /// "This month", "In October 2026": what the sentence opens with, as
    /// the header no longer says it.
    let period: String
    /// Shows the category named in the sentence; nil in the PDF.
    var onCategory: ((TransactionCategory) -> Void)?

    /// Five lines of the summary at its own size, its chip's among them.
    @ScaledMetric(relativeTo: .title) private var fiveLines: CGFloat = 5 * 36 + 8

    init(report: SpendingReport, period: String, onCategory: ((TransactionCategory) -> Void)? = nil) {
        self.init(insight: report.insight, unit: report.period, categories: report.categories, period: period, onCategory: onCategory)
    }

    init(
        insight: SpendingReport.Insight?,
        unit: ActivityPeriod,
        categories: [SpendingReport.CategoryTotal],
        period: String,
        onCategory: ((TransactionCategory) -> Void)? = nil
    ) {
        self.insight = insight
        self.unit = unit
        self.categories = categories
        self.period = period
        self.onCategory = onCategory
    }

    var body: some View {
        if let insight {
            let lead = lead(insight)
            let tail = tail(insight)
            VStack(alignment: .leading, spacing: 16) {
                // A new period or category fades one sentence into the
                // next rather than morphing its words in place.
                // At the owner's size when it fits in five lines; a long
                // sentence (a large sum, a long name, French) steps down
                // rather than filling the screen.
                ReportHeightLimit(height: fiveLines) {
                    ViewThatFits(in: .vertical) {
                        ForEach([ReportType.summary, .summaryLong, .summaryLongest], id: \.self) { type in
                            ReportSentence(lead: lead, tail: tail, category: category(insight), type: type, onCategory: onCategory)
                        }
                    }
                }
                .id(lead + tail)
                .transition(.opacity)
                    .accessibilityActions {
                        if let onCategory, let category = category(insight) {
                            Button(String(starhash: "Show \(category.title)")) { onCategory(category) }
                        }
                    }
                if let saving = saving(insight) {
                    Text(saving)
                        .reportFont(.body)
                        .foregroundStyle(Color.reportSaving)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
            }
            .padding(.horizontal, 4)
            .padding(.top, 8)
            .padding(.bottom, 16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .animation(.smooth(duration: 0.25), value: lead + tail)
        }
    }

    /// The sentence after the period: "This month, 56% of your spending…",
    /// its first letter small unless it is a figure.
    private func opened(_ sentence: String) -> String {
        guard let first = sentence.first, first.isLetter else { return period + ", " + sentence }
        return period + ", " + String(first).lowercased(with: .starhash) + sentence.dropFirst()
    }

    private func category(_ insight: SpendingReport.Insight) -> TransactionCategory? {
        switch insight {
        case .more(let category, _, _, _), .share(let category, _): category
        case .less: nil
        }
    }

    private func lead(_ insight: SpendingReport.Insight) -> String {
        let mark = String(ReportSentence.icon)
        return switch insight {
        case .more(_, let extra, _, _):
            opened(String(starhash: "You spent \(ReportSentence.amount(extra)) more on \(mark) than usual."))
        case .less(let by):
            opened(String(starhash: "You spent \(ReportSentence.amount(by)) less than usual."))
        case .share(let category, let share):
            opened(String(starhash: "\(SpendingReport.shareText(share)) of your spending went to \(ReportSentence.coloured(category.title))."))
        }
    }

    private func tail(_ insight: SpendingReport.Insight) -> String {
        switch insight {
        case .more(_, _, _, let fewer):
            switch unit {
            case .week, .today: String(starhash: "Skipping \(fewer) of them next week would get you back on track.")
            case .year, .allTime: String(starhash: "Skipping \(fewer) of them next year would get you back on track.")
            case .month: String(starhash: "Skipping \(fewer) of them next month would get you back on track.")
            }
        case .less:
            String(starhash: "You're on track.")
        case .share(let category, _):
            shareTail(categories.first { $0.category == category })
        }
    }

    /// "That's 91,480 RWF across 3 payments.": what the share is in money,
    /// and how many payments made it.
    private func shareTail(_ item: SpendingReport.CategoryTotal?) -> String {
        guard let item else { return "" }
        let amount = ReportSentence.amount(item.total)
        return item.count == 1
            ? String(starhash: "That's \(amount) in one payment.")
            : String(starhash: "That's \(amount) across \(item.count) payments.")
    }

    private func saving(_ insight: SpendingReport.Insight) -> String? {
        guard case .more(_, let extra, _, _) = insight else { return nil }
        return String(starhash: "Save up to \(Money.formatWithCurrency(extra))")
    }
}

/// Words wrapping as text does, set by the Report's own type: the
/// summary's, with the category's icon on an outlined chip where the
/// sentence names it, or a card's headline, set close as the reference
/// sets it. The chip is a mark inside the translated sentence, so every
/// language keeps its own word order. No word is left alone on the last
/// line.
struct ReportSentence: View {
    let lead: String
    var tail: String = ""
    var category: TransactionCategory?
    var type: ReportType = .summary
    var onCategory: ((TransactionCategory) -> Void)?

    /// Stands for the category's chip in a sentence.
    static let icon: Character = "\u{E002}"
    /// Round the category's name, which is written in its colour.
    static let colourOpen: Character = "\u{E003}"
    static let colourClose: Character = "\u{E004}"

    /// `name` marked to be written in the category's colour.
    static func coloured(_ name: String) -> String { "\(colourOpen)\(name)\(colourClose)" }

    /// "12,000 RWF", kept on one line: a figure never parts from its unit.
    static func amount(_ value: Int) -> String {
        Money.format(value) + "\u{00A0}" + Money.currency
    }

    private enum Tone { case primary, secondary, category }

    private enum Piece {
        case word(String, tone: Tone, glued: Bool)
        case chip
    }

    /// Only a plain space or a new line parts words: a no-break space
    /// (French figures, "56 %", an amount's unit) holds them together.
    private static func parts(_ character: Character) -> Bool {
        character == " " || character == "\n"
    }

    private var pieces: [Piece] {
        var pieces: [Piece] = []
        var inColour = false
        func words(_ text: String, tone: Tone) {
            for (index, part) in text.split(separator: Self.icon, omittingEmptySubsequences: false).enumerated() {
                if index > 0 { pieces.append(.chip) }
                let startsWithSpace = part.first.map(Self.parts) ?? true
                for (position, word) in part.split(whereSeparator: Self.parts).enumerated() {
                    // A word can hold the colour's edge ("Restaurants."), so
                    // it is cut where the colour changes, the pieces glued.
                    var glued = index > 0 && position == 0 && !startsWithSpace
                    var run = ""
                    func flush() {
                        guard !run.isEmpty else { return }
                        pieces.append(.word(run, tone: inColour ? .category : tone, glued: glued))
                        run = ""
                        glued = true
                    }
                    for character in word {
                        if character == Self.colourOpen || character == Self.colourClose {
                            flush()
                            inColour = character == Self.colourOpen
                        } else {
                            run.append(character)
                        }
                    }
                    flush()
                }
            }
        }
        words(lead, tone: .primary)
        words(tail, tone: .secondary)
        return pieces
    }

    /// Between words, and between lines: the summary as the "Check"
    /// reference sets it, a headline closer, as the money outlook's.
    private var spacing: (words: CGFloat, lines: CGFloat) {
        type.isSummary ? (type.size / 4, 0) : (6.5, -5)
    }

    var body: some View {
        ReportFlowLayout(spacing: spacing.words, lineSpacing: spacing.lines) {
            ForEach(Array(pieces.enumerated()), id: \.offset) { _, piece in
                switch piece {
                case .word(let word, let tone, let glued):
                    Text(word)
                        .reportFont(type)
                        .foregroundStyle(colour(tone))
                        .layoutValue(key: GluesToPrevious.self, value: glued)
                        .onTapGesture { if tone == .category { show() } }
                case .chip:
                    if let category {
                        Image(symbol: category.symbol, outline: true)
                            .font(.system(size: 19, weight: .medium))
                            .foregroundStyle(Color.reportCategoryText(category))
                            .frame(width: 44, height: 44)
                            .overlay(Circle().strokeBorder(Color.reportCategory(category).deep.opacity(0.45), lineWidth: 1.5))
                            .contentShape(Circle())
                            .onTapGesture { show() }
                    }
                }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(spoken)
    }

    /// The sentence as VoiceOver reads it, the category's name where its
    /// chip is.
    private var spoken: String {
        let whole = tail.isEmpty ? lead : lead + " " + tail
        return whole
            .replacingOccurrences(of: String(Self.icon), with: category?.title ?? "")
            .filter { $0 != Self.colourOpen && $0 != Self.colourClose }
    }

    private func show() {
        guard let category, let onCategory else { return }
        TapHaptic.play()
        onCategory(category)
    }

    private func colour(_ tone: Tone) -> Color {
        switch tone {
        case .primary: Color.starhashPrimaryText.color(in: environment)
        case .secondary: Color.starhashSecondaryText.color(in: environment)
        case .category: category.map(Color.reportCategoryText) ?? Color.starhashPrimaryText.color(in: environment)
        }
    }

    @Environment(\.self) private var environment
}

// MARK: Total Spent

/// What was spent, the total large under the card's label, then the
/// figures beside it as rows, as Categories lists its own, and how it
/// compares at the foot. A tap on a row brings its figure up large in the
/// total's place, the label and the foot saying what it is; a tap on it
/// again, or on the total, sets the total back.
struct ReportOverviewCard: View {
    let report: SpendingReport
    var rollsDigits = true

    @State private var shown: Figure = .spent

    enum Figure: CaseIterable {
        case spent, average, payments, received, fees
    }

    var body: some View {
        ReportCard(label: title(shown), footnote: line(shown)) {
            Button { choose(.spent) } label: { total }
                .buttonStyle(.hapticPlain)
                .disabled(shown == .spent)
            VStack(spacing: 0) {
                ForEach([Figure.average, .payments, .received, .fees], id: \.self) { figure in
                    Button { choose(shown == figure ? .spent : figure) } label: { row(figure) }
                        .buttonStyle(ReportRowStyle())
                }
            }
            .padding(.top, 2)
        }
    }

    private var total: some View {
        // The figure large, its unit half its size on its baseline.
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            Text(number(shown))
                .reportFont(.total)
                .foregroundStyle(Color.starhashPrimaryText)
                .contentTransition(rollsDigits ? .numericText(value: Double(amount(shown))) : .opacity)
            Text(unit(shown))
                .reportFont(.headline)
                .foregroundStyle(Color.starhashSecondaryText)
                .contentTransition(.opacity)
        }
        .lineLimit(1)
        .minimumScaleFactor(0.5)
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel([number(shown) + " " + unit(shown), line(shown)].compactMap { $0 }.joined(separator: ", "))
    }

    private func choose(_ figure: Figure) {
        withAnimation(.smooth(duration: 0.35)) { shown = figure }
    }

    private func amount(_ figure: Figure) -> Int {
        switch figure {
        case .spent: report.totals.spent
        case .average: report.averageDaily
        case .payments: report.totals.count
        case .received: report.totals.received
        case .fees: report.totals.fees
        }
    }

    private func number(_ figure: Figure) -> String {
        figure == .payments ? amount(figure).formatted(.number.locale(.starhash)) : Money.format(amount(figure))
    }

    private func unit(_ figure: Figure) -> String {
        guard figure == .payments else { return Money.currency }
        return amount(figure) == 1 ? String(starhash: "payment") : String(starhash: "payments")
    }

    /// At the card's foot: how the total compares, or what more there is
    /// to say of the figure the label names.
    private func line(_ figure: Figure) -> String? {
        switch figure {
        case .spent: comparison
        case .average:
            report.elapsedDays == 1
                ? String(starhash: "Over 1 day.")
                : String(starhash: "Over \(report.elapsedDays) days.")
        case .payments: String(starhash: "Made and received.")
        case .received: String(starhash: "Money that came in.")
        case .fees:
            report.totals.spent > 0
                ? String(starhash: "\((Double(report.totals.fees) / Double(report.totals.spent)).formatted(.percent.precision(.fractionLength(0...1)).locale(.starhash))) of what you spent.")
                : nil
        }
    }

    private func title(_ figure: Figure) -> LocalizedStringKey {
        switch figure {
        case .spent: "Total spent"
        case .average: "Average a day"
        case .payments: "Payments"
        case .received: "Received"
        case .fees: "Fees"
        }
    }

    /// "8% more than last month."; nothing with nothing before to compare.
    private var comparison: String? {
        guard let change = report.change else { return nil }
        let percent = abs(change).formatted(.percent.precision(.fractionLength(0)).locale(.starhash))
        return switch (change >= 0, report.period) {
        case (true, .week): String(starhash: "\(percent) more than last week.")
        case (false, .week): String(starhash: "\(percent) less than last week.")
        case (true, .year): String(starhash: "\(percent) more than last year.")
        case (false, .year): String(starhash: "\(percent) less than last year.")
        case (true, _): String(starhash: "\(percent) more than last month.")
        case (false, _): String(starhash: "\(percent) less than last month.")
        }
    }

    /// A figure's row; the one showing large reads in the text colour, the
    /// rest step back while it does.
    private func row(_ figure: Figure) -> some View {
        let quiet = shown != .spent && shown != figure
        return HStack(spacing: 10) {
            Text(title(figure))
                .reportFont(.body)
            Spacer(minLength: 8)
            Text(number(figure) + (figure == .payments ? "" : " " + Money.currency))
                .reportFont(.bodyNumber)
                .lineLimit(1)
        }
        .foregroundStyle(quiet ? Color.starhashSecondaryText : Color.starhashPrimaryText)
        .frame(minHeight: 40)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(shown == figure ? .isSelected : [])
    }
}

// MARK: Categories

/// The ring of categories under a sentence naming the largest, then every
/// category with its share, four of them until Show More.
struct ReportBreakdownCard: View {
    let report: SpendingReport
    /// The category chosen in the ring or its rows, shared with the
    /// summary, whose category leads here.
    @Binding var chosen: TransactionCategory?
    /// Narrows the whole report to one category; nil in the PDF.
    var onNarrow: ((TransactionCategory) -> Void)?
    /// The PDF lists every category, with nothing to press.
    var showsEverything = false

    @State private var showsAll = false

    var body: some View {
        let all = report.categories
        let shown = showsAll || showsEverything || chosen.map { c in !all.prefix(ReportLayout.collapsedCategories).contains { $0.category == c } } == true
            ? all : Array(all.prefix(ReportLayout.collapsedCategories))
        let lead = all.first { $0.category == chosen } ?? report.topCategory
        ReportCard(label: "Categories", footnote: lead.flatMap(footnote)) {
            if let lead {
                ReportHeadline(
                    lead: String(starhash: "\(SpendingReport.shareText(lead.share)) went to \(ReportSentence.coloured(lead.category.title))"),
                    category: lead.category
                )
                .id(lead.category)
                .transition(.opacity)
            }
            ReportRing(categories: all, total: report.totals.spent, chosen: $chosen, animates: !showsEverything)
                .frame(width: 196, height: 196)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 18)
            VStack(spacing: 0) {
                ForEach(shown) { item in
                    Button { choose(chosen == item.category ? nil : item.category) } label: { row(item) }
                        .buttonStyle(ReportRowStyle())
                        .disabled(showsEverything)
                        .contextMenu {
                            if let onNarrow {
                                Button { onNarrow(item.category) } label: {
                                    Label(String(starhash: "Show Only \(item.category.title)"), symbol: item.category.symbol)
                                }
                            }
                        }
                        .transition(.opacity)
                }
                if all.count > ReportLayout.collapsedCategories, !showsEverything {
                    Button {
                        withAnimation(.smooth(duration: 0.3)) { showsAll.toggle() }
                    } label: {
                        Text(showsAll ? "Show Less" : "Show More")
                            .reportFont(.body)
                            .foregroundStyle(Color.starhashAccentText)
                            .frame(maxWidth: .infinity, minHeight: 44)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.hapticPlain)
                }
            }
        }
    }

    private func choose(_ category: TransactionCategory?) {
        withAnimation(.easeOut(duration: 0.2)) { chosen = category }
    }

    /// What the chosen category came to, or, with none chosen, that one
    /// can be.
    private func footnote(_ lead: SpendingReport.CategoryTotal) -> String? {
        guard chosen != nil else { return showsEverything ? nil : String(starhash: "Tap one to see it.") }
        return lead.count == 1
            ? String(starhash: "1 payment, \(Money.formatWithCurrency(lead.total)).")
            : String(starhash: "\(lead.count) payments, \(Money.formatWithCurrency(lead.total)).")
    }

    private func row(_ item: SpendingReport.CategoryTotal) -> some View {
        HStack(spacing: 10) {
            Circle()
                .fill(Color.reportCategory(item.category).deep)
                .frame(width: 9, height: 9)
            Text(item.category.title)
                .reportFont(.body)
                .foregroundStyle(Color.starhashPrimaryText)
                .lineLimit(1)
            Spacer(minLength: 8)
            Text(SpendingReport.shareText(item.share))
                .reportFont(.detailNumber)
                .foregroundStyle(Color.starhashSecondaryText)
            Text(Money.formatWithCurrency(item.total))
                .reportFont(.bodyNumber)
                .foregroundStyle(Color.starhashPrimaryText)
                .lineLimit(1)
        }
        .frame(minHeight: 40)
        .contentShape(Rectangle())
        .opacity(chosen == nil || chosen == item.category ? 1 : 0.35)
        .accessibilityElement(children: .ignore)
        .accessibilityAddTraits(chosen == item.category ? .isSelected : [])
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
    @Binding var chosen: TransactionCategory?
    var animates = true

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var progress: CGFloat = 0

    private static let lineWidth: CGFloat = 20
    /// Slices smaller than this carry no icon: it would cover them.
    private static let iconShare = 0.06

    private struct Slice: Identifiable {
        let category: TransactionCategory
        let start: Double
        let end: Double
        var id: TransactionCategory { category }
    }

    private var chosenItem: SpendingReport.CategoryTotal? {
        categories.first { $0.category == chosen }
    }

    private func isQuiet(_ category: TransactionCategory) -> Bool {
        chosen != nil && chosen != category
    }

    private func choose(_ category: TransactionCategory?) {
        guard category != chosen else { return }
        withAnimation(.easeOut(duration: 0.2)) { chosen = category }
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
        // A hair of the page between slices, none for a ring of one.
        let gap = slices.count > 1 ? 0.004 : 0
        GeometryReader { geometry in
            let side = min(geometry.size.width, geometry.size.height)
            let radius = (side - Self.lineWidth) / 2
            let centre = CGPoint(x: geometry.size.width / 2, y: geometry.size.height / 2)
            ZStack {
                Circle()
                    .stroke(Color.starhashOutline, lineWidth: Self.lineWidth)
                    .frame(width: radius * 2, height: radius * 2)
                ForEach(slices) { slice in
                    Circle()
                        .trim(from: (slice.start + gap) * shown, to: max((slice.end - gap) * shown, (slice.start + gap) * shown))
                        .stroke(Color.reportCategory(slice.category).deep, style: StrokeStyle(lineWidth: Self.lineWidth, lineCap: .butt))
                        .frame(width: radius * 2, height: radius * 2)
                        .rotationEffect(.degrees(-90))
                        .opacity(isQuiet(slice.category) ? 0.3 : 1)
                }
                ForEach(slices.filter { $0.end - $0.start >= Self.iconShare }) { slice in
                    let angle = Angle.degrees(-90 + 360 * (slice.start + slice.end) / 2)
                    Image(symbol: slice.category.symbol)
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(Color.reportIconGlyph)
                        .frame(width: 20, height: 20)
                        .background(Color.reportCategory(slice.category).deep, in: Circle())
                        .overlay(Circle().stroke(Color.starhashBackground, lineWidth: 2))
                        .position(x: centre.x + radius * cos(angle.radians), y: centre.y + radius * sin(angle.radians))
                        .opacity(shown >= 1 ? (isQuiet(slice.category) ? 0.3 : 1) : 0)
                }
                VStack(spacing: 2) {
                    Text(Money.format(chosenItem?.total ?? total))
                        .contentTransition(.numericText(value: Double(chosenItem?.total ?? total)))
                        .reportFont(.headline)
                        .monospacedDigit()
                        .foregroundStyle(Color.starhashPrimaryText)
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                    Text(Money.currency)
                        .reportFont(.detail)
                        .foregroundStyle(Color.starhashSecondaryText)
                }
                .frame(width: radius * 2 - Self.lineWidth - 16)
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
            .contentShape(Rectangle())
            // A tap on the ring chooses the slice under it; anywhere else,
            // none.
            .onTapGesture { location in
                let x = location.x - centre.x
                let y = location.y - centre.y
                let reach = hypot(x, y)
                guard abs(reach - radius) <= Self.lineWidth else {
                    choose(nil)
                    return
                }
                var turn = (atan2(y, x) + .pi / 2) / (2 * .pi)
                if turn < 0 { turn += 1 }
                let slice = slices.first { $0.start <= turn && turn < $0.end }
                choose(slice?.category == chosen ? nil : slice?.category)
            }
        }
        .sensoryFeedback(.selection, trigger: chosen)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(String(starhash: "Spending by category"))
        .accessibilityValue(categories.prefix(3).map { $0.category.title + " " + SpendingReport.shareText($0.share) }.joined(separator: ", "))
        .onAppear {
            guard animates, progress < 1 else { return }
            withAnimation(reduceMotion ? .easeInOut(duration: 0.2) : .smooth(duration: 0.8)) { progress = 1 }
        }
    }
}

// MARK: Largest payments

/// The three largest payments under what they came to, as rows with each
/// recipient's tile as Activity draws it, each opening its page.
struct ReportLargestCard: View {
    let report: SpendingReport
    /// Nil where nothing can open (the PDF).
    var onOpen: ((StarHashKit.Transaction) -> Void)?

    var body: some View {
        let payments = report.topExpenses
        let sum = payments.reduce(0) { $0 + $1.amount }
        ReportCard(label: "Largest payments", footnote: footnote(sum)) {
            ReportHeadline(lead: payments.count == 1
                ? String(starhash: "Your largest payment was \(ReportSentence.amount(sum))")
                : String(starhash: "Your \(payments.count) largest came to \(ReportSentence.amount(sum))"))
            VStack(spacing: 0) {
                ForEach(report.topExpenses) { transaction in
                    if let onOpen {
                        Button { onOpen(transaction) } label: { row(transaction) }
                            .buttonStyle(ReportRowStyle())
                            .accessibilityHint(String(starhash: "Opens the payment"))
                    } else {
                        row(transaction)
                    }
                }
            }
        }
    }

    /// What share of the spending they were.
    private func footnote(_ sum: Int) -> String? {
        guard report.totals.spent > 0 else { return nil }
        let share = SpendingReport.shareText(min(Double(sum) / Double(report.totals.spent), 1))
        return String(starhash: "\(share) of everything you spent.")
    }

    private func row(_ transaction: StarHashKit.Transaction) -> some View {
        HStack(spacing: 12) {
            // Who it went to, as Activity's rows show them: a contact's
            // photo or initials, a shop, a silhouette, or the carrier.
            TransactionTile(transaction: transaction, size: ActivityLayout.tileSize)
            VStack(alignment: .leading, spacing: 1) {
                Text(transaction.counterparty.shownName)
                    .reportFont(.body)
                    .foregroundStyle(Color.starhashPrimaryText)
                    .lineLimit(1)
                Text(SpendingReport.dayText(transaction.date))
                    .reportFont(.detail)
                    .foregroundStyle(Color.starhashSecondaryText)
            }
            Spacer(minLength: 8)
            Text(Money.formatWithCurrency(transaction.amount))
                .reportFont(.bodyNumber)
                .foregroundStyle(Color.starhashPrimaryText)
                .lineLimit(1)
        }
        .padding(.vertical, 8)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }
}

// MARK: Payment types

/// The reference's "Your mix", for MoMo: what went to shops, to people and
/// on what was bought, as orbs of pale glass sized by their share, drifting
/// a little. A tap brings one to the middle, the others onto an orbit
/// round it, and the sentence above rolls to its figures; a tap on it, or
/// round it, sets them back.
struct ReportTypesCard: View {
    let report: SpendingReport
    /// Still, for the PDF.
    var isStill = false

    @State private var chosen: SpendingReport.PaymentType?

    var body: some View {
        let types = Array(report.types.prefix(3))
        ReportCard(label: "Payment types", footnote: footnote(types)) {
            headline(types)
                .contentTransition(.numericText())
                .animation(.smooth(duration: 0.35), value: chosen)
            ReportOrbs(types: types, chosen: $chosen, isStill: isStill)
                .frame(height: 260)
        }
        #if DEBUG
        .onAppear {
            if let value = DebugLaunch.value(after: "-reportOrb") { chosen = SpendingReport.PaymentType(rawValue: value) }
        }
        #endif
    }

    @ViewBuilder
    private func headline(_ types: [SpendingReport.TypeTotal]) -> some View {
        if let chosen, let item = types.first(where: { $0.type == chosen }) {
            ReportHeadline(lead: item.type.sentence(ReportSentence.amount(item.total)))
        } else if let top = types.first {
            ReportHeadline(lead: top.type.sentence(SpendingReport.shareText(top.share)))
        }
    }

    /// The chosen type's payments and share, or that one can be chosen.
    private func footnote(_ types: [SpendingReport.TypeTotal]) -> String? {
        guard let chosen, let item = types.first(where: { $0.type == chosen }) else {
            return isStill ? nil : String(starhash: "Tap one to see it.")
        }
        return item.count == 1
            ? String(starhash: "1 payment, \(SpendingReport.shareText(item.share)) of your spending.")
            : String(starhash: "\(item.count) payments, \(SpendingReport.shareText(item.share)) of your spending.")
    }
}

/// The orbs themselves, laid out by `chosen`: a cluster when none is
/// chosen, the chosen one large in the middle with the rest small on its
/// orbit otherwise.
private struct ReportOrbs: View {
    let types: [SpendingReport.TypeTotal]
    @Binding var chosen: SpendingReport.PaymentType?
    let isStill: Bool

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// The chosen orb's size, its companions', and their orbit.
    private static let chosenSize: CGFloat = 140
    private static let companionSize: CGFloat = 50
    private static let orbit: CGFloat = 112

    var body: some View {
        GeometryReader { geometry in
            let places = places(in: geometry.size)
            TimelineView(.animation(paused: isStill || reduceMotion)) { context in
                let time = context.date.timeIntervalSinceReferenceDate
                ZStack {
                    // Taps round the orbs set them back.
                    Color.clear
                        .contentShape(Rectangle())
                        .onTapGesture { choose(nil) }
                    if chosen != nil {
                        Circle()
                            .strokeBorder(Color.reportOrbit, style: StrokeStyle(lineWidth: 1, dash: [3, 5]))
                            .frame(width: Self.orbit * 2, height: Self.orbit * 2)
                            .position(x: geometry.size.width / 2, y: geometry.size.height / 2)
                            .transition(.opacity.combined(with: .scale(scale: 0.8)))
                    }
                    ForEach(Array(types.enumerated()), id: \.element.id) { index, item in
                        let place = places[item.type] ?? Place(centre: .zero, size: 0)
                        Button { choose(chosen == item.type ? nil : item.type) } label: {
                            ReportOrb(item: item, size: place.size, showsShare: place.size > 70)
                        }
                        .buttonStyle(ReportOrbPressStyle())
                        .position(place.centre)
                        .offset(drift(index, time))
                            .accessibilityElement(children: .ignore)
                            .accessibilityLabel(item.type.title)
                            .accessibilityValue([Money.formatWithCurrency(item.total), SpendingReport.shareText(item.share)].joined(separator: ", "))
                            .accessibilityAddTraits(chosen == item.type ? [.isButton, .isSelected] : .isButton)
                    }
                }
            }
        }
        .sensoryFeedback(.selection, trigger: chosen)
    }

    private func choose(_ type: SpendingReport.PaymentType?) {
        guard type != chosen else { return }
        withAnimation(reduceMotion ? .easeInOut(duration: 0.25) : .spring(response: 0.55, dampingFraction: 0.72)) {
            chosen = type
        }
    }

    /// A slow drift of a few points, each orb its own, as the reference's
    /// float; none when still.
    private func drift(_ index: Int, _ time: TimeInterval) -> CGSize {
        guard !isStill, !reduceMotion else { return .zero }
        let phase = Double(index) * 2.1
        return CGSize(width: sin(time * 0.7 + phase) * 3, height: cos(time * 0.55 + phase * 1.3) * 4)
    }

    private struct Place {
        let centre: CGPoint
        let size: CGFloat
    }

    private func places(in frame: CGSize) -> [SpendingReport.PaymentType: Place] {
        let middle = CGPoint(x: frame.width / 2, y: frame.height / 2)
        if let chosen {
            var places = [chosen: Place(centre: middle, size: Self.chosenSize)]
            // The others on the orbit, up to the left and up to the right,
            // as the reference's.
            let angles: [Double] = [-150, -30, 90]
            for (index, item) in types.filter({ $0.type != chosen }).enumerated() {
                let angle = angles[index % angles.count] * .pi / 180
                places[item.type] = Place(
                    centre: CGPoint(x: middle.x + Self.orbit * cos(angle), y: middle.y + Self.orbit * sin(angle)),
                    size: Self.companionSize
                )
            }
            return places
        }
        // A cluster: each orb as large as its share, the largest on the
        // left, the next above to its right, the third below, all touching
        // and the whole centred.
        let sizes = types.map { 64 + 92 * sqrt(max($0.share, 0)) }
        var centres: [CGPoint] = []
        for (index, size) in sizes.enumerated() {
            if index == 0 {
                centres.append(.zero)
            } else {
                let angle = (index == 1 ? -32.0 : 38.0) * .pi / 180
                let reach = sizes[0] / 2 + size / 2 + 6
                centres.append(CGPoint(x: reach * cos(angle), y: reach * sin(angle)))
            }
        }
        let left = zip(centres, sizes).map { $0.x - $1 / 2 }.min() ?? 0
        let right = zip(centres, sizes).map { $0.x + $1 / 2 }.max() ?? 0
        let top = zip(centres, sizes).map { $0.y - $1 / 2 }.min() ?? 0
        let bottom = zip(centres, sizes).map { $0.y + $1 / 2 }.max() ?? 0
        let shift = CGPoint(x: middle.x - (left + right) / 2, y: middle.y - (top + bottom) / 2)
        var places: [SpendingReport.PaymentType: Place] = [:]
        for (index, item) in types.enumerated() {
            places[item.type] = Place(centre: CGPoint(x: centres[index].x + shift.x, y: centres[index].y + shift.y), size: sizes[index])
        }
        return places
    }
}

/// One orb: pale glass lit from the top left, deepening to its colour,
/// with a soft glow of it beneath, its name and share on it.
private struct ReportOrb: View {
    let item: SpendingReport.TypeTotal
    let size: CGFloat
    let showsShare: Bool

    var body: some View {
        let colours = Color.reportType(item.type)
        ZStack {
            Circle()
                .fill(RadialGradient(
                    colors: [colours.light, colours.deep.opacity(0.85), colours.deep],
                    center: UnitPoint(x: 0.32, y: 0.26),
                    startRadius: 0,
                    endRadius: size * 0.8
                ))
            // The highlight a glass ball catches.
            Circle()
                .fill(RadialGradient(colors: [Color.reportIconGlyph.opacity(0.7), Color.reportIconGlyph.opacity(0)], center: UnitPoint(x: 0.34, y: 0.24), startRadius: 0, endRadius: size * 0.34))
            VStack(spacing: 0) {
                Text(item.type.title)
                    .starhashFont(max(10, size * 0.09), weight: .medium)
                if showsShare {
                    Text(SpendingReport.shareText(item.share))
                        .font(.starhashNumber(size * 0.17, weight: .bold))
                        .contentTransition(.numericText())
                }
            }
            .foregroundStyle(Color.reportOrbText)
            .lineLimit(1)
            .minimumScaleFactor(0.6)
            .padding(.horizontal, size * 0.12)
        }
        .frame(width: size, height: size)
        .shadow(color: colours.deep.opacity(0.35), radius: size * 0.12, y: size * 0.06)
        .contentShape(Circle())
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

    /// "94% went to shops", "153,780 RWF went to shops": a card's
    /// headline, with no full stop, as the reference's.
    func sentence(_ share: String) -> String {
        switch self {
        case .merchants: String(starhash: "\(share) went to shops")
        case .people: String(starhash: "\(share) went to people")
        case .purchases: String(starhash: "\(share) went on airtime, bundles and bills")
        }
    }
}

// MARK: By day

/// The period's days as the money outlook reference lays out its month:
/// each day's number, a small icon of the category most of it went to
/// under any day anything was spent, and the biggest day boxed. A tap on a
/// day moves the box to it and the sentence says what it came to; a tap on
/// it again sets them back. A year is twelve rows of dots, one a day,
/// darker the more was spent, the biggest ringed.
struct ReportChartCard: View {
    let report: SpendingReport
    let calendar: Calendar
    /// Nothing to press, for the PDF.
    var isStill = false

    @State private var chosen: Date?

    var body: some View {
        let chosenDay = report.days.first { $0.day == chosen }
        ReportCard(label: "By day", footnote: footnote(chosenDay)) {
            Group {
                if let chosenDay {
                    ReportHeadline(lead: String(starhash: "You spent \(ReportSentence.amount(chosenDay.total)) on \(SpendingReport.dayText(chosenDay.day))"))
                } else if let high = report.highestDay {
                    ReportHeadline(lead: String(starhash: "Your biggest day was \(SpendingReport.dayText(high.day))"))
                }
            }
            .contentTransition(.numericText())
            .animation(.smooth(duration: 0.3), value: chosen)
            ReportDays(report: report, calendar: calendar, chosen: $chosen, isStill: isStill)
                .padding(.top, 10)
        }
    }

    /// The chosen day's payments and what most went to; with none chosen,
    /// what the biggest day came to and the quietest.
    private func footnote(_ chosenDay: SpendingReport.DaySpend?) -> String? {
        if let chosenDay {
            return chosenDay.count == 1
                ? String(starhash: "1 payment, \(chosenDay.category.title).")
                : String(starhash: "\(chosenDay.count) payments, mostly \(chosenDay.category.title).")
        }
        guard let high = report.highestDay else { return nil }
        let most = Money.formatWithCurrency(high.total)
        guard let low = report.lowestDay else { return String(starhash: "\(most) that day.") }
        return String(starhash: "\(most) that day. The quietest was \(SpendingReport.dayText(low.day)), at \(Money.formatWithCurrency(low.total)).")
    }
}

/// The calendar itself: a week or a month as days under their weekdays'
/// letters, a year as rows of dots.
private struct ReportDays: View {
    let report: SpendingReport
    let calendar: Calendar
    @Binding var chosen: Date?
    let isStill: Bool

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Namespace private var box

    private var spent: [Date: SpendingReport.DaySpend] {
        Dictionary(uniqueKeysWithValues: report.days.map { ($0.day, $0) })
    }

    /// The day boxed: the one chosen, or else the biggest.
    private var boxed: Date? { chosen ?? report.highestDay?.day }

    var body: some View {
        Group {
            switch report.period {
            case .year, .allTime: yearDots
            case .today, .week, .month: monthGrid
            }
        }
        .sensoryFeedback(.selection, trigger: chosen)
    }

    private func choose(_ day: Date) {
        guard !isStill, spent[day] != nil else { return }
        withAnimation(reduceMotion ? .easeInOut(duration: 0.2) : .spring(response: 0.38, dampingFraction: 0.8)) {
            chosen = chosen == day ? nil : day
        }
    }

    /// Every day of the period, from its first.
    private var allDays: [Date] {
        var days: [Date] = []
        var day = calendar.startOfDay(for: report.interval.start)
        while day < report.interval.end {
            days.append(day)
            guard let next = calendar.date(byAdding: .day, value: 1, to: day) else { break }
            day = next
        }
        return days
    }

    /// A day still to come in the running period.
    private func isAhead(_ day: Date) -> Bool {
        guard report.isCurrent else { return false }
        let offset = calendar.dateComponents([.day], from: calendar.startOfDay(for: report.interval.start), to: day).day ?? 0
        return offset >= report.elapsedDays
    }

    // MARK: Week and month

    private var monthGrid: some View {
        let days = allDays
        var local = calendar
        local.locale = .starhash
        let letters = local.veryShortStandaloneWeekdaySymbols
        let first = calendar.firstWeekday - 1
        let ordered = Array(letters[first...] + letters[..<first])
        let lead = days.first.map { (calendar.component(.weekday, from: $0) - calendar.firstWeekday + 7) % 7 } ?? 0
        let columns = Array(repeating: GridItem(.flexible(), spacing: 0), count: 7)
        return VStack(spacing: 10) {
            LazyVGrid(columns: columns, spacing: 0) {
                ForEach(Array(ordered.enumerated()), id: \.offset) { _, letter in
                    Text(letter)
                        .reportFont(.detail)
                        .foregroundStyle(Color.starhashSecondaryText)
                        .accessibilityHidden(true)
                }
            }
            LazyVGrid(columns: columns, spacing: 6) {
                ForEach(0..<lead, id: \.self) { _ in Color.clear.frame(height: 1) }
                ForEach(days, id: \.self) { day in
                    dayCell(day)
                }
            }
        }
    }

    private func dayCell(_ day: Date) -> some View {
        let spend = spent[day]
        let ahead = isAhead(day)
        return Button { choose(day) } label: {
            VStack(spacing: 4) {
                Text(day.formatted(.dateTime.day().locale(.starhash)))
                    .font(.starhashNumber(19, relativeTo: .title3))
                    .foregroundStyle(spend != nil ? Color.starhashPrimaryText : Color.starhashSecondaryText)
                    .opacity(ahead ? 0.45 : 1)
                    .frame(width: 38, height: 38)
                    .background {
                        if boxed == day {
                            RoundedRectangle(cornerRadius: 11, style: .continuous)
                                .strokeBorder(Color.starhashPrimaryText, lineWidth: 1.5)
                                .matchedGeometryEffect(id: "box", in: box)
                        }
                    }
                Group {
                    if let spend {
                        ReportCategoryIcon(category: spend.category, size: 18)
                    } else {
                        Color.clear
                    }
                }
                .frame(width: 18, height: 18)
            }
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(ReportOrbPressStyle())
        .disabled(spend == nil || isStill)
        .accessibilityLabel(dayLabel(day, spend))
        .accessibilityAddTraits(boxed == day ? .isSelected : [])
    }

    private func dayLabel(_ day: Date, _ spend: SpendingReport.DaySpend?) -> String {
        let name = day.formatted(.dateTime.weekday(.wide).month(.wide).day().locale(.starhash))
        guard let spend else { return name }
        return name + ", " + Money.formatWithCurrency(spend.total) + ", " + spend.category.title
    }

    // MARK: Year

    /// Twelve rows, one a month, a dot a day, darker the more was spent.
    private var yearDots: some View {
        let days = allDays
        let months = Dictionary(grouping: days) { calendar.dateInterval(of: .month, for: $0)?.start ?? $0 }
            .sorted { $0.key < $1.key }
        let most = Double(report.highestDay?.total ?? 1)
        return GeometryReader { geometry in
            let labelWidth: CGFloat = 34
            let cell = (geometry.size.width - labelWidth) / 31
            let dot = max(cell - 2.5, 3)
            VStack(alignment: .leading, spacing: 7) {
                ForEach(months, id: \.key) { month, monthDays in
                    HStack(spacing: 0) {
                        Text(month.formatted(.dateTime.month(.abbreviated).locale(.starhash)))
                            .reportFont(.detail)
                            .foregroundStyle(Color.starhashSecondaryText)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                            .frame(width: labelWidth, alignment: .leading)
                        HStack(spacing: 0) {
                            ForEach(monthDays, id: \.self) { day in
                                yearDot(day, size: dot, most: most)
                                    .frame(width: cell, height: cell)
                            }
                        }
                        .contentShape(Rectangle())
                        .onTapGesture { location in
                            let index = Int(location.x / cell)
                            if monthDays.indices.contains(index) { choose(monthDays[index]) }
                        }
                    }
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(month.formatted(.dateTime.month(.wide).locale(.starhash)))
                    .accessibilityValue(Money.formatWithCurrency(monthDays.compactMap { spent[$0]?.total }.reduce(0, +)))
                }
            }
        }
        .frame(height: 12 * 19)
    }

    private func yearDot(_ day: Date, size: CGFloat, most: Double) -> some View {
        let spend = spent[day]
        let strength = spend.map { 0.22 + 0.78 * sqrt(Double($0.total) / most) } ?? 0
        return Circle()
            .fill(spend == nil ? AnyShapeStyle(Color.starhashOutline) : AnyShapeStyle(Color.starhashPrimaryText.opacity(strength)))
            .opacity(isAhead(day) ? 0.45 : 1)
            .frame(width: size, height: size)
            .overlay {
                if boxed == day {
                    Circle()
                        .strokeBorder(Color.starhashPrimaryText, lineWidth: 1.5)
                        .padding(-3.5)
                        .matchedGeometryEffect(id: "box", in: box)
                }
            }
    }
}

// MARK: Flow layout

/// Offers its view `height` to fit in, however tall the page, and takes
/// the size the view then wants: what lets `ViewThatFits` choose by
/// height inside a scroll view, which offers no height of its own.
struct ReportHeightLimit: Layout {
    var height: CGFloat

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        subviews.first?.sizeThatFits(ProposedViewSize(width: proposal.width, height: height)) ?? .zero
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        subviews.first?.place(at: bounds.origin, proposal: ProposedViewSize(width: bounds.width, height: height))
    }
}

struct GluesToPrevious: LayoutValueKey {
    static let defaultValue = false
}

/// Lays its views out left to right, wrapping to a new line as words do,
/// each line's views centred on one another. Views glued to the one before
/// travel with it, and the last line never holds one word alone: the word
/// before comes down to keep it company, as a typesetter would.
struct ReportFlowLayout: Layout {
    var spacing: CGFloat
    var lineSpacing: CGFloat

    /// Between views glued together: a hair, as between a word and its
    /// stop.
    private static let glue: CGFloat = 1

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        arrange(width: proposal.width ?? .infinity, subviews: subviews).size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let arrangement = arrange(width: bounds.width, subviews: subviews)
        for (index, point) in arrangement.points.enumerated() {
            subviews[index].place(
                at: CGPoint(x: bounds.minX + point.x, y: bounds.minY + point.y),
                proposal: ProposedViewSize(arrangement.sizes[index])
            )
        }
    }

    private func arrange(width: CGFloat, subviews: Subviews) -> (size: CGSize, points: [CGPoint], sizes: [CGSize]) {
        // A word wider than the line, at the largest text sizes, wraps
        // within itself rather than running off.
        let sizes = subviews.map { $0.sizeThatFits(ProposedViewSize(width: width.isFinite ? width : nil, height: nil)) }
        var groups: [[Int]] = []
        for index in sizes.indices {
            if subviews[index][GluesToPrevious.self], !groups.isEmpty {
                groups[groups.count - 1].append(index)
            } else {
                groups.append([index])
            }
        }
        func span(_ group: [Int]) -> CGFloat {
            group.reduce(0) { $0 + sizes[$1].width } + CGFloat(group.count - 1) * Self.glue
        }
        func span(of line: [[Int]]) -> CGFloat {
            line.reduce(0) { $0 + span($1) } + CGFloat(max(line.count - 1, 0)) * spacing
        }

        var lines: [[[Int]]] = [[]]
        for group in groups {
            let line = lines[lines.count - 1]
            if !line.isEmpty, span(of: line) + spacing + span(group) > width {
                lines.append([group])
            } else {
                lines[lines.count - 1].append(group)
            }
        }
        // No word alone on the last line.
        if lines.count > 1, lines[lines.count - 1].count == 1, lines[lines.count - 2].count > 2,
           let moved = lines[lines.count - 2].last,
           span(of: [moved] + lines[lines.count - 1]) <= width {
            lines[lines.count - 2].removeLast()
            lines[lines.count - 1].insert(moved, at: 0)
        }

        var points = Array(repeating: CGPoint.zero, count: sizes.count)
        var y: CGFloat = 0
        var widest: CGFloat = 0
        for line in lines where !line.isEmpty {
            let members = line.flatMap { $0 }
            let height = members.map { sizes[$0].height }.max() ?? 0
            var x: CGFloat = 0
            for (position, group) in line.enumerated() {
                if position > 0 { x += spacing }
                for (offset, index) in group.enumerated() {
                    if offset > 0 { x += Self.glue }
                    points[index] = CGPoint(x: x, y: y + (height - sizes[index].height) / 2)
                    x += sizes[index].width
                }
            }
            widest = max(widest, x)
            y += height + lineSpacing
        }
        return (CGSize(width: min(widest, width), height: max(y - lineSpacing, 0)), points, sizes)
    }
}
