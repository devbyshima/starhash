import Foundation
import Testing
@testable import StarHashKit

@Suite("NotificationPlan")
struct NotificationPlanTests {
    /// A Gregorian calendar in Kigali.
    static let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Africa/Kigali")!
        calendar.locale = Locale(identifier: "en_GB")
        return calendar
    }()

    /// Friday 2 October 2026, 14:00 in Kigali.
    static let now = date(2026, 10, 2, 14)

    static func date(_ year: Int, _ month: Int, _ day: Int, _ hour: Int = 12, _ minute: Int = 0) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour, minute: minute))!
    }

    static func tx(
        _ amount: Int,
        _ direction: Transaction.Direction = .outgoing,
        at date: Date,
        status: Transaction.Status = .confirmed,
        source: Transaction.Source = .app,
        name: String? = "Aline",
        fee: Int? = nil,
        balance: Int? = nil
    ) -> Transaction {
        Transaction(
            direction: direction,
            counterparty: Recipient(name: name, destination: "0788123456", kind: .phone),
            amount: amount, fee: fee, date: date, status: status, source: source, balanceAfter: balance
        )
    }

    // MARK: Reminders

    @Test func remindsOfAPendingPaymentAfterTheDelay() throws {
        let payment = Self.tx(5_000, at: Self.now.addingTimeInterval(-5 * 60), status: .pending)
        let plan = NotificationPlan.scheduled(for: [payment], settings: .init(reminderDelay: 30), now: Self.now, calendar: Self.calendar)
        let reminder = try #require(plan.first { $0.kind == .paymentReminder })
        #expect(reminder.date == payment.date.addingTimeInterval(30 * 60))
        #expect(reminder.transactionID == payment.id)
        #expect(reminder.body == "5,000 RWF to Aline is still pending. Mark it as confirmed or failed.")
    }

    @Test func noReminderOnceItsTimeHasPassed() {
        let payment = Self.tx(5_000, at: Self.now.addingTimeInterval(-2 * 3600), status: .pending)
        let plan = NotificationPlan.scheduled(for: [payment], settings: .init(reminderDelay: 30), now: Self.now, calendar: Self.calendar)
        #expect(!plan.contains { $0.kind == .paymentReminder })
    }

    @Test func noReminderForConfirmedOrMessagePaymentsOrWhenOff() {
        let recent = Self.now.addingTimeInterval(-60)
        let confirmed = Self.tx(5_000, at: recent, status: .confirmed)
        let fromSMS = Self.tx(5_000, at: recent, status: .pending, source: .sms)
        let pending = Self.tx(5_000, at: recent, status: .pending)
        #expect(NotificationPlan.reminder(for: confirmed, settings: .init()) == nil)
        #expect(NotificationPlan.reminder(for: fromSMS, settings: .init()) == nil)
        #expect(NotificationPlan.reminder(for: pending, settings: .init(paymentReminders: false)) == nil)
    }

    @Test func hiddenAmountsLeaveTheReminderWithoutOne() throws {
        let payment = Self.tx(5_000, at: Self.now, status: .pending)
        let reminder = try #require(NotificationPlan.reminder(for: payment, settings: .init(showsAmounts: false)))
        #expect(reminder.body == "Your payment to Aline is still pending. Mark it as confirmed or failed.")
    }

    // MARK: After a message

    @Test func confirmedPaymentSaysItsFeeAndBalance() throws {
        let pending = Self.tx(5_000, at: Self.now, status: .pending)
        var confirmed = pending
        confirmed.status = .confirmed
        confirmed.fee = 100
        confirmed.balanceAfter = 12_000
        let item = try #require(NotificationPlan.afterMessage(applied: confirmed, previous: pending, settings: .init(confirmedPayments: true)))
        #expect(item.kind == .paymentConfirmed)
        #expect(item.date == nil)
        #expect(item.body == "5,000 RWF to Aline went through. Fee 100 RWF, balance 12,000 RWF.")
    }

    @Test func aMessageAppliedTwiceSaysNothing() {
        let confirmed = Self.tx(5_000, at: Self.now, status: .confirmed)
        #expect(NotificationPlan.afterMessage(applied: confirmed, previous: confirmed, settings: .init(confirmedPayments: true)) == nil)
    }

    @Test func moneyReceivedOnlyWhenChosen() throws {
        let received = Self.tx(20_000, .incoming, at: Self.now, source: .sms, balance: 32_000)
        #expect(NotificationPlan.afterMessage(applied: received, previous: nil, settings: .init()) == nil)
        let item = try #require(NotificationPlan.afterMessage(applied: received, previous: nil, settings: .init(moneyReceived: true)))
        #expect(item.body == "Aline sent you 20,000 RWF. Balance 32,000 RWF.")
        let hidden = try #require(NotificationPlan.afterMessage(applied: received, previous: nil, settings: .init(moneyReceived: true, showsAmounts: false)))
        #expect(hidden.body == "Aline sent you money.")
    }

    @Test func aPaymentMadeOutsideStarHashSaysNothing() {
        let logged = Self.tx(5_000, at: Self.now, source: .sms)
        #expect(NotificationPlan.afterMessage(applied: logged, previous: nil, settings: .init(confirmedPayments: true, moneyReceived: true)) == nil)
    }

    // MARK: Summaries

    @Test func weeklySummaryComesOnTheChosenDayAndCountsTheSevenDaysBefore() throws {
        let transactions = [
            Self.tx(10_000, at: Self.date(2026, 9, 30)),
            Self.tx(2_500, at: Self.date(2026, 10, 1)),
            Self.tx(7_000, .incoming, at: Self.date(2026, 10, 2, 9)),
            Self.tx(99_000, at: Self.date(2026, 10, 1), status: .failed),
            // Before the week.
            Self.tx(50_000, at: Self.date(2026, 9, 20)),
        ]
        let plan = NotificationPlan.scheduled(for: transactions, settings: .init(weeklyDay: 1, monthlySummary: false, summaryHour: 18), now: Self.now, calendar: Self.calendar)
        let weekly = try #require(plan.first { $0.kind == .weeklySummary })
        // Sunday 4 October, 18:00.
        #expect(weekly.date == Self.date(2026, 10, 4, 18))
        #expect(weekly.body == "You sent 12,500 RWF in 2 payments and received 7,000 RWF this week.")
    }

    @Test func noSummaryForAnEmptyPeriod() {
        let old = Self.tx(10_000, at: Self.date(2026, 8, 1))
        let plan = NotificationPlan.scheduled(for: [old], settings: .init(), now: Self.now, calendar: Self.calendar)
        #expect(plan.isEmpty)
    }

    @Test func monthlySummaryComesOnTheFirstForTheMonthJustEnded() throws {
        let transactions = [
            Self.tx(4_000, at: Self.date(2026, 10, 1)),
            Self.tx(6_000, at: Self.date(2026, 10, 2, 8)),
            // September's, already summed up on 1 October.
            Self.tx(80_000, at: Self.date(2026, 9, 28)),
        ]
        let plan = NotificationPlan.scheduled(for: transactions, settings: .init(weeklySummary: false, summaryHour: 9), now: Self.now, calendar: Self.calendar)
        let monthly = try #require(plan.first { $0.kind == .monthlySummary })
        #expect(monthly.date == Self.date(2026, 11, 1, 9))
        #expect(monthly.title == "Your October")
        #expect(monthly.body == "You sent 10,000 RWF in 2 payments in October.")
    }

    @Test func hiddenAmountsCountPaymentsInstead() throws {
        let one = Self.tx(4_000, at: Self.date(2026, 10, 1))
        let plan = NotificationPlan.scheduled(for: [one], settings: .init(monthlySummary: false, showsAmounts: false), now: Self.now, calendar: Self.calendar)
        let weekly = try #require(plan.first { $0.kind == .weeklySummary })
        #expect(weekly.body == "You made 1 payment this week. Open StarHash to see where your money went.")
    }

    @Test func scheduledIdsKeepToTheirPrefixes() {
        let transactions = [
            Self.tx(5_000, at: Self.now.addingTimeInterval(-60), status: .pending),
            Self.tx(4_000, at: Self.date(2026, 10, 1)),
        ]
        let plan = NotificationPlan.scheduled(for: transactions, settings: .init(), now: Self.now, calendar: Self.calendar)
        #expect(plan.count == 3)
        #expect(plan.allSatisfy { item in NotificationPlan.scheduledPrefixes.contains { item.id.hasPrefix($0) } })
    }

    // MARK: Marking by hand

    @Test func markedFailedDropsTheFee() {
        let payment = Self.tx(5_000, at: Self.now, status: .pending, fee: 100)
        let failed = payment.markedFailed()
        #expect(failed.status == .failed)
        #expect(failed.fee == nil)
    }

    @Test func confirmedByHandTakesTheTariffFee() {
        let payment = Self.tx(5_000, at: Self.now, status: .pending)
        let confirmed = payment.confirmedByHand(wallet: .mtn)
        #expect(confirmed.status == .confirmed)
        #expect(confirmed.fee == Tariff.fee(sending: 5_000, to: payment.counterparty, from: .mtn))
    }
}
