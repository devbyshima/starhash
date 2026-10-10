#if DEBUG || WIDGET_EXTENSION
import StarHashKit
import SwiftUI
import WidgetKit

/// Buy on the Home Screen: a code's symbol and its name, nothing round them,
/// each dialling its code in a tap through iOS's call prompt, as the app's
/// do. The snapshot already puts the pinned codes first, so the small
/// widget is the first code, the whole widget dialling it (a small widget
/// takes one link), and the medium one is the first four.
struct BuyWidgetView: View {
    let snapshot: WidgetSnapshot
    let family: WidgetFamily

    private var codes: [USSDShortcut] { snapshot.codes }

    var body: some View {
        Group {
            switch family {
            case .systemSmall: small
            default: medium
            }
        }
        .foregroundStyle(Color.widgetText)
        .dynamicTypeSize(...DynamicTypeSize.xLarge)
        .widgetURL(family == .systemSmall ? codes.first.flatMap { USSD.telURL(for: $0.code) } : nil)
    }

    // MARK: Sizes

    @ViewBuilder
    private var small: some View {
        if let code = codes.first {
            SmallWidgetLabel(symbol: code.symbol ?? "number", name: Text(code.name))
                .accessibilityHint(String(localized: "Dials \(code.code)"))
        }
    }

    /// Up to four codes side by side, each in an equal share of the width,
    /// so three or fewer spread out rather than leave a gap.
    private var medium: some View {
        HStack(spacing: 4) {
            ForEach(codes.prefix(4)) { code in
                Link(destination: USSD.telURL(for: code.code) ?? URL(string: "starhash://buy")!) {
                    VStack(spacing: 10) {
                        WidgetSymbol(name: code.symbol ?? "number", size: 30)
                        Text(code.name)
                            .font(.widget(13, .bold))
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                .accessibilityLabel(code.name)
                .accessibilityHint(String(localized: "Dials \(code.code)"))
            }
        }
        .padding(.horizontal, 12)
    }
}

/// A small widget's one thing, the symbol over its name in the middle of
/// the card, shared by Buy and Scan to Pay so the two sit alike side by
/// side.
struct SmallWidgetLabel: View {
    let symbol: String
    let name: Text

    var body: some View {
        VStack(spacing: 12) {
            WidgetSymbol(name: symbol, size: 44)
            name
                .font(.widget(17, .bold))
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.75)
        }
        .foregroundStyle(Color.widgetText)
        .padding(16)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityElement(children: .combine)
    }
}

/// A symbol in the accent with nothing behind it, in a box of a fixed
/// height so names under symbols of different shapes line up.
struct WidgetSymbol: View {
    let name: String
    let size: CGFloat

    var body: some View {
        Image(systemName: name)
            .font(.system(size: size, weight: .semibold))
            .foregroundStyle(Color.widgetAccent)
            .frame(height: size * 1.15)
            .accessibilityHidden(true)
    }
}

extension Font {
    /// Space Grotesk at a widget's size, scaling with Dynamic Type as the
    /// text around it does.
    static func widget(_ size: CGFloat, _ weight: Font.Weight = .medium) -> Font {
        .custom(Font.starhashFamily, size: size, relativeTo: .starhashNearest(to: size)).weight(weight)
    }
}
#endif
