import Foundation

/// Everything the Report page shows for one week, month or year: what was
/// spent and how it compares with the period before, where it went (by
/// category, by kind of payment, the largest payments), the busiest and
/// quietest days, and one small saving to try. Worked out once, here, so
/// the page only lays it out and every number is tested.
///
/// "Spent" means what `ActivitySummary.totals` counts: money sent, merchant
/// payments and purchases, but not failed payments, money received or
/// money moved between the owner's own accounts. Fees are not spending.
public struct SpendingReport: Equatable, Sendable {
    /// How a payment left the wallet: paid to a shop, sent to a person, or
    /// bought from a carrier or a utility (airtime, a bundle, electricity).
    public enum PaymentType: String, CaseIterable, Identifiable, Sendable {
        case merchants
        case people
        case purchases

        public var id: Self { self }
    }

    public struct CategoryTotal: Identifiable, Equatable, Sendable {
        /// A payment with no category counts as `.other`.
        public let category: TransactionCategory
        public let total: Int
        public let count: Int
        /// Of everything spent in the report, 0...1.
        public let share: Double
        public var id: TransactionCategory { category }

        public init(category: TransactionCategory, total: Int, count: Int, share: Double) {
            self.category = category
            self.total = total
            self.count = count
            self.share = share
        }
    }

    public struct TypeTotal: Identifiable, Equatable, Sendable {
        public let type: PaymentType
        public let total: Int
        public let count: Int
        /// Of everything spent in the report, 0...1.
        public let share: Double
        public var id: PaymentType { type }
    }

    public struct DayTotal: Equatable, Sendable {
        /// The start of the day.
        public let day: Date
        public let total: Int
    }

    /// A day anything was spent: how much, in how many payments, and the
    /// category most of it went to.
    public struct DaySpend: Identifiable, Equatable, Sendable {
        /// The start of the day.
        public let day: Date
        public let total: Int
        public let count: Int
        public let category: TransactionCategory
        public var id: Date { day }

        public init(day: Date, total: Int, count: Int, category: TransactionCategory) {
            self.day = day
            self.total = total
            self.count = count
            self.category = category
        }
    }

    /// The one thing worth saying about the period, after the owner's
    /// reference ("You spent $380 more on takeout than usual"): measured
    /// against the owner's usual, the same span of up to three periods
    /// before that had any spending, averaged.
    public enum Insight: Equatable, Sendable {
        /// The category furthest over its usual: by how much, its usual,
        /// and how many of its payments fewer would bring it back.
        case more(category: TransactionCategory, extra: Int, usual: Int, fewerPayments: Int)
        /// Nothing over its usual, and the whole below it, by this much.
        case less(by: Int)
        /// No earlier period to compare with, or nothing stands out: the
        /// category most spent on and its share.
        case share(category: TransactionCategory, share: Double)
    }

    public let period: ActivityPeriod
    /// The whole week, month or year shown.
    public let interval: DateInterval
    /// The category the report is narrowed to, or nil for all of them.
    public let category: TransactionCategory?
    /// The period's transactions (narrowed to `category`), in the order given.
    public let transactions: [Transaction]
    public let totals: ActivitySummary.Totals
    /// Whether `interval` holds today.
    public let isCurrent: Bool
    /// Days in the period, and the days counted for the average: all of
    /// them once the period is over, those up to today while it runs.
    public let dayCount: Int
    public let elapsedDays: Int
    /// Spent per day over `elapsedDays`, rounded to the franc.
    public let averageDaily: Int
    /// What the period before spent over the same span: its first
    /// `elapsedDays` days while this one runs, all of it once this is over.
    public let previousSpent: Int
    /// Up or down on `previousSpent`, as a fraction (0.056 for +5.6%); nil
    /// when nothing was spent before, as there is nothing to compare with.
    public let change: Double?
    /// Spending by category, largest first.
    public let categories: [CategoryTotal]
    /// The three largest payments, largest first.
    public let topExpenses: [Transaction]
    /// Spending by kind of payment, largest first, kinds with none left out.
    public let types: [TypeTotal]
    /// Every day anything was spent, in order: the Report's calendar.
    public let days: [DaySpend]
    public let highestDay: DayTotal?
    /// The day with the least spent of the days anything was; nil with
    /// fewer than two such days, when it would only repeat `highestDay`.
    public let lowestDay: DayTotal?
    /// What the owner usually spends over the same span; nil with no
    /// earlier period that had any spending.
    public let usualSpent: Int?
    public let insight: Insight?

    /// How many periods before make the usual.
    public static let usualPeriods = 3
    /// The least over its usual a category must be to be named, in RWF.
    public static let notableExtra = 1_000

