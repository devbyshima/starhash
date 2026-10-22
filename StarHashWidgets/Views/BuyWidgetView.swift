#if DEBUG || WIDGET_EXTENSION
import StarHashKit
import SwiftUI
import WidgetKit

/// Buy on the Home Screen. The small widget is the first code, its symbol
/// and its name, the whole widget dialling it (a small widget takes one
/// link); the snapshot already puts the pinned codes first. The medium one
/// is four tiles, each a code's symbol, name and code, dialling it in a
/// tap through iOS's call prompt, as the app's do; with more codes than
/// fit, the last tile is More, which pages round without opening StarHash.
/// The symbols stand alone in the accent, with nothing behind them.
struct BuyWidgetView: View {
    let snapshot: WidgetSnapshot
    let family: WidgetFamily
    var page = 0

    private var codes: [USSDShortcut] { snapshot.codes }

    /// The medium widget's tiles.
    private let slots = 4

    /// Codes on a page: every slot, unless they do not all fit, when the
    /// last slot is More.
    private var perPage: Int { codes.count > slots ? slots - 1 : slots }

    private var pages: Int { max(1, Int((Double(codes.count) / Double(perPage)).rounded(.up))) }

    private var shown: [USSDShortcut] {
        Array(codes.dropFirst((page % pages) * perPage).prefix(perPage))
    }

    var body: some View {
        Group {
            switch family {
            case .systemSmall: small
            default: grid
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

    /// The codes two to a row, filling the widget, More in the last place
    /// when they do not all fit.
    private var grid: some View {
        let items = shown.map(Slot.code) + (pages > 1 ? [Slot.more] : [])
        return VStack(spacing: 8) {
            ForEach(0..<2, id: \.self) { row in
                HStack(spacing: 8) {
                    ForEach(0..<2, id: \.self) { column in
                        let index = row * 2 + column
                        if index < items.count {
                            tile(items[index])
                        } else {
                            Color.clear.frame(maxWidth: .infinity, maxHeight: .infinity)
                        }
                    }
                }
            }
        }
        .padding(12)
    }

    // MARK: Tiles

    private enum Slot {
        case code(USSDShortcut)
        case more
    }

    @ViewBuilder
    private func tile(_ slot: Slot) -> some View {
        switch slot {
        case .code(let code):
            Link(destination: USSD.telURL(for: code.code) ?? URL(string: "starhash://buy")!) {
                HStack(spacing: 9) {
                    WidgetSymbol(name: code.symbol ?? "number", size: 20)
                        .frame(width: 32)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(code.name)
                            .font(.widget(14, .bold))
                            .lineLimit(1)
                            .minimumScaleFactor(0.75)
                        Text(code.code)
                            .font(.widget(10.5))
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                    }
                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 10)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.widgetChip, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
            .accessibilityLabel(code.name)
            .accessibilityHint(String(localized: "Dials \(code.code)"))
        case .more:
            // The next page, here in the widget: StarHash stays shut.
            Button(intent: NextCodesPageIntent(pages: pages)) {
                HStack(spacing: 9) {
                    WidgetSymbol(name: "chevron.right", size: 16)
                        .frame(width: 32)
                    Text("\(page % pages + 1)/\(pages)")
                        .font(.widget(14, .bold))
                        .monospacedDigit()
                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 10)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.widgetChip, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
            .buttonStyle(.plain)
            .accessibilityLabel(String(localized: "More codes"))
        }
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
        Image(symbol: name)
            .font(.system(size: size, weight: .semibold))
            .foregroundStyle(Color.widgetAccent)
            .frame(height: size * 1.15)
            .accessibilityHidden(true)
    }
}

extension Font {
    /// Melange at a widget's size, scaling with Dynamic Type as the text
    /// around it does.
    static func widget(_ size: CGFloat, _ weight: Font.Weight = .medium) -> Font {
        .custom(StarHashTypeface.melange(weight), size: size, relativeTo: .starhashNearest(to: size))
    }
}
#endif
