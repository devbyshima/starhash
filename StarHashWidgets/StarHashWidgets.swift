import AppIntents
import SwiftUI
import WidgetKit

/// StarHash's widgets: Buy's codes on the Home Screen, and Scan to Pay in
/// Control Center and on the Lock Screen. Buy's view is in `Views/`,
/// shared with the app's widget gallery (DEBUG).
@main
struct StarHashWidgets: WidgetBundle {
    var body: some Widget {
        BuyWidget()
        ScanToPayControl()
    }
}

/// Buy's codes, nothing else on the card: dial one in a tap, page through
/// the rest with More, all without opening StarHash.
struct BuyWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "BuyWidget", provider: StarHashTimeline()) { entry in
            BuyWidgetEntryView(entry: entry)
                .containerBackground(Color.widgetCard, for: .widget)
        }
        .configurationDisplayName("Buy")
        .description("Dial your Buy codes in a tap.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
        .contentMarginsDisabled()
    }
}

private struct BuyWidgetEntryView: View {
    let entry: StarHashEntry
    @Environment(\.widgetFamily) private var family

    var body: some View {
        BuyWidgetView(snapshot: entry.snapshot, family: family, page: entry.page)
    }
}

/// Scan to Pay as a control: opens StarHash's QR scanner, ready to pay.
struct ScanToPayControl: ControlWidget {
    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: "ScanToPayControl") {
            ControlWidgetButton(action: OpenScannerIntent()) {
                Label("Scan to Pay", systemImage: "qrcode.viewfinder")
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
    BuyWidget()
} timeline: {
    StarHashEntry(date: .now, snapshot: .placeholder, page: 0)
}
