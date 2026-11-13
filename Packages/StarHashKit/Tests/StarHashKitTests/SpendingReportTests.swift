import Foundation
import Testing
@testable import StarHashKit

@Suite("SpendingReport")
struct SpendingReportTests {
    static let calendar = ActivitySummaryTests.calendar
    static let locale = ActivitySummaryTests.locale
    static func date(_ y: Int, _ m: Int, _ d: Int, _ h: Int = 12) -> Date { ActivitySummaryTests.date(y, m, d, h) }

    /// Tuesday 10 November 2026, 15:00 in Kigali.
    static let now = date(2026, 11, 10, 15)

    static func tx(
        _ amount: Int,
        on date: Date,
        _ direction: Transaction.Direction = .outgoing,
        status: Transaction.Status = .confirmed,
        name: String = "Simba",
        merchant: Bool = true,
        category: TransactionCategory? = nil
    ) -> Transaction {
        Transaction(
            direction: direction,
            counterparty: Recipient(name: name, destination: merchant ? "123456" : "0788123456", kind: merchant ? .merchant : .phone),
            amount: amount, date: date, status: status, source: .app, category: category?.rawValue
        )
    }

    static func report(_ items: [Transaction], _ period: ActivityPeriod = .month, anchor: Date = now, category: TransactionCategory? = nil) -> SpendingReport {
        SpendingReport(transactions: items, period: period, anchor: anchor, now: now, calendar: calendar, category: category)
    }

    // MARK: Totals and days

    @Test func averagesOverTheDaysSoFarWhileThePeriodRuns() {
        let report = Self.report([Self.tx(10_000, on: Self.date(2026, 11, 2)), Self.tx(5_000, on: Self.date(2026, 11, 9))])
        #expect(report.isCurrent)
        #expect(report.dayCount == 30)
        #expect(report.elapsedDays == 10)
        #expect(report.totals.spent == 15_000)
        #expect(report.averageDaily == 1_500)
    }

    @Test func averagesOverTheWholePeriodOnceItIsOver() {
        let october = Self.date(2026, 10, 15)
        let report = Self.report([Self.tx(31_000, on: Self.date(2026, 10, 3))], anchor: october)
        #expect(!report.isCurrent)
        #expect(report.dayCount == 31)
        #expect(report.elapsedDays == 31)
        #expect(report.averageDaily == 1_000)
    }

    @Test func leavesOutFailedReceivedAndOwnTransfers() {
        let day = Self.date(2026, 11, 4)
        let report = Self.report([
            Self.tx(1_000, on: day),
            Self.tx(9_000, on: day, status: .failed),
            Self.tx(7_000, on: day, .incoming),
            Self.tx(4_000, on: day, category: .ownAccounts),
        ])
        #expect(report.totals.spent == 1_000)
        #expect(report.totals.received == 7_000)
        #expect(report.categories.map(\.total) == [1_000])
        #expect(report.topExpenses.map(\.amount) == [1_000])
    }

    // MARK: Change

    /// Ten days into November is set against the first ten of October,
    /// not October's whole month.
    @Test func comparesWithTheSameDaysOfThePeriodBefore() throws {
        let report = Self.report([
            Self.tx(2_000, on: Self.date(2026, 10, 5)),
            Self.tx(50_000, on: Self.date(2026, 10, 25)),
            Self.tx(3_000, on: Self.date(2026, 11, 5)),
        ])
        #expect(report.previousSpent == 2_000)
        let change = try #require(report.change)
        #expect(abs(change - 0.5) < 0.0001)
    }

    @Test func comparesWholePeriodsOnceOver() throws {
        let report = Self.report([
            Self.tx(1_000, on: Self.date(2026, 9, 5)),
            Self.tx(1_000, on: Self.date(2026, 9, 28)),
            Self.tx(1_000, on: Self.date(2026, 10, 30)),
        ], anchor: Self.date(2026, 10, 1))
        #expect(report.previousSpent == 2_000)
        #expect(try #require(report.change) == -0.5)
    }

    @Test func noChangeWithNothingBefore() {
        #expect(Self.report([Self.tx(1_000, on: Self.date(2026, 11, 2))]).change == nil)
    }

