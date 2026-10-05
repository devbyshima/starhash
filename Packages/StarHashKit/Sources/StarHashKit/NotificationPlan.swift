import Foundation

/// The notifications StarHash makes, worked out from the transactions: a
/// reminder for a payment still pending a while after it was dialled, word
/// of a payment its SMS confirmed or of money received, and the week's and
/// the month's summaries. Pure, so the app only hands the plan to iOS. Every
/// notification is made on the iPhone; nothing is sent from a server.
public enum NotificationPlan {
    /// What the owner chose on the Notifications page. Everything starts on
    /// except the two that repeat the wallet's own SMS, which already
    /// arrives with its banner: a confirmed payment and money received.
    public struct Settings: Equatable, Sendable {
        public var paymentReminders: Bool
        /// How long after a payment is dialled its reminder comes, in minutes.
        public var reminderDelay: Int
        public var confirmedPayments: Bool
        public var moneyReceived: Bool
        public var weeklySummary: Bool
        /// The weekly summary's day, as `Calendar` numbers them: 1 is Sunday.
        public var weeklyDay: Int
        public var monthlySummary: Bool
        /// The hour both summaries come, 0 to 23.
        public var summaryHour: Int
        /// Off keeps amounts and balances off the Lock Screen: the
        /// notifications say what happened, not how much.
        public var showsAmounts: Bool
        /// Auto-verify is on and working, so a payment no message confirms
        /// within the hour fails on its own (`AutoVerify`): its reminder
        /// becomes word that it failed, at the hour, in place of a nudge.
        /// Not a choice on the page; the app works it out.
        public var failsUnconfirmed: Bool

        public init(
            paymentReminders: Bool = true,
            reminderDelay: Int = NotificationPlan.defaultReminderDelay,
            confirmedPayments: Bool = false,
            moneyReceived: Bool = false,
            weeklySummary: Bool = true,
            weeklyDay: Int = NotificationPlan.defaultWeeklyDay,
            monthlySummary: Bool = true,
            summaryHour: Int = NotificationPlan.defaultSummaryHour,
            showsAmounts: Bool = true,
            failsUnconfirmed: Bool = false
        ) {
            self.paymentReminders = paymentReminders
            self.reminderDelay = reminderDelay
            self.confirmedPayments = confirmedPayments
            self.moneyReceived = moneyReceived
            self.weeklySummary = weeklySummary
            self.weeklyDay = weeklyDay
            self.monthlySummary = monthlySummary
            self.summaryHour = summaryHour
            self.showsAmounts = showsAmounts
            self.failsUnconfirmed = failsUnconfirmed
        }
    }

    /// One notification: when it shows, what it says, and the transaction
    /// it is about.
    public struct Item: Equatable, Sendable {
        public enum Kind: String, Sendable {
            case paymentReminder
            /// A payment no message confirmed within the hour, failed.
            case paymentExpired
            case paymentConfirmed
            case moneyReceived
            case weeklySummary
            case monthlySummary
        }

        /// The same for the same reminder or summary every time it is
        /// worked out, so scheduling it again replaces it.
        public let id: String
        public let kind: Kind
        /// When it shows; nil for at once.
        public let date: Date?
        public let title: String
        public let body: String
        /// The transaction it is about, which tapping it opens.
        public let transactionID: UUID?
    }

    /// The reminder's choices, in minutes.
    public static let reminderDelays = [10, 30, 60, 180]
    public static let defaultReminderDelay = 30
    /// The summaries' choices of hour.
    public static let summaryHours = [7, 9, 12, 18, 20]
    public static let defaultSummaryHour = 18
    /// Sunday evening, as the week ends.
    public static let defaultWeeklyDay = 1

    /// The ids of what `scheduled` plans, for telling StarHash's waiting
    /// notifications from ones about to show.
    public static let scheduledPrefixes = ["payment-reminder.", "weekly-summary", "monthly-summary"]

    // MARK: Scheduled

    /// What to schedule now: a reminder for each payment dialled from
    /// StarHash that is still pending and whose reminder is still to come,
    /// and the next weekly and monthly summaries when their period has
    /// anything in it so far. Worked out again whenever a transaction
    /// changes, so a summary always counts everything up to the moment it
    /// shows.
    public static func scheduled(
        for transactions: [Transaction],
        settings: Settings,
        now: Date,
        calendar: Calendar
    ) -> [Item] {
        let reminders = transactions.compactMap { reminder(for: $0, settings: settings) }
            .filter { ($0.date ?? now) > now }
        let summaries = [
            weeklySummary(of: transactions, settings: settings, now: now, calendar: calendar),
            monthlySummary(of: transactions, settings: settings, now: now, calendar: calendar),
        ].compactMap(\.self)
        return reminders + summaries
    }

    /// A payment dialled from StarHash with no SMS to confirm it yet:
    /// asks whether it went through, `reminderDelay` minutes on. With
    /// auto-verify failing such payments, says it failed instead, at the
    /// hour. Both share an id, so one replaces the other.
    public static func reminder(for transaction: Transaction, settings: Settings) -> Item? {
        guard settings.paymentReminders, transaction.status == .pending,
              transaction.source == .app, transaction.direction == .outgoing else { return nil }
        let name = transaction.counterparty.displayName
        if settings.failsUnconfirmed {
            let messages = transaction.wallet.map { "\($0.messagesName) message" } ?? "message"
            let what = settings.showsAmounts
                ? "\(Money.formatWithCurrency(transaction.amount)) to \(name)"
                : "your payment to \(name)"
            return Item(
                id: "payment-reminder.\(transaction.id.uuidString)",
                kind: .paymentExpired,
                date: transaction.date.addingTimeInterval(AutoVerify.confirmationWindow),
                title: "Your payment didn't go through",
                body: "No \(messages) confirmed \(what) within an hour, so StarHash marked it failed.",
                transactionID: transaction.id
            )
        }
        let what = settings.showsAmounts
            ? "\(Money.formatWithCurrency(transaction.amount)) to \(name)"
            : "Your payment to \(name)"
        return Item(
            id: "payment-reminder.\(transaction.id.uuidString)",
            kind: .paymentReminder,
            date: transaction.date.addingTimeInterval(TimeInterval(settings.reminderDelay * 60)),
            title: "Did your payment go through?",
            body: "\(what) is still pending. Mark it as confirmed or failed.",
            transactionID: transaction.id
        )
    }

