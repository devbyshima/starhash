import Foundation

/// A month of money, worked out for the Reports page: what went out and
/// came in, where it went by category and by recipient, how it compares
/// with the month before, and the plain facts the page's summary is
/// written from. Failed payments count for nothing, as on Activity.
public struct MonthlyReport: Equatable, Sendable {
    /// Where a share of the month's spending went: a category, money sent
    /// to people with none, or other payments with none.
    public enum Group: Hashable, Sendable {
        case category(TransactionCategory)
        case people
        case uncategorized
    }

    public struct GroupTotal: Equatable, Identifiable, Sendable {
        public let group: Group
        public let amount: Int
        public let count: Int
        /// Of the month's spending, 0 to 1.
        public let share: Double
        public var id: Group { group }
    }

    public struct RecipientTotal: Equatable, Identifiable, Sendable {
        public let recipient: Recipient
        public let amount: Int
        public let count: Int
        public var id: String { recipient.kind.rawValue + recipient.destination + (recipient.name ?? "") }
    }

    /// The month, from its first moment to the next month's.
    public let month: DateInterval
    public let spent: Int
    public let received: Int
    public let fees: Int
    /// Payments that went through.
    public let paymentCount: Int
    /// Of `spent`, what bought airtime, bundles, electricity, water and TV.
    public let purchases: Int
    /// The month before's spending, nil when nothing went out then.
    public let previousSpent: Int?
    /// Biggest first.
    public let groups: [GroupTotal]
    /// The five paid the most, most first.
    public let topRecipients: [RecipientTotal]
    public let biggestPayment: Transaction?
    /// The weekday most was spent on (`Calendar` numbering, 1 is Sunday).
    public let busiestWeekday: Int?
    /// Spending spread over the month's days so far (all of them, for a
    /// month that is over).
    public let dailyAverage: Int
    /// Payments still waiting for their message.
    public let pendingCount: Int

    /// Whether anything moved in the month.
    public var isEmpty: Bool { spent == 0 && received == 0 && pendingCount == 0 }

    /// The change on the month before, as a fraction (0.12 is 12% more), nil
    /// when there is nothing to compare with.
    public var change: Double? {
        guard let previousSpent, previousSpent > 0 else { return nil }
        return Double(spent - previousSpent) / Double(previousSpent)
    }

    /// The report for the month holding `date`.
    public static func make(
        for date: Date,
        from transactions: [Transaction],
        now: Date = .now,
        calendar: Calendar = .current
    ) -> MonthlyReport {
        let month = calendar.dateInterval(of: .month, for: date) ?? DateInterval(start: date, duration: 0)
        let inMonth = transactions.filter { month.contains($0.date) && $0.date < month.end }
        let counted = inMonth.filter { $0.status != .failed }
        let pending = inMonth.filter { $0.status == .pending }.count
        let totals = ActivitySummary.totals(of: counted)
        let outgoing = counted.filter { $0.direction == .outgoing }

        let previousSpent: Int? = {
            guard let before = calendar.date(byAdding: .month, value: -1, to: month.start),
                  let previous = calendar.dateInterval(of: .month, for: before) else { return nil }
            let spent = transactions
                .filter { $0.direction == .outgoing && $0.status != .failed && previous.contains($0.date) && $0.date < previous.end }
                .reduce(0) { $0 + $1.amount }
            return spent > 0 ? spent : nil
        }()

        var byGroup: [Group: (amount: Int, count: Int)] = [:]
        for t in outgoing {
            let group: Group = if let category = t.knownCategory {
                .category(category)
            } else if t.counterparty.kind == .phone {
                .people
            } else {
                .uncategorized
            }
            byGroup[group, default: (0, 0)].amount += t.amount
            byGroup[group, default: (0, 0)].count += 1
        }
        let spent = totals.spent
        let groups = byGroup
            .map { GroupTotal(group: $0.key, amount: $0.value.amount, count: $0.value.count, share: spent > 0 ? Double($0.value.amount) / Double(spent) : 0) }
            .sorted { $0.amount != $1.amount ? $0.amount > $1.amount : $0.count > $1.count }

        var byRecipient: [String: (recipient: Recipient, amount: Int, count: Int)] = [:]
        for t in outgoing {
            let key = t.counterparty.destination.isEmpty
                ? "name:" + (t.counterparty.name ?? "").lowercased()
                : t.counterparty.kind.rawValue + t.counterparty.destination
            var entry = byRecipient[key] ?? (t.counterparty, 0, 0)
            entry.amount += t.amount
            entry.count += 1
            byRecipient[key] = entry
        }
        let topRecipients = byRecipient.values
            .sorted { $0.amount != $1.amount ? $0.amount > $1.amount : $0.count > $1.count }
            .prefix(5)
            .map { RecipientTotal(recipient: $0.recipient, amount: $0.amount, count: $0.count) }

        var byWeekday: [Int: Int] = [:]
        for t in outgoing { byWeekday[calendar.component(.weekday, from: t.date), default: 0] += t.amount }
        let busiest = byWeekday.max { $0.value != $1.value ? $0.value < $1.value : $0.key > $1.key }?.key

        let elapsedEnd = min(month.end, max(month.start, now))
        let days = max(1, calendar.dateComponents([.day], from: month.start, to: elapsedEnd).day.map { now < month.end ? $0 + 1 : $0 } ?? 1)

        return MonthlyReport(
            month: month,
            spent: spent,
            received: totals.received,
            fees: totals.fees,
            paymentCount: outgoing.count,
            purchases: outgoing.filter(\.isPurchase).reduce(0) { $0 + $1.amount },
            previousSpent: previousSpent,
            groups: groups,
            topRecipients: Array(topRecipients),
            biggestPayment: outgoing.max { $0.amount < $1.amount },
            busiestWeekday: busiest,
            dailyAverage: spent / days,
            pendingCount: pending
        )
    }

    /// The months that have anything in them, newest first, for stepping
    /// back through reports.
    public static func months(with transactions: [Transaction], calendar: Calendar = .current) -> [Date] {
        var starts = Set<Date>()
        for t in transactions {
            if let start = calendar.dateInterval(of: .month, for: t.date)?.start { starts.insert(start) }
        }
        return starts.sorted(by: >)
    }
}