    // MARK: Breakdown

    @Test func categoriesLargestFirstWithUncategorisedAsOther() {
        let day = Self.date(2026, 11, 3)
        let report = Self.report([
            Self.tx(1_000, on: day, category: .restaurant),
            Self.tx(3_000, on: day, category: .groceries),
            Self.tx(500, on: day),
            Self.tx(500, on: day, category: .restaurant),
        ])
        #expect(report.categories.map(\.category) == [.groceries, .restaurant, .other])
        #expect(report.categories.map(\.total) == [3_000, 1_500, 500])
        #expect(report.categories.first?.share == 0.6)
        #expect(report.topCategory?.category == .groceries)
    }

    @Test func topExpensesAreTheThreeLargest() {
        let report = Self.report([1, 5, 3, 9, 7].enumerated().map { index, amount in
            Self.tx(amount * 1_000, on: Self.date(2026, 11, index + 1))
        })
        #expect(report.topExpenses.map(\.amount) == [9_000, 7_000, 5_000])
    }

    @Test func typesSplitShopsPeopleAndPurchases() {
        let day = Self.date(2026, 11, 3)
        let report = Self.report([
            Self.tx(6_000, on: day),
            Self.tx(3_000, on: day, name: "Aline", merchant: false),
            Self.tx(1_000, on: day, name: "MTN", category: .airtime),
        ])
        #expect(report.types.map(\.type) == [.merchants, .people, .purchases])
        #expect(report.types.map(\.share) == [0.6, 0.3, 0.1])
    }

    @Test func highestAndLowestDays() {
        let report = Self.report([
            Self.tx(1_000, on: Self.date(2026, 11, 2, 9)),
            Self.tx(2_000, on: Self.date(2026, 11, 2, 18)),
            Self.tx(500, on: Self.date(2026, 11, 6)),
            Self.tx(800, on: Self.date(2026, 11, 8)),
        ])
        #expect(report.highestDay == .init(day: Self.calendar.startOfDay(for: Self.date(2026, 11, 2)), total: 3_000))
        #expect(report.lowestDay?.total == 500)
    }

    @Test func daysInOrderWithTheirTopCategory() {
        let report = Self.report([
            Self.tx(800, on: Self.date(2026, 11, 8), category: .transport),
            Self.tx(1_000, on: Self.date(2026, 11, 2, 9), category: .groceries),
            Self.tx(2_000, on: Self.date(2026, 11, 2, 18), category: .restaurant),
        ])
        #expect(report.days.map(\.total) == [3_000, 800])
        #expect(report.days.map(\.count) == [2, 1])
        #expect(report.days.map(\.category) == [.restaurant, .transport])
        #expect(report.days.first?.day == Self.calendar.startOfDay(for: Self.date(2026, 11, 2)))
    }

    @Test func noLowestDayWithOneDay() {
        let report = Self.report([Self.tx(1_000, on: Self.date(2026, 11, 2))])
        #expect(report.highestDay?.total == 1_000)
        #expect(report.lowestDay == nil)
    }

    // MARK: Insight

    /// Restaurants usually 10,000 a month; this month 25,000 in three
    /// payments: 15,000 more, two payments' worth.
    @Test func namesTheCategoryFurthestOverItsUsual() {
        var items: [Transaction] = []
        for month in 7...9 {
            items.append(Self.tx(10_000, on: Self.date(2026, month, 3), category: .restaurant))
            items.append(Self.tx(5_000, on: Self.date(2026, month, 4), category: .groceries))
        }
        items += [9_000, 8_000, 8_000].map { Self.tx($0, on: Self.date(2026, 10, 5), category: .restaurant) }
        items.append(Self.tx(5_500, on: Self.date(2026, 10, 6), category: .groceries))
        let report = Self.report(items, anchor: Self.date(2026, 10, 15))
        #expect(report.usualSpent == 15_000)
        #expect(report.insight == .more(category: .restaurant, extra: 15_000, usual: 10_000, fewerPayments: 2))
    }

