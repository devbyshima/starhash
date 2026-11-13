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
        #expect(channels { flag(.everywhere).isOnByDefault(in: $0) } == [.dev, .production])
    }

    @Test func aSwitchOnTheDeviceWinsInDev() {
        #expect(flag(.off).isOn(in: .dev, override: true))
        #expect(!flag(.dev).isOn(in: .dev, override: false))
        #expect(!flag(.everywhere).isOn(in: .dev, override: false))
    }

    @Test func theReleaseBuildIgnoresTheSwitch() {
        #expect(!flag(.off).isOn(in: .production, override: true))
        #expect(!flag(.dev).isOn(in: .production, override: true))
        #expect(flag(.everywhere).isOn(in: .production, override: false))
    }

    @Test func noSwitchMeansTheRollout() {
        for channel in ReleaseChannel.allCases {
            #expect(flag(.dev).isOn(in: channel, override: nil) == flag(.dev).isOnByDefault(in: channel))
        }
    }

    @Test func theChannelComesFromInfoPlist() {
        #expect(ReleaseChannel(infoValue: "dev") == .dev)
        #expect(ReleaseChannel(infoValue: "production") == .production)
    }

    @Test func anythingUnknownIsProduction() {
        #expect(ReleaseChannel(infoValue: nil) == .production)
        #expect(ReleaseChannel(infoValue: "") == .production)
        // The beta channel is gone: a build that still says so shows
        // nothing unfinished.
        #expect(ReleaseChannel(infoValue: "beta") == .production)
        #expect(ReleaseChannel(infoValue: "Dev") == .production)
        #expect(ReleaseChannel(infoValue: "$(STARHASH_CHANNEL)") == .production)
    }

    @Test func overridesAreForTheDevBuildOnly() {
        #expect(channels(where: \.allowsOverrides) == [.dev])
    }

    @Test func theSwitchHasItsOwnKey() {
        #expect(flag(.off).defaultsKey == "featureFlag.sample")
    }
}
