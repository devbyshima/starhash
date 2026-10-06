import Foundation

/// Where a build of StarHash goes: dev for builds run from Xcode on `main`,
/// beta for TestFlight builds of a release branch, production for the App
/// Store. Stamped into Info.plist by the build configuration (Debug, Beta,
/// Release), so one binary always knows which it is.
public enum ReleaseChannel: String, CaseIterable, Sendable {
    case dev
    case beta
    case production

    /// The channel Info.plist names. A missing or unknown value, or a build
    /// setting left unexpanded, reads as production: a build that lost the
    /// key shows nothing unfinished.
    public init(infoValue: String?) {
        self = infoValue.flatMap(Self.init(rawValue:)) ?? .production
    }

    /// Dev and beta builds honour a flag switched on this device; the App
    /// Store build ignores it, so a switch left on by a tester can never
    /// reach the people it was kept from.
    public var allowsOverrides: Bool { self != .production }

    /// "Beta".
    public var title: String {
        switch self {
        case .dev: "Dev"
        case .beta: "Beta"
        case .production: "Production"
        }
    }
}

/// A feature that can ship dark: merged on `main` while unfinished, off
/// where it is not ready, and switched on channel by channel as it ripens
/// (`Rollout`). Once it is on everywhere, delete the flag and its checks.
public struct FeatureFlag: Hashable, Identifiable, Sendable {
    /// How far a flag reaches before anyone switches it on this device.
    /// Each step includes the ones before it: beta is dev and beta.
    public enum Rollout: Sendable {
        /// Nowhere; only a switch on a dev or beta device turns it on.
        case off
        /// Builds run from Xcode.
        case dev
        /// Dev builds and TestFlight.
        case beta
        /// Every build, the App Store's too: time to delete the flag.
        case everywhere
    }

    /// Stable and unique: it names the device's switch in UserDefaults.
    public let key: String
    public let title: String
    /// One line on what it turns on, for the Feature Flags page.
    public let detail: String
    public let rollout: Rollout

    public init(key: String, title: String, detail: String, rollout: Rollout) {
        self.key = key
        self.title = title
        self.detail = detail
        self.rollout = rollout
    }

    public var id: String { key }

    /// Where this device's switch is kept. A Debug launch argument with the
    /// same name sets it for one run: `-featureFlag.<key> YES`.
    public var defaultsKey: String { "featureFlag.\(key)" }

    /// On in this channel before any switch on the device.
    public func isOnByDefault(in channel: ReleaseChannel) -> Bool {
        switch rollout {
        case .off: false
        case .dev: channel == .dev
        case .beta: channel != .production
        case .everywhere: true
        }
    }

    /// On in this channel, with the device's switch (nil when untouched)
    /// taken into account where the channel allows it.
    public func isOn(in channel: ReleaseChannel, override: Bool?) -> Bool {
        if channel.allowsOverrides, let override { return override }
        return isOnByDefault(in: channel)
    }
}
