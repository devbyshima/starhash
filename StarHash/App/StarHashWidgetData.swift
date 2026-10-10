import Foundation
import StarHashKit
import WidgetKit

/// Hands the widgets what they show (`WidgetSnapshot`), through the App
/// Group the app and its widget extension share. App Groups need a paid
/// developer team, so a build signed by a free one has none
/// (`STARHASH_APP_GROUP` empty in project.yml): then nothing is shared and
/// the widgets show Buy's default codes.
@MainActor
enum StarHashWidgetData {
    /// The App Group's id from Info.plist, nil when the build has none.
    static var appGroup: String? {
        let id = Bundle.main.object(forInfoDictionaryKey: "StarHashAppGroup") as? String ?? ""
        return id.isEmpty ? nil : id
    }

    /// Writes Buy's codes and the wallet as they are now, and asks the
    /// widget to draw them.
    static func publish(shortcuts: USSDShortcutList) {
        guard let appGroup, let defaults = UserDefaults(suiteName: appGroup) else { return }
        let snapshot = WidgetSnapshot.make(shortcuts: shortcuts.shortcuts, wallet: StarHashPreferences.wallet)
        defaults.set(snapshot.encoded(), forKey: WidgetSnapshot.key)
        WidgetCenter.shared.reloadAllTimelines()
    }

    /// Delete All Data: the widgets forget too.
    static func erase() {
        guard let appGroup else { return }
        UserDefaults(suiteName: appGroup)?.removeObject(forKey: WidgetSnapshot.key)
        WidgetCenter.shared.reloadAllTimelines()
    }
}
