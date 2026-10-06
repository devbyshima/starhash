import StarHashKit
import SwiftUI

extension FeatureFlag {
    /// Every flag in the app, as Feature Flags lists them. Add one here with
    /// `rollout: .dev` when unfinished work is merged on `main`, move it to
    /// `.beta` once testers should see it, and delete it with its checks once
    /// it ships to everyone. A release branch is cut with whatever rollouts
    /// main has, so check them before cutting one.
    ///
    ///     static let splitBill = FeatureFlag(
    ///         key: "splitBill", title: "Split a bill",
    ///         detail: "Pay part of a total to each of several people",
    ///         rollout: .dev
    ///     )
    static let all: [FeatureFlag] = []
}

extension ReleaseChannel {
    /// This build's channel, from Info.plist's `StarHashChannel`, which the
    /// build configuration sets (`STARHASH_CHANNEL` in project.yml).
    static let current = ReleaseChannel(
        infoValue: Bundle.main.object(forInfoDictionaryKey: "StarHashChannel") as? String
    )
}

enum FeatureFlags {
    /// A flag's state outside a view, read afresh each time.
    static func isOn(_ flag: FeatureFlag) -> Bool {
        flag.isOn(in: .current, override: override(for: flag))
    }

    /// This device's switch for the flag, nil if never touched. A Debug
    /// launch argument arrives as the text "YES" or "NO", which
    /// `bool(forKey:)` reads as it reads a saved switch.
    static func override(for flag: FeatureFlag) -> Bool? {
        let defaults = UserDefaults.standard
        guard defaults.object(forKey: flag.defaultsKey) != nil else { return nil }
        return defaults.bool(forKey: flag.defaultsKey)
    }

    /// Back to each flag's rollout.
    static func resetOverrides() {
        for flag in FeatureFlag.all {
            UserDefaults.standard.removeObject(forKey: flag.defaultsKey)
        }
    }

    /// Whether Feature Flags shows under About StarHash: dev and beta
    /// builds, once there is a flag to show.
    static var showsPage: Bool {
        ReleaseChannel.current.allowsOverrides && !FeatureFlag.all.isEmpty
    }
}

/// A flag's state in a view, redrawn as its switch changes:
///
///     @FeatureFlagged(.splitBill) private var splitsBills
@propertyWrapper
struct FeatureFlagged: DynamicProperty {
    private let flag: FeatureFlag
    @AppStorage private var override: Bool?

    init(_ flag: FeatureFlag) {
        self.flag = flag
        _override = AppStorage(flag.defaultsKey)
    }

    var wrappedValue: Bool {
        // A launch argument's "YES" is text, which a Bool? AppStorage
        // reads as nil.
        flag.isOn(in: .current, override: override ?? FeatureFlags.override(for: flag))
    }
}
