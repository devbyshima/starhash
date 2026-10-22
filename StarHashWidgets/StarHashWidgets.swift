import AppIntents
import SwiftUI
import WidgetKit

/// StarHash's widgets, after the owner's reference: two kinds, each small
/// and medium, so four in all, on the Home Screen; and Scan to Pay in
/// Control Center and on the Lock Screen. The Home Screen views are in
/// `Views/`, shared with the app's widget gallery (DEBUG).
@main
struct StarHashWidgets: WidgetBundle {
    var body: some Widget {
        ShortcutTilesWidget()
        QuickPayWidget()
        ScanToPayControl()
    }
}

/// Tiles: Pay and Scan on the small one, Pay, Scan, Balance and Activity on
/// the medium one.
struct ShortcutTilesWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "ShortcutTilesWidget", provider: StarHashTimeline()) { entry in
            ShortcutTilesEntryView(entry: entry)
                .containerBackground(Color.widgetCard, for: .widget)
        }
        .configurationDisplayName("StarHash")
        .description("Pay, scan, check your balance and see your activity in a tap.")
        .supportedFamilies([.systemSmall, .systemMedium])
        .contentMarginsDisabled()
    }
}

private struct ShortcutTilesEntryView: View {
    let entry: StarHashEntry
    @Environment(\.widgetFamily) private var family

    var body: some View {
        ShortcutTilesWidgetView(family: family, wallet: entry.snapshot.wallet)
    }
}

/// Pay in a pill, with Scan and Balance (and on the medium one Buy and
/// Activity) as circles under it.
struct QuickPayWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "QuickPayWidget", provider: StarHashTimeline()) { entry in
            QuickPayEntryView(entry: entry)
                .containerBackground(Color.widgetCard, for: .widget)
        }
        .configurationDisplayName("Quick Pay")
        .description("Start a payment, or scan, from your Home Screen.")
        .supportedFamilies([.systemSmall, .systemMedium])
        .contentMarginsDisabled()
    }
}

private struct QuickPayEntryView: View {
    let entry: StarHashEntry
    @Environment(\.widgetFamily) private var family

    var body: some View {
        QuickPayWidgetView(family: family, wallet: entry.snapshot.wallet)
    }
}

/// Scan to Pay as a control: opens StarHash's QR scanner, ready to pay.
struct ScanToPayControl: ControlWidget {
    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: "ScanToPayControl") {
            ControlWidgetButton(action: OpenScannerIntent()) {
                // A control shows SF Symbols and custom symbols named in
                // the asset catalog, so StarHash's scan icon by its name.
                Label("Scan to Pay", image: StarIcon.scan.assetName)
            }
        }
        .displayName("Scan to Pay")
        .description("Opens StarHash's scanner to pay a QR code.")
    }
}

/// Opens StarHash on its scanner.
struct OpenScannerIntent: AppIntent {
    static let title: LocalizedStringResource = "Scan to Pay"
    static let isDiscoverable = false
    static let openAppWhenRun = true

    func perform() async throws -> some IntentResult & OpensIntent {
        .result(opensIntent: OpenURLIntent(URL(string: "starhash://scan")!))
    }
}

#Preview(as: .systemMedium) {
    ShortcutTilesWidget()
} timeline: {
    StarHashEntry(date: .now, snapshot: .placeholder)
}
