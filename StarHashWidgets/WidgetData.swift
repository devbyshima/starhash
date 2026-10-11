import Foundation
import StarHashKit
import WidgetKit

/// What the widget reads: the app's snapshot from the App Group, or the
/// placeholder (StarHash's own codes) without one.
enum WidgetData {
    static var appGroup: String? {
        let id = Bundle.main.object(forInfoDictionaryKey: "StarHashAppGroup") as? String ?? ""
        return id.isEmpty ? nil : id
    }

    static var snapshot: WidgetSnapshot {
        guard let appGroup, let defaults = UserDefaults(suiteName: appGroup),
              let snapshot = WidgetSnapshot.decode(defaults.data(forKey: WidgetSnapshot.key)) else { return .placeholder }
        return snapshot
    }
}

/// One moment of the Buy widget: the codes and the page it is on.
struct StarHashEntry: TimelineEntry {
    let date: Date
    let snapshot: WidgetSnapshot
    let page: Int
}

/// The codes change only in the app, which reloads the widget whenever it
/// writes a new snapshot, so the timeline is the one entry, now.
struct StarHashTimeline: TimelineProvider {
    func placeholder(in context: Context) -> StarHashEntry {
        StarHashEntry(date: .now, snapshot: .placeholder, page: 0)
    }

    func getSnapshot(in context: Context, completion: @escaping (StarHashEntry) -> Void) {
        completion(StarHashEntry(date: .now, snapshot: context.isPreview ? .placeholder : WidgetData.snapshot, page: WidgetChoices.buyPage))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<StarHashEntry>) -> Void) {
        let entry = StarHashEntry(date: .now, snapshot: WidgetData.snapshot, page: WidgetChoices.buyPage)
        completion(Timeline(entries: [entry], policy: .never))
    }
}
