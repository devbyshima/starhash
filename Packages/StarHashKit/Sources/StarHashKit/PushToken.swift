import Foundation

/// The token APNs gives this copy of StarHash, which the server needs to
/// wake it when a request comes (`STARHASH_PUSH` in project.yml, a paid
/// team only): in hex, as APNs takes it in a URL, and which of APNs's two
/// services it belongs to. A build Xcode signed for development gets a
/// sandbox token; TestFlight and the App Store get production ones, and
/// each service refuses the other's.
public struct PushToken: Equatable, Sendable {
    public var hex: String
    public var sandbox: Bool

    public init(hex: String, sandbox: Bool) {
        self.hex = hex.lowercased()
        self.sandbox = sandbox
    }

    /// The bytes `didRegisterForRemoteNotificationsWithDeviceToken` hands
    /// over.
    public init(deviceToken: Data, sandbox: Bool) {
        self.init(hex: deviceToken.map { String(format: "%02x", $0) }.joined(), sandbox: sandbox)
    }

    /// One line, as it is kept between launches.
    var state: String { "\(hex)|\(sandbox ? "sandbox" : "production")" }

    init?(state: String) {
        let parts = state.split(separator: "|")
        guard parts.count == 2, !parts[0].isEmpty, ["sandbox", "production"].contains(parts[1]) else { return nil }
        self.init(hex: String(parts[0]), sandbox: parts[1] == "sandbox")
    }

    /// Whether a build's tokens are the sandbox's, from its provisioning
    /// profile (`embedded.mobileprovision`, a signed plist): a development
    /// profile says `aps-environment` development. TestFlight and the App
    /// Store carry no profile, and their tokens are production's, as an ad
    /// hoc build's are.
    public static func isSandbox(provisioningProfile: Data?) -> Bool {
        guard let profile = provisioningProfile,
              let start = profile.range(of: Data("<?xml".utf8)),
              let end = profile.range(of: Data("</plist>".utf8), in: start.lowerBound..<profile.endIndex),
              let plist = try? PropertyListSerialization.propertyList(from: profile[start.lowerBound..<end.upperBound], format: nil),
              let entitlements = (plist as? [String: Any])?["Entitlements"] as? [String: Any]
        else { return false }
        return entitlements["aps-environment"] as? String == "development"
    }
}
