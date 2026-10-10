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
            /// A message that looks like the wallet's but may be a scam.
            case scamWarning
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
        /// For a summary, the month whose report tapping it opens.
        public var reportMonth: Date?

        public init(id: String, kind: Kind, date: Date?, title: String, body: String, transactionID: UUID?, reportMonth: Date? = nil) {
            self.id = id
            self.kind = kind
            self.date = date
            self.title = title
            self.body = body
            self.transactionID = transactionID
            self.reportMonth = reportMonth
        }
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
            let messages = transaction.wallet.map { String(localized: "\($0.messagesName) message", bundle: .module) } ?? String(localized: "message", bundle: .module)
            let what = settings.showsAmounts
                ? String(localized: "\(Money.formatWithCurrency(transaction.amount)) to \(name)", bundle: .module)
                : String(localized: "your payment to \(name)", bundle: .module)
            return Item(
                id: "payment-reminder.\(transaction.id.uuidString)",
                kind: .paymentExpired,
                date: transaction.date.addingTimeInterval(AutoVerify.confirmationWindow),
                title: String(localized: "Your payment didn't go through", bundle: .module),
                body: String(localized: "No \(messages) confirmed \(what) within an hour, so StarHash marked it failed.", bundle: .module),
                transactionID: transaction.id
            )
        }
        let what = settings.showsAmounts
            ? String(localized: "\(Money.formatWithCurrency(transaction.amount)) to \(name)", bundle: .module)
            : String(localized: "Your payment to \(name)", bundle: .module)
        return Item(
            id: "payment-reminder.\(transaction.id.uuidString)",
            kind: .paymentReminder,
            date: transaction.date.addingTimeInterval(TimeInterval(settings.reminderDelay * 60)),
            title: String(localized: "Did your payment go through?", bundle: .module),
            body: String(localized: "\(what) is still pending. Mark it as confirmed or failed.", bundle: .module),
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
                ? String(localized: "\(Money.formatWithCurrency(transaction.amount)) to \(name) went through.", bundle: .module)
                : String(localized: "Your payment to \(name) went through.", bundle: .module)
            if settings.showsAmounts {
                let details = [
                    transaction.fee.map { String(localized: "fee \(Money.formatWithCurrency($0))", bundle: .module) },
                    transaction.balanceAfter.map { String(localized: "balance \(Money.formatWithCurrency($0))", bundle: .module) },
                ].compactMap(\.self)
                if !details.isEmpty {
                    let line = details.joined(separator: ", ")
                    body += " " + line.prefix(1).uppercased() + line.dropFirst() + "."
                }
            }
            return Item(
                id: "payment-confirmed.\(transaction.id.uuidString)", kind: .paymentConfirmed, date: nil,
                title: String(localized: "Payment confirmed", bundle: .module), body: body, transactionID: transaction.id
            )
        }
        guard settings.moneyReceived, transaction.direction == .incoming else { return nil }
        var body = settings.showsAmounts
            ? String(localized: "\(name) sent you \(Money.formatWithCurrency(transaction.amount)).", bundle: .module)
            : String(localized: "\(name) sent you money.", bundle: .module)
        if settings.showsAmounts, let balance = transaction.balanceAfter {
            body += String(localized: " Balance \(Money.formatWithCurrency(balance)).", bundle: .module)
        }
        return Item(
            id: "money-received.\(transaction.id.uuidString)", kind: .moneyReceived, date: nil,
            title: String(localized: "Money received", bundle: .module), body: body, transactionID: transaction.id
        )
    }

    // MARK: Scams

    /// Word, at once, that a message which looks like the wallet's may be
    /// a scam, and was not logged. Shown whatever the Notifications page
    /// says: it is a warning, not news.
    public static func scamWarning(_ warning: ScamWarning, settings: Settings, at date: Date = .now) -> Item {
        let wallet = warning.wallet.walletName
        let claim: String = if let claimed = warning.claimed, claimed.direction == .incoming, settings.showsAmounts {
            String(localized: "says you received \(Money.formatWithCurrency(claimed.amount))", bundle: .module)
        } else {
            String(localized: "looks like \(wallet)'s", bundle: .module)
        }
        let body: String = switch warning.reason {
        case .unofficialSender:
            String(localized: "A message from \(warning.sender ?? String(localized: "an unknown sender", bundle: .module)) \(claim), but \(wallet)'s come from \(warning.wallet.messagesName). Don't send any money back. Check your balance first.", bundle: .module)
        case .suspiciousWording:
            String(localized: "A message that \(claim) asks for money back. \(wallet) never does. Check your balance before you send anything.", bundle: .module)
        }
        return Item(
            id: "scam-warning.\(Int(date.timeIntervalSince1970))", kind: .scamWarning, date: nil,
            title: String(localized: "This may be a scam", bundle: .module), body: body, transactionID: nil
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
        var item = summary(
            id: "weekly-summary", kind: .weeklySummary, date: date, title: String(localized: "Your week", bundle: .module), period: String(localized: "this week", bundle: .module),
            of: transactions.filter { start <= $0.date && $0.date < date }, settings: settings
        )
        // The month the week ends in, whose report it opens.
        item?.reportMonth = calendar.dateInterval(of: .month, for: date.addingTimeInterval(-1))?.start
        return item
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
        var item = summary(
            id: "monthly-summary", kind: .monthlySummary, date: date, title: String(localized: "Your \(name)", bundle: .module), period: String(localized: "in \(name)", bundle: .module),
            of: transactions.filter { month.start <= $0.date && $0.date < month.end }, settings: settings
        )
        item?.reportMonth = month.start
        return item
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
        let paymentsPhrase = payments == 1 ? String(localized: "1 payment", bundle: .module) : String(localized: "\(payments) payments", bundle: .module)
        let body: String
        if settings.showsAmounts {
            let sent = String(localized: "You sent \(Money.formatWithCurrency(totals.spent)) in \(paymentsPhrase)", bundle: .module)
            let received = String(localized: "received \(Money.formatWithCurrency(totals.received))", bundle: .module)
            body = switch (payments > 0, totals.received > 0) {
            case (true, true): String(localized: "\(sent) and \(received) \(period).", bundle: .module)
            case (true, false): String(localized: "\(sent) \(period).", bundle: .module)
            default: String(localized: "You \(received) \(period).", bundle: .module)
            }
        } else {
            body = payments > 0
                ? String(localized: "You made \(paymentsPhrase) \(period). Open StarHash to see where your money went.", bundle: .module)
                : String(localized: "You received money \(period). Open StarHash to see it.", bundle: .module)
        }
        return Item(id: id, kind: kind, date: date, title: title, body: body, transactionID: nil)
    }
}
