import Foundation
import Testing
@testable import StarHashKit

struct PushTokenTests {
    @Test func aDeviceTokenIsKeptInHex() {
        let token = PushToken(deviceToken: Data([0x00, 0xAB, 0x10, 0xFF]), sandbox: true)
        #expect(token.hex == "00ab10ff")
        #expect(PushToken(state: token.state) == token)
        #expect(PushToken(state: "00ab10ff|nowhere") == nil)
        #expect(PushToken(state: "") == nil)
    }

    /// A provisioning profile as Xcode embeds it: the plist wrapped in its
    /// signature.
    private func profile(apsEnvironment: String?) -> Data {
        var entitlements: [String: Any] = ["application-identifier": "W46T258AXM.com.devbyshima.starhash"]
        if let apsEnvironment { entitlements["aps-environment"] = apsEnvironment }
        let plist = try! PropertyListSerialization.data(
            fromPropertyList: ["Name": "StarHash", "Entitlements": entitlements], format: .xml, options: 0
        )
        return Data([0x30, 0x82, 0x4E, 0x1F, 0x06, 0x09]) + plist + Data([0xA0, 0x82, 0x0D, 0x00])
    }

    @Test func aDevelopmentProfileMeansTheSandbox() {
        #expect(PushToken.isSandbox(provisioningProfile: profile(apsEnvironment: "development")))
        #expect(!PushToken.isSandbox(provisioningProfile: profile(apsEnvironment: "production")))
        // A profile without push, and TestFlight or the App Store, with none.
        #expect(!PushToken.isSandbox(provisioningProfile: profile(apsEnvironment: nil)))
        #expect(!PushToken.isSandbox(provisioningProfile: nil))
        #expect(!PushToken.isSandbox(provisioningProfile: Data("not a profile".utf8)))
    }
}