    @Test func lessThanUsualWhenNothingRises() {
        let items = [
            Self.tx(20_000, on: Self.date(2026, 9, 3), category: .groceries),
            Self.tx(15_000, on: Self.date(2026, 10, 3), category: .groceries),
        ]
        let report = Self.report(items, anchor: Self.date(2026, 10, 15))
        #expect(report.insight == .less(by: 5_000))
    }

    @Test func theTopShareWithNothingToCompare() {
        let report = Self.report([
            Self.tx(3_000, on: Self.date(2026, 11, 3), category: .restaurant),
            Self.tx(1_000, on: Self.date(2026, 11, 4), category: .transport),
        ])
        #expect(report.usualSpent == nil)
        #expect(report.insight == .share(category: .restaurant, share: 0.75))
    }

    /// Ten days into November, the usual is the first ten days of the
    /// months before, and a month with nothing spent does not count.
    @Test func theUsualKeepsToTheSameSpanAndSkipsEmptyPeriods() {
        let report = Self.report([
            Self.tx(4_000, on: Self.date(2026, 8, 5)),
            Self.tx(90_000, on: Self.date(2026, 8, 25)),
            Self.tx(2_000, on: Self.date(2026, 10, 5)),
            Self.tx(1_000, on: Self.date(2026, 11, 5)),
        ])
        #expect(report.usualSpent == 3_000)
    }

    // MARK: Filter and navigation

    @Test func narrowsToOneCategory() {
        let day = Self.date(2026, 11, 3)
        let report = Self.report([
            Self.tx(1_000, on: day, category: .gifts),
            Self.tx(3_000, on: day, category: .groceries),
            Self.tx(2_000, on: Self.date(2026, 10, 3), category: .gifts),
        ], category: .gifts)
        #expect(report.totals.spent == 1_000)
        #expect(report.categories.map(\.category) == [.gifts])
        #expect(report.previousSpent == 2_000)
    }

    @Test func stepsBackAndForth() {
        let back = ActivityPeriod.month.anchor(Self.now, movedBy: -1, calendar: Self.calendar)
        #expect(Self.calendar.component(.month, from: back) == 10)
        let year = ActivityPeriod.year.anchor(Self.now, movedBy: -2, calendar: Self.calendar)
        #expect(Self.calendar.component(.year, from: year) == 2024)
    }

    @Test func titlesNameEarlierPeriods() {
        let october = Self.date(2026, 10, 15)
        #expect(ActivityPeriod.month.title(for: Self.now, now: Self.now, calendar: Self.calendar, locale: Self.locale) == ActivityPeriod.month.title)
        #expect(ActivityPeriod.month.title(for: october, now: Self.now, calendar: Self.calendar, locale: Self.locale) == "October 2026")
        #expect(ActivityPeriod.year.title(for: Self.date(2025, 3, 1), now: Self.now, calendar: Self.calendar, locale: Self.locale) == "2025")
        #expect(ActivityPeriod.month.name(for: Self.now, calendar: Self.calendar, locale: Self.locale) == "November 2026")
        // Mid-sentence, a month keeps its language's case.
        let french = Locale(identifier: "fr_FR")
        #expect(ActivityPeriod.month.name(for: Self.now, calendar: Self.calendar, locale: french) == "Novembre 2026")
        #expect(ActivityPeriod.month.name(for: Self.now, calendar: Self.calendar, locale: french, inSentence: true) == "novembre 2026")
        #expect(ActivityPeriod.month.name(for: Self.now, calendar: Self.calendar, locale: Self.locale, inSentence: true) == "November 2026")
    }

    @Test func emptyReport() {
        let report = Self.report([])
        #expect(report.isEmpty)
        #expect(report.categories.isEmpty)
        #expect(report.insight == nil)
        #expect(report.highestDay == nil)
    }

    // MARK: Gifts

    @Test func giftShopsAreGifts() {
        #expect(TransactionCategorizer.category(name: "Kigali Gift Shop") == .gifts)
        #expect(TransactionCategorizer.category(name: "Impano Nziza") == .gifts)
        #expect(TransactionCategorizer.category(name: "Fleurs de Kigali") == .gifts)
        #expect(TransactionCategory.choices.contains(.gifts))
        #expect(!TransactionCategory.gifts.isPurchase)
    }
}
