import AppIntents
import StarHashKit
import SwiftUI
import WidgetKit

/// Buy's codes as tiles, two on the small widget and four on the medium
/// one, each dialling its code in a tap. Which codes is the owner's to
/// choose (Edit Widget); a tile they leave unchosen, or whose code is gone
/// from Buy, takes the next in Buy's order, pinned first.
struct BuyCodesWidget: Widget {
    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: "BuyCodesWidget", intent: BuyCodesConfiguration.self, provider: BuyCodesTimeline()) { entry in
            BuyCodesEntryView(entry: entry)
                .containerBackground(Color.widgetCard, for: .widget)
        }
        .configurationDisplayName("Buy")
        .description("Dial your codes in a tap.")
        .supportedFamilies([.systemSmall, .systemMedium])
        .contentMarginsDisabled()
    }
}

private struct BuyCodesEntryView: View {
    let entry: BuyCodesEntry
    @Environment(\.widgetFamily) private var family

    var body: some View {
        BuyTilesWidgetView(family: family, codes: entry.codes)
    }
}

/// What the owner chose in Edit Widget: the codes, in their order, as many
/// as the widget has tiles.
struct BuyCodesConfiguration: WidgetConfigurationIntent {
    static let title: LocalizedStringResource = "Buy Codes"
    static var description: IntentDescription { IntentDescription("Choose the codes the widget dials.") }

    @Parameter(title: "Codes", size: [.systemSmall: 2, .systemMedium: 4])
    var codes: [BuyCodeEntity]?
}

/// One of Buy's codes, as Edit Widget lists them: its name, the code under
/// it, and its symbol.
struct BuyCodeEntity: AppEntity {
    static var typeDisplayRepresentation: TypeDisplayRepresentation { "Buy Code" }
    static let defaultQuery = BuyCodeQuery()

    let id: String
    let name: String
    let code: String
    let symbol: String

    init(_ shortcut: USSDShortcut) {
        id = shortcut.id.uuidString
        name = shortcut.name
        code = shortcut.code
        symbol = shortcut.symbol ?? "number"
    }

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(
            title: "\(name)",
            subtitle: "\(code)",
            image: StarIcon(symbol: symbol).map { .init(named: $0.assetName) }
        )
    }
}

/// Buy's codes, from the app's snapshot (or StarHash's own without one).
struct BuyCodeQuery: EntityQuery {
    func entities(for identifiers: [BuyCodeEntity.ID]) async throws -> [BuyCodeEntity] {
        let codes = WidgetData.snapshot.codes
        return identifiers.compactMap { id in codes.first { $0.id.uuidString == id }.map(BuyCodeEntity.init) }
    }

    func suggestedEntities() async throws -> [BuyCodeEntity] {
        WidgetData.snapshot.codes.map(BuyCodeEntity.init)
    }
}

struct BuyCodesEntry: TimelineEntry {
    let date: Date
    /// The codes to show, in order: the chosen ones, else Buy's first.
    let codes: [USSDShortcut]
}

/// Buy's codes change only in the app, which reloads the widgets whenever
/// it writes a new snapshot, so the timeline is the one entry, now.
struct BuyCodesTimeline: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> BuyCodesEntry {
        BuyCodesEntry(date: .now, codes: WidgetSnapshot.placeholder.codes)
    }

    func snapshot(for configuration: BuyCodesConfiguration, in context: Context) async -> BuyCodesEntry {
        entry(for: configuration)
    }

    func timeline(for configuration: BuyCodesConfiguration, in context: Context) async -> Timeline<BuyCodesEntry> {
        Timeline(entries: [entry(for: configuration)], policy: .never)
    }

    /// The chosen codes as they are now (renamed or given a new symbol
    /// since), leaving out any deleted, then Buy's others in its order, so
    /// a tile left unchosen still dials something.
    private func entry(for configuration: BuyCodesConfiguration) -> BuyCodesEntry {
        let codes = WidgetData.snapshot.codes
        let chosen = (configuration.codes ?? []).compactMap { entity in codes.first { $0.id.uuidString == entity.id } }
        let rest = codes.filter { code in !chosen.contains { $0.id == code.id } }
        return BuyCodesEntry(date: .now, codes: chosen + rest)
    }
}
