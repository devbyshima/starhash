#if DEBUG || WIDGET_EXTENSION
import StarHashKit
import SwiftUI
import WidgetKit

/// What a widget's tile or circle does: open StarHash on Pay, its scanner,
/// Buy or Activity, or dial the wallet's balance code.
enum WidgetAction: CaseIterable {
    case pay, scan, balance, buy, activity

    var title: LocalizedStringResource {
        switch self {
        case .pay: "Pay"
        case .scan: "Scan"
        case .balance: "Balance"
        case .buy: "Buy"
        case .activity: "Activity"
        }
    }

    /// Its icon, by the SF Symbol's name, drawn in outline as the
    /// reference's are.
    var symbol: String {
        switch self {
        case .pay: "number.square.fill"
        case .scan: "qrcode"
        case .balance: "banknote.fill"
        case .buy: "bag.fill"
        case .activity: "clock.fill"
        }
    }

    /// The StarHash link it opens; Balance's carries the wallet's code.
    func link(wallet: Recipient.Network) -> String {
        switch self {
        case .pay: "starhash://pay"
        case .scan: "starhash://scan"
        case .buy: "starhash://buy"
        case .activity: "starhash://activity"
        case .balance:
            "starhash://dial?code=" + (USSD.balance(for: wallet).addingPercentEncoding(withAllowedCharacters: .alphanumerics) ?? "")
        }
    }
}

/// The reference's grid of tiles, each an icon top left and its name at the
/// foot: two stacked on the small widget (Pay and Scan), two by two on the
/// medium one (Pay, Scan, Balance and Activity).
struct ShortcutTilesWidgetView: View {
    let family: WidgetFamily
    let wallet: Recipient.Network

    var body: some View {
        Group {
            if family == .systemSmall {
                VStack(spacing: WidgetMetrics.gap) {
                    tile(.pay)
                    tile(.scan)
                }
            } else {
                Grid(horizontalSpacing: WidgetMetrics.gap, verticalSpacing: WidgetMetrics.gap) {
                    GridRow {
                        tile(.pay)
                        tile(.scan)
                    }
                    GridRow {
                        tile(.balance)
                        tile(.activity)
                    }
                }
            }
        }
        .padding(WidgetMetrics.padding)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func tile(_ action: WidgetAction) -> some View {
        Button(intent: OpenStarHashIntent(link: action.link(wallet: wallet))) {
            VStack(alignment: .leading, spacing: 0) {
                // In a box of one height, so every name sits at the same
                // size and place whatever its icon's shape.
                Image(symbol: action.symbol, outline: true)
                    .font(.system(size: 19, weight: .semibold))
                    .frame(height: 20, alignment: .leading)
                    .accessibilityHidden(true)
                Spacer(minLength: 0)
                Text(action.title)
                    .font(.widget(15))
                    .lineLimit(1)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .foregroundStyle(Color.widgetText)
            .padding(.horizontal, 12)
            .padding(.vertical, 9)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
            .background(Color.widgetChip, in: RoundedRectangle(cornerRadius: WidgetMetrics.tileRadius, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(action.title))
    }
}

/// The reference's pill and circles: the StarHash mark and "Pay" in a pill
/// across the top, which opens Pay, and circles under it, two on the small
/// widget (Scan and Balance) and four on the medium one (Scan, Balance, Buy
/// and Activity).
struct QuickPayWidgetView: View {
    let family: WidgetFamily
    let wallet: Recipient.Network

    private var circles: [WidgetAction] {
        family == .systemSmall ? [.scan, .balance] : [.scan, .balance, .buy, .activity]
    }

    var body: some View {
        VStack(spacing: WidgetMetrics.gap) {
            pill
            HStack(spacing: WidgetMetrics.gap) {
                ForEach(Array(circles.enumerated()), id: \.offset) { index, action in
                    if index > 0, family != .systemSmall { Spacer(minLength: 0) }
                    circle(action)
                }
            }
        }
        .padding(WidgetMetrics.padding)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var pill: some View {
        Button(intent: OpenStarHashIntent(link: WidgetAction.pay.link(wallet: wallet))) {
            HStack(spacing: 12) {
                StarHashMark(size: 30)
                Text(family == .systemSmall ? "Pay" : "Pay someone")
                    .font(.widget(19))
                    .foregroundStyle(Color.widgetSecondaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 14)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.widgetChip, in: Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text("Pay"))
    }

    private func circle(_ action: WidgetAction) -> some View {
        Button(intent: OpenStarHashIntent(link: action.link(wallet: wallet))) {
            Image(symbol: action.symbol, outline: true)
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(Color.widgetText)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.widgetChip, in: Circle())
                .aspectRatio(1, contentMode: .fit)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(action.title))
    }
}

/// The reference's measurements on an iPhone's widgets (158 square, 338 by
/// 158): 16 points in, 8 between tiles, so each tile or circle is about 59
/// tall.
enum WidgetMetrics {
    static let padding: CGFloat = 16
    static let gap: CGFloat = 8
    static let tileRadius: CGFloat = 14
}

extension Font {
    /// Space Grotesk at a widget's size, scaling with Dynamic Type as the text
    /// around it does.
    static func widget(_ size: CGFloat, _ weight: Font.Weight = .medium) -> Font {
        .custom(Font.starhashFamily, size: size, relativeTo: .starhashNearest(to: size)).weight(weight)
    }
}
#endif