    // MARK: At once

    /// What a carrier SMS just did, worth a word: a payment it confirmed,
    /// or money it logged as received. `previous` is the transaction as it
    /// stood before the message, nil when the message added it; a message
    /// applied twice changes nothing and says nothing.
    public static func afterMessage(applied transaction: Transaction, previous: Transaction?, settings: Settings) -> Item? {
        let name = transaction.counterparty.displayName
        if let previous {
            guard settings.confirmedPayments, previous.status == .pending,
                  transaction.status == .confirmed, transaction.direction == .outgoing else { return nil }
            var body = settings.showsAmounts
                ? "\(Money.formatWithCurrency(transaction.amount)) to \(name) went through."
                : "Your payment to \(name) went through."
            if settings.showsAmounts {
                let details = [
                    transaction.fee.map { "fee \(Money.formatWithCurrency($0))" },
                    transaction.balanceAfter.map { "balance \(Money.formatWithCurrency($0))" },
                ].compactMap(\.self)
                if !details.isEmpty {
                    let line = details.joined(separator: ", ")
                    body += " " + line.prefix(1).uppercased() + line.dropFirst() + "."
                }
            }
            return Item(
                id: "payment-confirmed.\(transaction.id.uuidString)", kind: .paymentConfirmed, date: nil,
                title: "Payment confirmed", body: body, transactionID: transaction.id
            )
        }
        guard settings.moneyReceived, transaction.direction == .incoming else { return nil }
        var body = settings.showsAmounts
            ? "\(name) sent you \(Money.formatWithCurrency(transaction.amount))."
            : "\(name) sent you money."
        if settings.showsAmounts, let balance = transaction.balanceAfter {
            body += " Balance \(Money.formatWithCurrency(balance))."
        }
        return Item(
            id: "money-received.\(transaction.id.uuidString)", kind: .moneyReceived, date: nil,
            title: "Money received", body: body, transactionID: transaction.id
        )
    }

    // MARK: Summaries

    /// The next weekly summary: the seven days up to it, on the chosen day
    /// at the chosen hour.
    static func weeklySummary(of transactions: [Transaction], settings: Settings, now: Date, calendar: Calendar) -> Item? {
        guard settings.weeklySummary,
              let date = calendar.nextDate(
                after: now,
                matching: DateComponents(hour: settings.summaryHour, minute: 0, weekday: settings.weeklyDay),
                matchingPolicy: .nextTime
              ),
              let start = calendar.date(byAdding: .day, value: -7, to: date) else { return nil }
        return summary(
            id: "weekly-summary", kind: .weeklySummary, date: date, title: "Your week", period: "this week",
            of: transactions.filter { start <= $0.date && $0.date < date }, settings: settings
        )
    }

    /// The next monthly summary: the month just ended, on the 1st at the
    /// chosen hour.
    static func monthlySummary(of transactions: [Transaction], settings: Settings, now: Date, calendar: Calendar) -> Item? {
        guard settings.monthlySummary,
              let date = calendar.nextDate(
                after: now,
                matching: DateComponents(day: 1, hour: settings.summaryHour, minute: 0),
                matchingPolicy: .nextTime
              ),
              let lastDay = calendar.date(byAdding: .day, value: -1, to: date),
              let month = calendar.dateInterval(of: .month, for: lastDay) else { return nil }
        let name = calendar.standaloneMonthSymbols[calendar.component(.month, from: month.start) - 1]
        return summary(
            id: "monthly-summary", kind: .monthlySummary, date: date, title: "Your \(name)", period: "in \(name)",
            of: transactions.filter { month.start <= $0.date && $0.date < month.end }, settings: settings
        )
    }

    /// What was sent and received in a period. Nothing when nothing moved:
    /// failed payments count for nothing, as on Activity.
    private static func summary(
        id: String,
        kind: Item.Kind,
        date: Date,
        title: String,
        period: String,
        of transactions: [Transaction],
        settings: Settings
    ) -> Item? {
        let counted = transactions.filter { $0.status != .failed }
        guard !counted.isEmpty else { return nil }
        let totals = ActivitySummary.totals(of: counted)
        let payments = counted.filter { $0.direction == .outgoing }.count
        let paymentsPhrase = payments == 1 ? "1 payment" : "\(payments) payments"
        let body: String
        if settings.showsAmounts {
            let sent = "You sent \(Money.formatWithCurrency(totals.spent)) in \(paymentsPhrase)"
            let received = "received \(Money.formatWithCurrency(totals.received))"
            body = switch (payments > 0, totals.received > 0) {
            case (true, true): "\(sent) and \(received) \(period)."
            case (true, false): "\(sent) \(period)."
            default: "You \(received) \(period)."
            }
        } else {
            body = payments > 0
                ? "You made \(paymentsPhrase) \(period). Open StarHash to see where your money went."
                : "You received money \(period). Open StarHash to see it."
        }
        return Item(id: id, kind: kind, date: date, title: title, body: body, transactionID: nil)
    }
}
