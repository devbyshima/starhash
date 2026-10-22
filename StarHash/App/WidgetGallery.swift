#if DEBUG
import StarHashKit
import SwiftUI
import WidgetKit

/// `-widgetGallery` (DEBUG): the Home Screen widgets at an iPhone's sizes,
/// 158 points square and 338 by 158, to look at and screenshot without
/// adding them to a Home Screen, laid out as the owner's reference: the
/// medium tiles, the small tiles beside the small Quick Pay, then the
/// medium Quick Pay.
struct WidgetGallery: View {
    var body: some View {
        ScrollView {
            VStack(spacing: 22) {
                card(width: 338, height: 158) { ShortcutTilesWidgetView(family: .systemMedium, wallet: .mtn) }
                HStack(spacing: 22) {
                    card(width: 158, height: 158) { ShortcutTilesWidgetView(family: .systemSmall, wallet: .mtn) }
                    card(width: 158, height: 158) { QuickPayWidgetView(family: .systemSmall, wallet: .mtn) }
                }
                card(width: 338, height: 158) { QuickPayWidgetView(family: .systemMedium, wallet: .mtn) }
            }
            .padding(.vertical, 24)
            .frame(maxWidth: .infinity)
        }
        .scrollIndicators(.hidden)
        .background(Color(light: .brandCloud, dark: .black).ignoresSafeArea())
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
