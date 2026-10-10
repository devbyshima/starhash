#if DEBUG || WIDGET_EXTENSION
import StarHashKit
import SwiftUI
import WidgetKit

/// Buy on the Home Screen, nothing on it but the codes: each tile dials its
/// code in a tap through iOS's call prompt, as the app's do, pinned codes
/// first. With more codes than fit, the last tile is More, which pages
/// round without opening StarHash. The large widget adds Balance and Scan
/// to Pay; the small one is one code at a time, the whole widget dialling
/// it (a small widget takes one link), with its own arrow to the next.
struct BuyWidgetView: View {
    let snapshot: WidgetSnapshot
    let family: WidgetFamily
    var page = 0

    private var codes: [USSDShortcut] { snapshot.codes }

    /// The tiles the widget has room for.
    private var slots: Int {
        switch family {
        case .systemSmall: 1
        case .systemMedium: 4
        default: 6
        }
    }

    /// Codes on a page: every slot, unless they do not all fit, when the
    /// last slot is More.
    private var perPage: Int {
        codes.count > slots && family != .systemSmall ? slots - 1 : slots
    }

    private var pages: Int { max(1, Int((Double(codes.count) / Double(perPage)).rounded(.up))) }

    private var shown: [USSDShortcut] {
        Array(codes.dropFirst((page % pages) * perPage).prefix(perPage))
    }

    var body: some View {
        Group {
            switch family {
            case .systemSmall: small
            case .systemLarge: large
            default: grid(rows: 2)
            }
        }
        .foregroundStyle(Color.widgetText)
        .dynamicTypeSize(...DynamicTypeSize.xLarge)
        .widgetURL(family == .systemSmall ? shown.first.flatMap { USSD.telURL(for: $0.code) } : nil)
    }

    // MARK: Sizes

    /// The small widget is its one code: symbol, name and code, with the
    /// arrow to the next code in its corner when there are more.
    private var small: some View {
        ZStack(alignment: .topTrailing) {
            if let code = shown.first {
                VStack(alignment: .leading, spacing: 3) {
                    symbol(code, size: 40, disc: .widgetChip)
                    Spacer(minLength: 0)
                    Text(code.name)
                        .font(.widget(17, .bold))
                        .lineLimit(2)
                        .minimumScaleFactor(0.75)
                    Text(code.code)
                        .font(.widget(12))
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
                .padding(16)
                .accessibilityElement(children: .combine)
                .accessibilityHint(String(localized: "Dials \(code.code)"))
            }
            if pages > 1 {
                Button(intent: NextCodesPageIntent(pages: pages)) {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 13, weight: .bold))
                        .frame(width: 32, height: 32)
                        .background(Color.widgetChip, in: Circle())
                }
                .buttonStyle(.plain)
                .padding(12)
                .accessibilityLabel(String(localized: "More codes"))
            }
        }
    }

    private var large: some View {
        VStack(spacing: 8) {
            grid(rows: 3, padded: false)
            HStack(spacing: 8) {
                Link(destination: USSD.telURL(for: USSD.balance(for: snapshot.wallet)) ?? URL(string: "starhash://pay")!) {
                    capsule(String(localized: "Balance"), symbol: "wallet.bifold")
                }
                Link(destination: URL(string: "starhash://scan")!) {
                    capsule(String(localized: "Scan to Pay"), symbol: "qrcode.viewfinder")
                }
            }
            .frame(height: 44)
        }
        .padding(12)
    }

    /// The codes two to a row, filling the widget, More in the last place
    /// when they do not all fit.
    private func grid(rows: Int, padded: Bool = true) -> some View {
        let items = shown.map(Slot.code) + (pages > 1 ? [Slot.more] : [])
        return VStack(spacing: 8) {
            ForEach(0..<rows, id: \.self) { row in
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
        .padding(padded ? 12 : 0)
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
                    symbol(code, size: 32)
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
                    Image(systemName: "chevron.right")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(Color.widgetAccent)
                        .frame(width: 32, height: 32)
                        .background(Color.widgetCard, in: Circle())
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

    /// A code's symbol in the blue, on a disc of the card's colour (of a
    /// tile's, on the small widget, which has no tiles).
    private func symbol(_ code: USSDShortcut, size: CGFloat, disc: Color = .widgetCard) -> some View {
        Image(systemName: code.symbol ?? "number")
            .font(.system(size: size * 0.42, weight: .semibold))
            .foregroundStyle(Color.widgetAccent)
            .frame(width: size, height: size)
            .background(disc, in: Circle())
            .accessibilityHidden(true)
    }

    private func capsule(_ title: String, symbol: String) -> some View {
        Label(title, systemImage: symbol)
            .font(.widget(13, .semibold))
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.widgetChip, in: Capsule())
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