    /// The report for the `period` holding `anchor` (today's for This
    /// Month, any earlier one to look back), as it stands at `now`.
    public init(
        transactions all: [Transaction],
        period: ActivityPeriod,
        anchor: Date,
        now: Date,
        calendar: Calendar,
        category: TransactionCategory? = nil
    ) {
        let interval = period.interval(now: anchor, calendar: calendar)
            ?? DateInterval(start: all.map(\.date).min() ?? anchor, end: max(now, anchor))
        let narrowed = category.map { chosen in all.filter { ($0.knownCategory ?? .other) == chosen } } ?? all
        let inPeriod = narrowed.filter { interval.start <= $0.date && $0.date < interval.end }

        self.period = period
        self.interval = interval
        self.category = category
        self.transactions = inPeriod
        self.totals = ActivitySummary.totals(of: inPeriod)
        self.isCurrent = interval.contains(now) && now < interval.end

        let dayCount = Self.days(from: interval.start, to: interval.end, calendar: calendar)
        let elapsed: Int
        if isCurrent {
            let endOfToday = calendar.dateInterval(of: .day, for: now)?.end ?? now
            elapsed = Self.days(from: interval.start, to: min(endOfToday, interval.end), calendar: calendar)
        } else {
            elapsed = interval.end <= now ? dayCount : 0
        }
        self.dayCount = dayCount
        self.elapsedDays = elapsed
        self.averageDaily = elapsed > 0 ? Int((Double(totals.spent) / Double(elapsed)).rounded()) : 0

        // The same span of the period before: a month ten days in is set
        // against the first ten days of the month before, not all of it.
        var previous = 0
        if let before = period.interval(now: interval.start.addingTimeInterval(-1), calendar: calendar) {
            let end = isCurrent
                ? min(calendar.date(byAdding: .day, value: elapsed, to: before.start) ?? before.end, before.end)
                : before.end
            previous = Self.spending(in: narrowed)
                .filter { before.start <= $0.date && $0.date < end }
                .reduce(0) { $0 + $1.amount }
        }
        self.previousSpent = previous
        self.change = previous > 0 ? Double(totals.spent - previous) / Double(previous) : nil

        let spending = Self.spending(in: inPeriod)
        let spent = totals.spent

        let byCategory = Dictionary(grouping: spending) { $0.knownCategory ?? .other }
        self.categories = byCategory
            .map { category, items in
                let total = items.reduce(0) { $0 + $1.amount }
                return CategoryTotal(category: category, total: total, count: items.count, share: spent > 0 ? Double(total) / Double(spent) : 0)
            }
            .sorted { $0.total != $1.total ? $0.total > $1.total : $0.category.order < $1.category.order }

        self.topExpenses = Array(spending.sorted { $0.amount != $1.amount ? $0.amount > $1.amount : $0.date > $1.date }.prefix(3))

        let byType = Dictionary(grouping: spending, by: Self.type(of:))
        self.types = byType
            .map { type, items in
                let total = items.reduce(0) { $0 + $1.amount }
                return TypeTotal(type: type, total: total, count: items.count, share: spent > 0 ? Double(total) / Double(spent) : 0)
            }
            .sorted { $0.total != $1.total ? $0.total > $1.total : $0.type.order < $1.type.order }

        let spentByDay = Dictionary(grouping: spending) { calendar.startOfDay(for: $0.date) }
        self.days = spentByDay
            .map { day, items in
                let byCategory = Dictionary(grouping: items) { $0.knownCategory ?? .other }
                    .mapValues { $0.reduce(0) { $0 + $1.amount } }
                let top = byCategory.max { $0.value != $1.value ? $0.value < $1.value : $0.key.rawValue > $1.key.rawValue }?.key ?? .other
                return DaySpend(day: day, total: items.reduce(0) { $0 + $1.amount }, count: items.count, category: top)
            }
            .sorted { $0.day < $1.day }
        let byDay = days.map { DayTotal(day: $0.day, total: $0.total) }
        self.highestDay = byDay.max { $0.total != $1.total ? $0.total < $1.total : $0.day > $1.day }
        self.lowestDay = byDay.count < 2 ? nil : byDay.min { $0.total != $1.total ? $0.total < $1.total : $0.day < $1.day }

        // The usual: the same span of up to three periods before, those
        // with anything spent, averaged, so a month away does not halve it.
        var earlier: [[Transaction]] = []
        var cursor = interval.start
        for _ in 0..<Self.usualPeriods {
            guard let before = period.interval(now: cursor.addingTimeInterval(-1), calendar: calendar) else { break }
            cursor = before.start
            let end = isCurrent
                ? min(calendar.date(byAdding: .day, value: elapsed, to: before.start) ?? before.end, before.end)
                : before.end
            let items = Self.spending(in: narrowed).filter { before.start <= $0.date && $0.date < end }
            if !items.isEmpty { earlier.append(items) }
        }
        let usualSpent = earlier.isEmpty ? nil : Int((Double(earlier.joined().reduce(0) { $0 + $1.amount }) / Double(earlier.count)).rounded())
        self.usualSpent = usualSpent

        let topShare = categories.first.map { Insight.share(category: $0.category, share: $0.share) }
        if earlier.isEmpty {
            self.insight = topShare
        } else {
            var usualByCategory: [TransactionCategory: Double] = [:]
            for t in earlier.joined() {
                usualByCategory[t.knownCategory ?? .other, default: 0] += Double(t.amount) / Double(earlier.count)
            }
            let rising = categories
                .map { item in (item: item, usual: Int((usualByCategory[item.category] ?? 0).rounded())) }
                .filter { $0.item.total - $0.usual >= Self.notableExtra }
                .max { ($0.item.total - $0.usual, $1.item.category.order) < ($1.item.total - $1.usual, $0.item.category.order) }
            if let rising {
                let extra = rising.item.total - rising.usual
                let average = Double(rising.item.total) / Double(max(rising.item.count, 1))
                let fewer = min(max(Int((Double(extra) / average).rounded(.up)), 1), 9)
                self.insight = .more(category: rising.item.category, extra: extra, usual: rising.usual, fewerPayments: fewer)
            } else if let usualSpent, spent < usualSpent {
                self.insight = .less(by: usualSpent - spent)
            } else {
                self.insight = topShare
            }
        }
    }

