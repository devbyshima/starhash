#if DEBUG
import StarHashKit
import SwiftUI

/// `-reportSummaries <page>`: the Report's sentences at every length
/// StarHash can write them, the shortest and the longest of each kind,
/// to check how they sit on the page in each language.
struct ReportGallery: View {
    let page: Int

    private struct Sample: Identifiable {
        let id: String
        let insight: SpendingReport.Insight
        let unit: ActivityPeriod
        let period: String
        var categories: [SpendingReport.CategoryTotal] = []
    }

    private var weekOf: String { String(starhash: "In the week of \(SpendingReport.dayText(.now))") }
    private var monthIn: String {
        String(starhash: "In \(ActivityPeriod.month.name(for: .now, calendar: .current, locale: .starhash, inSentence: true))")
    }

    private var samples: [Sample] {
        switch page {
        case 0:
            [
                Sample(id: "more, week, short", insight: .more(category: .restaurant, extra: 1_000, usual: 4_000, fewerPayments: 1), unit: .week, period: String(starhash: "This week")),
                Sample(id: "more, month", insight: .more(category: .groceries, extra: 245_000, usual: 90_000, fewerPayments: 3), unit: .month, period: String(starhash: "This month")),
                Sample(id: "more, year, longest", insight: .more(category: .electricity, extra: 9_999_999, usual: 9_999, fewerPayments: 120), unit: .year, period: String(starhash: "This year")),
            ]
        case 1:
            [
                Sample(id: "more, past week", insight: .more(category: .education, extra: 1_250_000, usual: 50_000, fewerPayments: 12), unit: .week, period: weekOf),
                Sample(id: "less, short", insight: .less(by: 500), unit: .week, period: String(starhash: "This week")),
                Sample(id: "less, past month, longest", insight: .less(by: 10_000_000), unit: .month, period: monthIn),
            ]
        case 2:
            [
                Sample(id: "share, one payment", insight: .share(category: .transport, share: 1), unit: .year, period: String(starhash: "In \("2025")"),
                       categories: [.init(category: .transport, total: 10_000_000, count: 1, share: 1)]),
                Sample(id: "share, many", insight: .share(category: .shopping, share: 0.07), unit: .month, period: String(starhash: "This month"),
                       categories: [.init(category: .shopping, total: 12_345_678, count: 1_234, share: 0.07)]),
                Sample(id: "share, past week", insight: .share(category: .health, share: 0.56), unit: .week, period: weekOf,
                       categories: [.init(category: .health, total: 91_480, count: 3, share: 0.56)]),
            ]
        default: []
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                ForEach(samples) { sample in
                    Text(sample.id)
                        .starhashFont(11, weight: .semibold)
                        .foregroundStyle(Color.starhashSecondaryText)
                        .padding(.horizontal, 4)
                    ReportSummary(insight: sample.insight, unit: sample.unit, categories: sample.categories, period: sample.period)
                }
                if page == 3 {
                    // Every category's name in a card's headline.
                    ForEach(TransactionCategory.allCases.filter { $0 != .ownAccounts }, id: \.self) { category in
                        ReportHeadline(
                            lead: String(starhash: "\(SpendingReport.shareText(0.56)) went to \(ReportSentence.coloured(category.title))"),
                            category: category
                        )
                    }
                    ReportHeadline(lead: String(starhash: "Your 3 largest came to \(ReportSentence.amount(29_999_997))"))
                    ReportHeadline(lead: SpendingReport.PaymentType.purchases.sentence(ReportSentence.amount(9_999_999)))
                }
            }
            .padding(.horizontal, StarHashMetrics.screenPadding)
            .padding(.top, 12)
        }
    }
}

#endif
