import Testing
@testable import StarHashKit

struct FeatureFlagTests {
    private func flag(_ rollout: FeatureFlag.Rollout) -> FeatureFlag {
        FeatureFlag(key: "sample", title: "Sample", detail: "A flag for the tests", rollout: rollout)
    }

    private func channels(where isOn: (ReleaseChannel) -> Bool) -> [ReleaseChannel] {
        ReleaseChannel.allCases.filter(isOn)
    }

    @Test func eachRolloutReachesItsChannelsAndTheOnesBefore() {
        #expect(channels { flag(.off).isOnByDefault(in: $0) } == [])
        #expect(channels { flag(.dev).isOnByDefault(in: $0) } == [.dev])
        #expect(channels { flag(.beta).isOnByDefault(in: $0) } == [.dev, .beta])
        #expect(channels { flag(.everywhere).isOnByDefault(in: $0) } == [.dev, .beta, .production])
    }

    @Test func aSwitchOnTheDeviceWinsInDevAndBeta() {
        #expect(flag(.off).isOn(in: .dev, override: true))
        #expect(flag(.off).isOn(in: .beta, override: true))
        #expect(!flag(.beta).isOn(in: .beta, override: false))
        #expect(!flag(.everywhere).isOn(in: .dev, override: false))
    }

    @Test func theAppStoreBuildIgnoresTheSwitch() {
        #expect(!flag(.off).isOn(in: .production, override: true))
        #expect(!flag(.beta).isOn(in: .production, override: true))
        #expect(flag(.everywhere).isOn(in: .production, override: false))
    }

    @Test func noSwitchMeansTheRollout() {
        for channel in ReleaseChannel.allCases {
            #expect(flag(.beta).isOn(in: channel, override: nil) == flag(.beta).isOnByDefault(in: channel))
        }
    }

    @Test func theChannelComesFromInfoPlist() {
        #expect(ReleaseChannel(infoValue: "dev") == .dev)
        #expect(ReleaseChannel(infoValue: "beta") == .beta)
        #expect(ReleaseChannel(infoValue: "production") == .production)
    }

    @Test func anythingUnknownIsProduction() {
        #expect(ReleaseChannel(infoValue: nil) == .production)
        #expect(ReleaseChannel(infoValue: "") == .production)
        #expect(ReleaseChannel(infoValue: "Beta") == .production)
        #expect(ReleaseChannel(infoValue: "$(STARHASH_CHANNEL)") == .production)
    }

    @Test func overridesAreForDevAndBetaOnly() {
        #expect(channels(where: \.allowsOverrides) == [.dev, .beta])
    }

    @Test func theSwitchHasItsOwnKey() {
        #expect(flag(.off).defaultsKey == "featureFlag.sample")
    }
}
