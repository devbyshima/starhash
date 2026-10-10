import Foundation

/// The span of time the Activity tab shows: its totals, its chart and its
/// list all keep to it.
public enum ActivityPeriod: String, CaseIterable, Identifiable, Sendable {
    case today
    case week
    case month
    case year
    case allTime = "all"

    public var id: Self { self }

    /// The period picker's title: String(localized: "This Week", bundle: .module).
    public var title: String {
        switch self {
        case .today: String(localized: "Today", bundle: .module)
        case .week: String(localized: "This Week", bundle: .module)
        case .month: String(localized: "This Month", bundle: .module)
        case .year: String(localized: "This Year", bundle: .module)
        case .allTime: String(localized: "All Time", bundle: .module)
        }
    }

    /// Over the summary card's total: String(localized: "Spent this week", bundle: .module).
    public var spentCaption: String {
        switch self {
        case .today: String(localized: "Spent today", bundle: .module)
        case .week: String(localized: "Spent this week", bundle: .module)
        case .month: String(localized: "Spent this month", bundle: .module)
        case .year: String(localized: "Spent this year", bundle: .module)
        case .allTime: String(localized: "Spent in total", bundle: .module)
        }
    }

    /// What an empty period says: "Nothing was paid or received this
    /// week."
    public var emptyMessage: String {
        switch self {
        case .today: String(localized: "Nothing was paid or received today.", bundle: .module)
        case .week: String(localized: "Nothing was paid or received this week.", bundle: .module)
        case .month: String(localized: "Nothing was paid or received this month.", bundle: .module)
        case .year: String(localized: "Nothing was paid or received this year.", bundle: .module)
        case .allTime: String(localized: "Nothing was paid or received yet.", bundle: .module)
        }
    }

    /// Ends "No transactions ..." when the period holds nothing.
    public var emptyPhrase: String {
        switch self {
        case .today: "today"
        case .week: "this week"
        case .month: "this month"
        case .year: "this year"
        case .allTime: "yet"
        }
    }

    /// The calendar span holding `now`, or nil for All Time. The week
    /// follows `calendar`'s first weekday, so it starts on Sunday or Monday
    /// as the user's region does.
    public func interval(now: Date, calendar: Calendar) -> DateInterval? {
        switch self {
        case .today: calendar.dateInterval(of: .day, for: now)
        case .week: calendar.dateInterval(of: .weekOfYear, for: now)
        case .month: calendar.dateInterval(of: .month, for: now)
        case .year: calendar.dateInterval(of: .year, for: now)
        case .allTime: nil
        }
    }
}

/// Everything the Activity tab works out from the transactions: the
/// period's totals, the chart's bars, the day groups of the list and
/// search. Pure functions, so they are tested without the app.
public enum ActivitySummary {
    // MARK: Totals

    public struct Totals: Equatable, Sendable {
        /// Money sent and merchant payments, fees not included.
        public var spent: Int
        public var received: Int
        /// The carrier's fees on what was sent.
        public var fees: Int
        public var count: Int

        public init(spent: Int = 0, received: Int = 0, fees: Int = 0, count: Int = 0) {
            self.spent = spent
            self.received = received
            self.fees = fees
            self.count = count
        }
    }

    /// The transactions dated inside `period`, in the order given.
    public static func transactions(
        _ transactions: [Transaction],
        in period: ActivityPeriod,
        now: Date,
        calendar: Calendar
    ) -> [Transaction] {
        guard let interval = period.interval(now: now, calendar: calendar) else { return transactions }
        return transactions.filter { interval.start <= $0.date && $0.date < interval.end }
    }

    /// Failed transactions moved no money, so they count for nothing.
    /// Pending ones do: they were dialled and most go through.
    public static func totals(of transactions: [Transaction]) -> Totals {
        var totals = Totals()
        for t in transactions where t.status != .failed {
            totals.count += 1
            switch t.direction {
            case .outgoing:
                totals.spent += t.amount
                // Only confirmed payments: by SMS (its fee), or by hand (the
                // fee from `Tariff`). A pending payment has none yet.
                if t.status == .confirmed { totals.fees += t.fee ?? 0 }
            case .incoming:
                totals.received += t.amount
            }
        }
        return totals
    }

    // MARK: Chart

    /// One bar of the chart: what was sent in one hour block, day, month
    /// or year.
    public struct Bucket: Identifiable, Hashable, Sendable {
        /// Position from the left, from 0; also the chart's x value, since
        /// labels repeat ("T" for Tuesday and Thursday).
        public let index: Int
        public let interval: DateInterval
        /// Under the bar: "Mon", "15", "Sep", "2026", "4 PM".
        public let label: String
        /// For when labels would collide: "M", "S".
        public let narrowLabel: String
        /// A month of days labels only every seventh.
        public let showsLabel: Bool
        public var total: Int

        public var id: Int { index }

        public init(index: Int, interval: DateInterval, label: String, narrowLabel: String? = nil, showsLabel: Bool, total: Int = 0) {
            self.index = index
            self.interval = interval
            self.label = label
            self.narrowLabel = narrowLabel ?? label
            self.showsLabel = showsLabel
            self.total = total
        }
    }

