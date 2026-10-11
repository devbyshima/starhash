#if DEBUG
import StarHashKit
import SwiftUI
import WidgetKit

/// `-widgetGallery` (DEBUG): the Home Screen widgets at an iPhone's sizes,
/// 158 points square and 338 by 158, to look at and screenshot without
/// adding them to a Home Screen. Small Buy beside Scan to Pay, then medium
/// Buy with three codes, spread across the width, and with more than fit,
/// cut to the first four.
struct WidgetGallery: View {
    private let few = WidgetSnapshot(codes: Array(Self.codes.prefix(3)), wallet: .mtn, updatedAt: .now)
    private let many = WidgetSnapshot(codes: Self.codes, wallet: .mtn, updatedAt: .now)

    private static let codes = [
        USSDShortcut(name: "Airtime", code: "*182*2*1#", symbol: "phone.fill", isPinned: true),
        USSDShortcut(name: "Bundles", code: "*345#", symbol: "wifi", isPinned: true),
        USSDShortcut(name: "Cash Power", code: "*182*2*2*1#", symbol: "bolt.fill"),
        USSDShortcut(name: "Balance", code: "*182*6*1#", symbol: "banknote.fill"),
        USSDShortcut(name: "Water", code: "*182*3*1#", symbol: "drop.fill"),
        USSDShortcut(name: "Canal+", code: "*182*3*2#", symbol: "tv.fill"),
        USSDShortcut(name: "Cash out", code: "*182*7*2#", symbol: "banknote"),
    ]

    var body: some View {
        ScrollView {
            VStack(spacing: 22) {
                HStack(spacing: 22) {
                    card(width: 158, height: 158) { BuyWidgetView(snapshot: many, family: .systemSmall) }
                    card(width: 158, height: 158) { ScanToPayWidgetView() }
                }
                card(width: 338, height: 158) { BuyWidgetView(snapshot: few, family: .systemMedium) }
                card(width: 338, height: 158) { BuyWidgetView(snapshot: many, family: .systemMedium) }
            }
            .padding(.vertical, 24)
            .frame(maxWidth: .infinity)
        }
        .scrollIndicators(.hidden)
        .background(Color(light: .brandPaper, dark: .black).ignoresSafeArea())
    }

    /// A widget on its card, rounded as the Home Screen rounds it.
    private func card(width: CGFloat, height: CGFloat, @ViewBuilder content: () -> some View) -> some View {
        content()
            .frame(width: width, height: height)
            .background(Color.widgetCard)
            .clipShape(RoundedRectangle(cornerRadius: 23, style: .continuous))
            .shadow(color: .black.opacity(0.06), radius: 12, y: 4)
    }
}

extension View {
    /// Covers the app with the widget gallery when launched with
    /// `-widgetGallery`.
    func debugWidgetGallery() -> some View {
        overlay {
            if DebugLaunch.arguments.contains("-widgetGallery") {
                WidgetGallery()
            }
        }
    }
}
#endif
