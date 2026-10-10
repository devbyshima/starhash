import Foundation
import StarHashKit
#if canImport(FoundationModels)
import FoundationModels
#endif

/// Writes the few sentences at the top of a month's report. With Apple
/// Intelligence (iOS 26 and later, in a language it speaks), the on-device
/// model writes them from the report's figures; otherwise StarHash writes
/// them itself from the same figures. Either way nothing leaves the iPhone.
@MainActor
enum ReportNarrator {
    struct Summary: Equatable {
        let text: String
        /// Written by the on-device model rather than StarHash's own words.
        let byModel: Bool
    }

    /// How long the model has to write before StarHash's own words stand in.
    nonisolated static let modelPatience: Duration = .seconds(8)

    /// The summary for `report`, from the model when it can, else StarHash's
    /// own. `previousName` is the month before's name.
    static func summary(of report: MonthlyReport, monthName: String, previousName: String) async -> Summary {
        let plain = plainSummary(of: report, monthName: monthName, previousName: previousName)
        #if canImport(FoundationModels)
        if #available(iOS 26.0, *), SmartCategories.isAvailable,
           SystemLanguageModel.default.supportsLocale(Locale.current) {
            let facts = self.facts(of: report, monthName: monthName, previousName: previousName)
            // The model gets a few seconds, then StarHash's own words stand
            // in: a busy phone or a model still loading would otherwise leave
            // the card as a placeholder for as long as it takes.
            let written: String? = await withCheckedContinuation { continuation in
                let once = ResumeOnce(continuation)
                let model = Task { once.resume(await modelSummary(of: facts)) }
                Task {
                    try? await Task.sleep(for: modelPatience)
                    model.cancel()
                    once.resume(nil)
                }
            }
            if let text = written?.trimmingCharacters(in: .whitespacesAndNewlines)
                .replacingOccurrences(of: "\u{2014}", with: ","), !text.isEmpty {
                return Summary(text: text, byModel: true)
            }
        }
        #endif
        return Summary(text: plain, byModel: false)
    }

    #if canImport(FoundationModels)
    /// The on-device model's few sentences from `facts`, or nil when it
    /// fails or is cancelled.
    @available(iOS 26.0, *)
    private static func modelSummary(of facts: String) async -> String? {
        let session = LanguageModelSession(instructions: """
            You write a short, friendly summary of someone's month of mobile money spending in Rwanda, \
            for the top of a monthly report in their payments app. \
            Write two or three short sentences, in the second person, in plain everyday words. \
            Use only the facts you are given and do not invent any. Amounts are in Rwandan francs (RWF). \
            Point out what stands out most. Do not give financial advice and do not judge. \
            Do not use dashes, lists, headings or emoji.
            """)
        return try? await session.respond(to: facts).content
    }
    #endif

    /// The figures, one per line, as the model is given them.
    private static func facts(of report: MonthlyReport, monthName: String, previousName: String) -> String {
        var lines = [
            "Month: \(monthName)",
            "Spent: \(Money.formatWithCurrency(report.spent)) in \(report.paymentCount) payments",
            "Received: \(Money.formatWithCurrency(report.received))",
            "Fees paid: \(Money.formatWithCurrency(report.fees))",
            "Average spent per day: \(Money.formatWithCurrency(report.dailyAverage))",
        ]
        if let previous = report.previousSpent {
            lines.append("Spent in \(previousName): \(Money.formatWithCurrency(previous))")
        }
        for group in report.groups.prefix(4) {
            lines.append("Spent on \(group.group.englishName): \(Money.formatWithCurrency(group.amount)) (\(Int((group.share * 100).rounded()))%)")
        }
        if let top = report.topRecipients.first {
            lines.append("Paid the most: \(top.recipient.displayName), \(Money.formatWithCurrency(top.amount)) over \(top.count) payments")
        }
        if report.purchases > 0 {
            lines.append("Bought airtime, bundles, electricity, water or TV: \(Money.formatWithCurrency(report.purchases))")
        }
        if let biggest = report.biggestPayment {
            lines.append("Biggest payment: \(Money.formatWithCurrency(biggest.amount)) to \(biggest.counterparty.displayName)")
        }
        return lines.joined(separator: "\n")
    }

    /// StarHash's own sentences, from the same figures.
    static func plainSummary(of report: MonthlyReport, monthName: String, previousName: String) -> String {
        guard report.spent > 0 else {
            return report.received > 0
                ? String(localized: "You received \(Money.formatWithCurrency(report.received)) in \(monthName) and spent nothing.")
                : String(localized: "Nothing went out in \(monthName).")
        }
        var sentences: [String] = []
        let payments = report.paymentCount
        sentences.append(String(localized: "You spent \(Money.formatWithCurrency(report.spent)) in \(monthName), over \(payments) payments."))
        if let change = report.change {
            let percent = Int((abs(change) * 100).rounded())
            if percent == 0 {
                sentences.append(String(localized: "That is about the same as \(previousName)."))
            } else if change > 0 {
                sentences.append(String(localized: "That is \(percent)% more than \(previousName)."))
            } else {
                sentences.append(String(localized: "That is \(percent)% less than \(previousName)."))
            }
        }
        if let top = report.groups.first, top.share >= 0.2 {
            let percent = Int((top.share * 100).rounded())
            sentences.append(String(localized: "The most went to \(top.group.title.lowercased()), \(percent)% of it."))
        }
        if let recipient = report.topRecipients.first, recipient.count > 1 {
            sentences.append(String(localized: "You paid \(recipient.recipient.displayName) the most, \(Money.formatWithCurrency(recipient.amount)) over \(recipient.count) payments."))
        }
        if report.fees > 0 {
            sentences.append(String(localized: "Fees came to \(Money.formatWithCurrency(report.fees))."))
        }
        return sentences.joined(separator: " ")
    }
}

extension MonthlyReport.Group {
    /// The group's name in English, for the model, whatever the app's
    /// language.
    var englishName: String {
        switch self {
        case .category(let category): category.rawValue
        case .people: "money sent to people"
        case .uncategorized: "other payments"
        }
    }
}

/// Hands a continuation the first answer it is given, the model's or the
/// timeout's, and drops the other.
@MainActor
private final class ResumeOnce {
    private var continuation: CheckedContinuation<String?, Never>?

    init(_ continuation: CheckedContinuation<String?, Never>) {
        self.continuation = continuation
    }

    func resume(_ value: String?) {
        continuation?.resume(returning: value)
        continuation = nil
    }
}
