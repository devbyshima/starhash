import AppIntents
import SwiftUI
import WidgetKit

/// StarHash's widgets: Buy's codes and Scan to Pay on the Home Screen, and
/// Scan to Pay again in Control Center and on the Lock Screen. The Home
/// Screen views are in `Views/`, shared with the app's widget gallery
/// (DEBUG).
@main
struct StarHashWidgets: WidgetBundle {
    var body: some Widget {
        BuyWidget()
        ScanToPayWidget()
        ScanToPayControl()
    }
}

/// Buy's codes, nothing else on the card: dial one in a tap without
/// opening StarHash.
struct BuyWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "BuyWidget", provider: StarHashTimeline()) { entry in
            BuyWidgetEntryView(entry: entry)
                .containerBackground(Color.widgetCard, for: .widget)
        }
        .configurationDisplayName("Buy")
        .description("Dial your codes in a tap.")
        .supportedFamilies([.systemSmall, .systemMedium])
        .contentMarginsDisabled()
    }
}

private struct BuyWidgetEntryView: View {
    let entry: StarHashEntry
    @Environment(\.widgetFamily) private var family

    var body: some View {
        BuyWidgetView(snapshot: entry.snapshot, family: family)
    }
}

/// Scan to Pay as a small widget, on the same card as Buy's: one tap opens
/// StarHash's scanner.
struct ScanToPayWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "ScanToPayWidget", provider: ScanToPayTimeline()) { _ in
            ScanToPayWidgetView()
                .containerBackground(Color.widgetCard, for: .widget)
        }
        .configurationDisplayName("Scan to Pay")
        .description("Open the scanner to pay a QR code.")
        .supportedFamilies([.systemSmall])
        .contentMarginsDisabled()
    }
}

/// Scan to Pay shows nothing that changes, so its timeline is one entry
/// that stands for good.
private struct ScanToPayTimeline: TimelineProvider {
    struct Entry: TimelineEntry {
        let date: Date
    }

    func placeholder(in context: Context) -> Entry {
        Entry(date: .now)
    }

    func getSnapshot(in context: Context, completion: @escaping (Entry) -> Void) {
        completion(Entry(date: .now))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<Entry>) -> Void) {
        completion(Timeline(entries: [Entry(date: .now)], policy: .never))
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
    StarHashEntry(date: .now, snapshot: .placeholder)
}
