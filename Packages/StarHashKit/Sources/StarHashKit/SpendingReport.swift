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

    /// The reference's Savings Potential: spending a little less on the
    /// category most spent on that is a choice (food, shopping, rides),
    /// never bills, school or savings.
    public struct Saving: Equatable, Sendable {
        public let category: TransactionCategory
        public let spent: Int
        /// The cut suggested, in percent.
        public let percent: Int
        /// What the cut would keep, in RWF.
        public let amount: Int
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
    public let highestDay: DayTotal?
    /// The day with the least spent of the days anything was; nil with
    /// fewer than two such days, when it would only repeat `highestDay`.
    public let lowestDay: DayTotal?
    public let saving: Saving?

    /// The share of a category's spending the saving suggests cutting.
    public static let savingPercent = 10
    /// Categories whose spending is a choice, so a cut is a fair thing to
    /// suggest.
    public static let flexibleCategories: Set<TransactionCategory> = [
        .restaurant, .groceries, .shopping, .transport, .gifts, .tv, .bundles, .airtime,
    ]

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

        let byDay = Dictionary(grouping: spending) { calendar.startOfDay(for: $0.date) }
            .map { DayTotal(day: $0.key, total: $0.value.reduce(0) { $0 + $1.amount }) }
        self.highestDay = byDay.max { $0.total != $1.total ? $0.total < $1.total : $0.day > $1.day }
        self.lowestDay = byDay.count < 2 ? nil : byDay.min { $0.total != $1.total ? $0.total < $1.total : $0.day < $1.day }

        self.saving = categories
            .first { Self.flexibleCategories.contains($0.category) }
            .flatMap { top in
                let amount = Int((Double(top.total) * Double(Self.savingPercent) / 100).rounded())
                return amount > 0 ? Saving(category: top.category, spent: top.total, percent: Self.savingPercent, amount: amount) : nil
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
    /// moment, such as an exported report.
    public func name(for anchor: Date, calendar: Calendar, locale: Locale = .current) -> String {
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
            let text = month.string(from: interval.start)
            return text.prefix(1).uppercased(with: locale) + text.dropFirst()
        default:
            formatter.dateTemplate = "dMMM"
            return formatter.string(from: interval.start, to: interval.end.addingTimeInterval(-1))
        }
    }

    /// The span written out under the Report's total: "1 – 31 Oct 2026".
    public func rangeText(for anchor: Date, calendar: Calendar, locale: Locale = .current) -> String? {
        guard let interval = interval(now: anchor, calendar: calendar) else { return nil }
        var calendar = calendar
        calendar.locale = locale
        let formatter = DateIntervalFormatter()
        formatter.calendar = calendar
        formatter.locale = locale
        formatter.timeZone = calendar.timeZone
        formatter.dateTemplate = "dMMMyyyy"
        return formatter.string(from: interval.start, to: interval.end.addingTimeInterval(-1))
    }
}

extension TransactionCategory {
    /// Its place in `allCases`, to break ties the same way every time.
    var order: Int { Self.allCases.firstIndex(of: self) ?? 0 }
}

extension SpendingReport.PaymentType {
    var order: Int { Self.allCases.firstIndex(of: self) ?? 0 }
}
