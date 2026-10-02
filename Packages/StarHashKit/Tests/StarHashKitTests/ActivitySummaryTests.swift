import Foundation
import Testing
@testable import StarHashKit

@Suite("ActivitySummary")
struct ActivitySummaryTests {
    /// A Gregorian calendar in Kigali with weeks starting on Monday.
    static let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Africa/Kigali")!
        calendar.firstWeekday = 2
        calendar.locale = Locale(identifier: "en_GB")
        return calendar
    }()

    static let locale = Locale(identifier: "en_GB")

    /// Friday 2 October 2026, 14:00 in Kigali.
    static let now = date(2026, 10, 2, 14)

    static func date(_ year: Int, _ month: Int, _ day: Int, _ hour: Int = 12, _ minute: Int = 0) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour, minute: minute))!
    }

    static func tx(
        _ amount: Int,
        _ direction: Transaction.Direction = .outgoing,
        fee: Int? = nil,
        at date: Date,
        status: Transaction.Status = .confirmed,
        name: String? = nil,
        destination: String = "0788123456",
        reference: String? = nil
    ) -> Transaction {
        Transaction(
            direction: direction,
            counterparty: Recipient(name: name, destination: destination, kind: destination.count >= 10 ? .phone : .merchant),
            amount: amount, fee: fee, date: date, status: status, source: .app, reference: reference
        )
    }

    // MARK: Periods

    @Test func weekFollowsTheCalendarsFirstWeekday() throws {
        let monday = try #require(ActivityPeriod.week.interval(now: Self.now, calendar: Self.calendar))
        #expect(monday.start == Self.date(2026, 9, 28, 0))
        var sundayFirst = Self.calendar
        sundayFirst.firstWeekday = 1
        let sunday = try #require(ActivityPeriod.week.interval(now: Self.now, calendar: sundayFirst))
        #expect(sunday.start == Self.date(2026, 9, 27, 0))
    }

    @Test func allTimeHasNoInterval() {
        #expect(ActivityPeriod.allTime.interval(now: Self.now, calendar: Self.calendar) == nil)
    }

    @Test func filtersToThePeriod() {
        let items = [
            Self.tx(100, at: Self.date(2026, 10, 2, 9)),
            Self.tx(200, at: Self.date(2026, 9, 28, 0)),
            Self.tx(300, at: Self.date(2026, 9, 27, 23)),
        ]
        let week = ActivitySummary.transactions(items, in: .week, now: Self.now, calendar: Self.calendar)
        #expect(week.map(\.amount) == [100, 200])
        let today = ActivitySummary.transactions(items, in: .today, now: Self.now, calendar: Self.calendar)
        #expect(today.map(\.amount) == [100])
        #expect(ActivitySummary.transactions(items, in: .allTime, now: Self.now, calendar: Self.calendar).count == 3)
    }

    // MARK: Totals

    @Test func totalsSplitByDirectionAndSkipFailedAndCountOnlyConfirmedFees() {
        let totals = ActivitySummary.totals(of: [
            Self.tx(15_000, fee: 0, at: Self.now),
            Self.tx(700, fee: 20, at: Self.now),
            Self.tx(8_000, fee: 100, at: Self.now, status: .pending),
            Self.tx(35_000, .incoming, at: Self.now),
            Self.tx(50_000, fee: 250, at: Self.now, status: .failed),
        ])
        #expect(totals == ActivitySummary.Totals(spent: 23_700, received: 35_000, fees: 20, count: 4))
    }

    // MARK: Chart

    @Test func weekHasSevenBucketsStartingMonday() {
        let buckets = ActivitySummary.buckets(
            for: [
                Self.tx(1_000, at: Self.date(2026, 9, 28, 8)),
                Self.tx(2_500, at: Self.date(2026, 10, 2, 9)),
                Self.tx(500, at: Self.date(2026, 10, 2, 13)),
                Self.tx(9_000, .incoming, at: Self.date(2026, 10, 2, 10)),
                Self.tx(9_000, at: Self.date(2026, 10, 1), status: .failed),
            ],
            period: .week, now: Self.now, calendar: Self.calendar, locale: Self.locale
        )
        #expect(buckets.count == 7)
        #expect(buckets.first?.label == "Mon")
        #expect(buckets.map(\.total) == [1_000, 0, 0, 0, 3_000, 0, 0])
    }

    @Test func otherPeriodsHaveTheirResolution() {
        func count(_ period: ActivityPeriod) -> Int {
            ActivitySummary.buckets(for: [], period: period, now: Self.now, calendar: Self.calendar, locale: Self.locale).count
        }
        #expect(count(.today) == 6)
        #expect(count(.month) == 31)
        #expect(count(.year) == 12)
        #expect(count(.allTime) == ActivitySummary.minimumYears)
    }

    @Test func allTimeReachesBackToTheEarliestYear() {
        let buckets = ActivitySummary.buckets(
            for: [Self.tx(4_000, at: Self.date(2019, 5, 1))],
            period: .allTime, now: Self.now, calendar: Self.calendar, locale: Self.locale
        )
        #expect(buckets.first?.label == "2019")
        #expect(buckets.last?.label == "2026")
        #expect(buckets.first?.total == 4_000)
    }

    @Test func monthLabelsEverySeventhDay() {
        let buckets = ActivitySummary.buckets(for: [], period: .month, now: Self.now, calendar: Self.calendar, locale: Self.locale)
        #expect(buckets.filter(\.showsLabel).map(\.label) == ["1", "8", "15", "22", "29"])
    }

    @Test(arguments: [
        (0, [0, 5_000, 10_000, 15_000, 20_000]),
        (20_000, [0, 5_000, 10_000, 15_000, 20_000]),
        (76_480, [0, 20_000, 40_000, 60_000, 80_000]),
        (3, [0, 1, 2, 3]),
    ])
    func axisTicksAreRound(highest: Int, expected: [Int]) {
        #expect(ActivitySummary.axisTicks(for: highest) == expected)
    }

    // MARK: List

    @Test func groupsByDayNewestFirst() {
        let sections = ActivitySummary.groupedByDay([
            Self.tx(1, at: Self.date(2026, 10, 1, 9)),
            Self.tx(2, at: Self.date(2026, 10, 2, 8)),
            Self.tx(3, at: Self.date(2026, 10, 2, 13)),
        ], calendar: Self.calendar)
        #expect(sections.map(\.day) == [Self.date(2026, 10, 2, 0), Self.date(2026, 10, 1, 0)])
        #expect(sections.first?.transactions.map(\.amount) == [3, 2])
    }

    @Test func dayTitles() {
        func title(_ day: Date) -> String {
            ActivitySummary.dayTitle(for: day, now: Self.now, calendar: Self.calendar, locale: Self.locale)
        }
        #expect(title(Self.date(2026, 10, 2, 0)) == "Today")
        #expect(title(Self.date(2026, 10, 1, 0)) == "Yesterday")
        #expect(title(Self.date(2026, 9, 25, 0)) == "Fri 25 Sept" || title(Self.date(2026, 9, 25, 0)) == "Fri 25 Sep")
        #expect(title(Self.date(2025, 9, 25, 0)).contains("2025"))
    }

    // MARK: Search

    @Test func searchMatchesNameNumberAmountAndReference() {
        let items = [
            Self.tx(15_000, at: Self.now, name: "Pili-Pili Invest", destination: "020205", reference: "1203948571"),
            Self.tx(700, at: Self.now, name: "John Doe", destination: "0780123456"),
        ]
        #expect(ActivitySummary.search("pili", in: items).count == 1)
        #expect(ActivitySummary.search("john doe", in: items).map(\.amount) == [700])
        #expect(ActivitySummary.search("0780 123", in: items).map(\.amount) == [700])
        #expect(ActivitySummary.search("15,000", in: items).map(\.amount) == [15_000])
        #expect(ActivitySummary.search("15000", in: items).map(\.amount) == [15_000])
        #expect(ActivitySummary.search("39485", in: items).map(\.amount) == [15_000])
        #expect(ActivitySummary.search("nobody", in: items).isEmpty)
        #expect(ActivitySummary.search("   ", in: items).isEmpty)
    }
}