    /// All Time shows at least this many years, so a new install does not
    /// draw one lonely bar.
    public static let minimumYears = 4
    /// Today is split into blocks of this many hours.
    public static let hoursPerBlock = 4

    /// Outgoing totals per bar: hour blocks for Today, weekdays for This
    /// Week, days for This Month, months for This Year and years for All
    /// Time. Failed transactions and money received are left out.
    public static func buckets(
        for transactions: [Transaction],
        period: ActivityPeriod,
        now: Date,
        calendar: Calendar,
        locale: Locale = .current
    ) -> [Bucket] {
        let outgoing = transactions.filter { $0.direction == .outgoing && $0.status != .failed }
        var buckets = emptyBuckets(for: period, earliest: outgoing.map(\.date).min(), now: now, calendar: calendar, locale: locale)
        guard let first = buckets.first, let last = buckets.last else { return buckets }
        let span = DateInterval(start: first.interval.start, end: last.interval.end)
        for t in outgoing {
            guard span.contains(t.date),
                  let index = buckets.firstIndex(where: { $0.interval.start <= t.date && t.date < $0.interval.end })
            else { continue }
            buckets[index].total += t.amount
        }
        return buckets
    }

    /// Grid line amounts, from 0 up to a round number at or above the
    /// tallest bar: the smallest 1, 2, 2.5 or 5 step (times a power of ten)
    /// that needs at most four intervals. An empty chart still gets a scale.
    public static func axisTicks(for highest: Int) -> [Int] {
        guard highest > 0 else { return [0, 5_000, 10_000, 15_000, 20_000] }
        let maximumIntervals = 4.0
        let value = Double(highest)
        var magnitude = pow(10, floor(log10(value / maximumIntervals)))
        while true {
            for multiple in [1, 2, 2.5, 5] {
                let step = multiple * magnitude
                let intervals = (value / step - 1e-9).rounded(.up)
                if intervals <= maximumIntervals, step >= 1 {
                    return (0...Int(max(intervals, 1))).map { Int((Double($0) * step).rounded()) }
                }
            }
            magnitude *= 10
        }
    }

    /// The heading of the callout over a pressed bar: "8 AM – 12 PM",
    /// "Fri 2 Oct", "2 Oct", "October", "2026".
    public static func calloutTitle(of bucket: Bucket, period: ActivityPeriod, calendar: Calendar, locale: Locale = .current) -> String {
        let start = bucket.interval.start
        switch period {
        case .today:
            return "\(string(start, "j", calendar, locale)) \u{2013} \(string(bucket.interval.end, "j", calendar, locale))"
        case .week: return string(start, "EEEdMMM", calendar, locale)
        case .month: return string(start, "dMMM", calendar, locale)
        case .year: return string(start, "MMMM", calendar, locale)
        case .allTime: return string(start, "yyyy", calendar, locale)
        }
    }

    /// What VoiceOver says for a bar: "Friday 2 October", "October 2026".
    public static func spokenName(of bucket: Bucket, period: ActivityPeriod, calendar: Calendar, locale: Locale = .current) -> String {
        let start = bucket.interval.start
        switch period {
        case .today:
            return String(localized: "\(string(start, "j", calendar, locale)) to \(string(bucket.interval.end, "j", calendar, locale))", bundle: .module)
        case .week: return string(start, "EEEEdMMMM", calendar, locale)
        case .month: return string(start, "dMMMM", calendar, locale)
        case .year: return string(start, "MMMMyyyy", calendar, locale)
        case .allTime: return string(start, "yyyy", calendar, locale)
        }
    }

    static func emptyBuckets(for period: ActivityPeriod, earliest: Date?, now: Date, calendar: Calendar, locale: Locale) -> [Bucket] {
        var calendar = calendar
        calendar.locale = locale
        switch period {
        case .allTime:
            let current = calendar.component(.year, from: now)
            let earliestYear = earliest.map { calendar.component(.year, from: $0) } ?? current
            let firstYear = min(earliestYear, current - (minimumYears - 1))
            return (firstYear...current).enumerated().compactMap { index, year in
                guard let start = calendar.date(from: DateComponents(year: year, month: 1, day: 1)),
                      let interval = calendar.dateInterval(of: .year, for: start)
                else { return nil }
                return Bucket(index: index, interval: interval, label: String(year), showsLabel: true)
            }
        case .year:
            guard let year = calendar.dateInterval(of: .year, for: now) else { return [] }
            let symbols = calendar.shortStandaloneMonthSymbols
            let narrow = calendar.veryShortStandaloneMonthSymbols
            return subdivide(year, by: .month, calendar: calendar) { _, start in
                let month = calendar.component(.month, from: start) - 1
                return (symbols[month % symbols.count], narrow[month % narrow.count], true)
            }
        case .month:
            guard let month = calendar.dateInterval(of: .month, for: now) else { return [] }
            return subdivide(month, by: .day, calendar: calendar) { index, start in
                let day = String(calendar.component(.day, from: start))
                return (day, day, index % 7 == 0)
            }
        case .week:
            guard let week = calendar.dateInterval(of: .weekOfYear, for: now) else { return [] }
            let symbols = calendar.shortStandaloneWeekdaySymbols
            let narrow = calendar.veryShortStandaloneWeekdaySymbols
            return subdivide(week, by: .day, calendar: calendar) { _, start in
                let weekday = calendar.component(.weekday, from: start) - 1
                return (symbols[weekday % symbols.count], narrow[weekday % narrow.count], true)
            }
        case .today:
            guard let day = calendar.dateInterval(of: .day, for: now) else { return [] }
            // Wall-clock hours (0, 4, 8...), so a daylight saving day still
            // reads 12 AM, 4 AM, 8 AM.
            let starts = stride(from: 0, to: 24, by: hoursPerBlock).compactMap {
                calendar.date(bySettingHour: $0, minute: 0, second: 0, of: day.start)
            }
            return starts.enumerated().map { index, start in
                let end = index + 1 < starts.count ? starts[index + 1] : day.end
                return Bucket(index: index, interval: DateInterval(start: start, end: max(start, end)), label: string(start, "j", calendar, locale), showsLabel: true)
            }
        }
    }