    /// Whether there is anything to report: something spent or received.
    public var isEmpty: Bool { totals.count == 0 }

    /// The category most spent on, if any.
    public var topCategory: CategoryTotal? { categories.first }

    /// The kind of payment `transaction` was.
    public static func type(of transaction: Transaction) -> PaymentType {
        if transaction.isPurchase { return .purchases }
        return transaction.counterparty.kind == .merchant ? .merchants : .people
    }

    /// What counts as spent, as `ActivitySummary.totals` counts it.
    static func spending(in transactions: [Transaction]) -> [Transaction] {
        transactions.filter { $0.direction == .outgoing && $0.status != .failed && !$0.isOwnTransfer }
    }

    /// Whole calendar days from `start` to `end`, so a daylight saving day
    /// still counts as one.
    private static func days(from start: Date, to end: Date, calendar: Calendar) -> Int {
        guard end > start else { return 0 }
        let first = calendar.startOfDay(for: start)
        let last = calendar.startOfDay(for: end.addingTimeInterval(-1))
        return (calendar.dateComponents([.day], from: first, to: last).day ?? 0) + 1
    }
}

extension ActivityPeriod {
    /// A date inside the period `steps` before (negative) or after
    /// (positive) the one holding `anchor`: the Report's arrows step
    /// through weeks, months or years with it. All Time has no other.
    public func anchor(_ anchor: Date, movedBy steps: Int, calendar: Calendar) -> Date {
        let component: Calendar.Component
        switch self {
        case .today: component = .day
        case .week: component = .weekOfYear
        case .month: component = .month
        case .year: component = .year
        case .allTime: return anchor
        }
        return calendar.date(byAdding: component, value: steps, to: anchor) ?? anchor
    }

    /// The Report's heading for the period holding `anchor`: "This Month"
    /// for the one running at `now`, else its own name ("September 2026",
    /// "2025", "29 Sep – 5 Oct").
    public func title(for anchor: Date, now: Date, calendar: Calendar, locale: Locale = .current) -> String {
        guard let interval = interval(now: anchor, calendar: calendar) else { return title }
        if interval.contains(now) { return title }
        return name(for: anchor, calendar: calendar, locale: locale)
    }

    /// The period holding `anchor` by its own name, even the running one:
    /// "November 2026", "2026", "9 Nov – 15 Nov". For what outlives the
    /// moment, such as an exported report. `inSentence` writes a month as
    /// the middle of a sentence has it, small where its language writes it
    /// so ("en novembre 2026").
    public func name(for anchor: Date, calendar: Calendar, locale: Locale = .current, inSentence: Bool = false) -> String {
        guard let interval = interval(now: anchor, calendar: calendar) else { return title }
        var calendar = calendar
        calendar.locale = locale
        let formatter = DateIntervalFormatter()
        formatter.calendar = calendar
        formatter.locale = locale
        formatter.timeZone = calendar.timeZone
        switch self {
        case .year:
            return String(calendar.component(.year, from: interval.start))
        case .month:
            let month = DateFormatter()
            month.calendar = calendar
            month.locale = locale
            month.timeZone = calendar.timeZone
            month.setLocalizedDateFormatFromTemplate("MMMMyyyy")
            if inSentence {
                month.formattingContext = .middleOfSentence
                return month.string(from: interval.start)
            }
            let text = month.string(from: interval.start)
            return text.prefix(1).uppercased(with: locale) + text.dropFirst()
        default:
            formatter.dateTemplate = "dMMM"
            return formatter.string(from: interval.start, to: interval.end.addingTimeInterval(-1))
        }
    }
}

extension TransactionCategory {
    /// Its place in `allCases`, to break ties the same way every time.
    var order: Int { Self.allCases.firstIndex(of: self) ?? 0 }
}

extension SpendingReport.PaymentType {
    var order: Int { Self.allCases.firstIndex(of: self) ?? 0 }
}
