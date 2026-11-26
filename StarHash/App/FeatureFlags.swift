import StarHashKit
import SwiftUI

extension FeatureFlag {
    /// Every flag in the app, as Feature Flags lists them. Add one here with
    /// `rollout: .dev` when unfinished work is merged on `main`, and delete
    /// it with its checks once it ships to everyone. A release branch is cut
    /// with whatever rollouts main has, so check them before cutting one.
    ///
    ///     static let splitBill = FeatureFlag(
    ///         key: "splitBill", title: "Split a bill",
    ///         detail: "Pay part of a total to each of several people",
    ///         rollout: .dev
    ///     )
    static let all: [FeatureFlag] = [.peopleNearby, .requestsAnywhere, .tapToRequest]

    /// StarHash users close by on Pay, paid with a tap (`PeopleNearby`).
    static let peopleNearby = FeatureFlag(
        key: "peopleNearby", title: "People Nearby",
        detail: "StarHash users close by show up on Pay, and a tap pays them",
        rollout: .dev
    )

    /// Requests to StarHash users anywhere, through the server, sealed
    /// (`RequestsAnywhere`). Only with People Nearby on too, which brings
    /// Request to Pay.
    static let requestsAnywhere = FeatureFlag(
        key: "requestsAnywhere", title: "Requests Anywhere",
        detail: "Ask StarHash users who aren't nearby, through StarHash's server",
        rollout: .dev
    )

    /// Asking for money by holding the iPhone to another (`TapToRequest`).
    /// Only with People Nearby on too, whose connection it travels over.
    static let tapToRequest = FeatureFlag(
        key: "tapToRequest", title: "Tap to Request",
        detail: "Ask for money by holding your iPhone to theirs",
        rollout: .dev
    )
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

    /// Requests through the server: both flags, since Request on Pay comes
    /// with People Nearby.
    static var requestsAnywhere: Bool {
        isOn(.peopleNearby) && isOn(.requestsAnywhere)
    }

    /// Requests by a tap: both flags, since the tap travels over People
    /// Nearby's connection.
    static var tapToRequest: Bool {
        isOn(.peopleNearby) && isOn(.tapToRequest)
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

    /// Whether Feature Flags shows under About StarHash: the dev build, once
    /// there is a flag to show.
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