    /// Steps through the calendar rather than adding seconds, so daylight
    /// saving days still line up.
    private static func subdivide(
        _ interval: DateInterval,
        by component: Calendar.Component,
        calendar: Calendar,
        label: (Int, Date) -> (label: String, narrow: String, shows: Bool)
    ) -> [Bucket] {
        var result: [Bucket] = []
        var start = interval.start
        while start < interval.end {
            guard let next = calendar.date(byAdding: component, value: 1, to: start), next > start else { break }
            let end = min(next, interval.end)
            let text = label(result.count, start)
            result.append(Bucket(index: result.count, interval: DateInterval(start: start, end: end), label: text.label, narrowLabel: text.narrow, showsLabel: text.shows))
            start = end
        }
        return result
    }

    // MARK: List

    /// One day of the list: its transactions, newest first.
    public struct DaySection: Identifiable, Hashable, Sendable {
        /// The start of the day.
        public let day: Date
        public let transactions: [Transaction]
        public var id: Date { day }
    }

    /// Groups transactions by calendar day, newest day first and newest
    /// first within each day, whatever order they come in.
    public static func groupedByDay(_ transactions: [Transaction], calendar: Calendar) -> [DaySection] {
        let groups = Dictionary(grouping: transactions) { calendar.startOfDay(for: $0.date) }
        return groups.keys.sorted(by: >).map { day in
            DaySection(day: day, transactions: groups[day, default: []].sorted { $0.date > $1.date })
        }
    }

    /// A day group's heading: String(localized: "Today", bundle: .module), String(localized: "Yesterday", bundle: .module), "Fri 2 Oct" (in the
    /// user's own date order), with the year once it is not this year's.
    public static func dayTitle(for day: Date, now: Date, calendar: Calendar, locale: Locale = .current) -> String {
        if calendar.isDate(day, inSameDayAs: now) { return String(localized: "Today", bundle: .module) }
        if let yesterday = calendar.date(byAdding: .day, value: -1, to: now), calendar.isDate(day, inSameDayAs: yesterday) {
            return String(localized: "Yesterday", bundle: .module)
        }
        let sameYear = calendar.component(.year, from: day) == calendar.component(.year, from: now)
        return string(day, sameYear ? "EEEdMMM" : "EEEdMMMyyyy", calendar, locale)
    }

    // MARK: Search

    /// The transactions matching `query` by name, number or merchant code,
    /// amount or reference, in the order given. Every word of the query has
    /// to match. Digits match however they are spaced or grouped, so
    /// "0788 123", "0788123" and "15,000" all find what they should.
    public static func search(_ query: String, in transactions: [Transaction]) -> [Transaction] {
        let words = query.lowercased().split(whereSeparator: \.isWhitespace).map(String.init)
        guard !words.isEmpty else { return [] }
        let digitsOnly = query.filter(\.isASCIIDigit)
        let isNumeric = !digitsOnly.isEmpty && query.allSatisfy { $0.isASCIIDigit || $0 == "," || $0 == "." || $0.isWhitespace || $0 == "+" }
        return transactions.filter { t in
            let numbers = [t.counterparty.destination, String(t.amount), t.reference ?? ""]
            if isNumeric, numbers.contains(where: { $0.contains(digitsOnly) }) { return true }
            let text = [
                t.counterparty.name ?? "",
                t.counterparty.formattedDestination,
                Money.format(t.amount),
                t.reference ?? "",
                t.category ?? "",
            ].joined(separator: " ").lowercased()
            return words.allSatisfy { text.contains($0) }
        }
    }

    // MARK: Formatting

    private static func string(_ date: Date, _ template: String, _ calendar: Calendar, _ locale: Locale) -> String {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.locale = locale
        formatter.timeZone = calendar.timeZone
        formatter.setLocalizedDateFormatFromTemplate(template)
        return formatter.string(from: date)
    }
}
