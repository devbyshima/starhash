import Testing
@testable import StarHashKit

struct WhatsNewTests {
    private func release(_ version: String, announced: Bool) -> Release {
        Release(
            version: version,
            date: "2026-10-04",
            summary: "",
            highlights: [],
            announcement: announced ? .init(highlights: [], pages: []) : nil
        )
    }

    /// Newest first, as `ReleaseHistory` keeps them.
    private var history: [Release] {
        [
            release("1.3.0", announced: true),
            release("1.2.1", announced: false),
            release("1.2.0", announced: true),
            release("1.1.0", announced: true),
            release("1.0.0", announced: false),
        ]
    }

    private func announced(_ current: String, lastRun: String?, hasUsedApp: Bool = true) -> String? {
        WhatsNew.release(toAnnounce: current, lastRun: lastRun, hasUsedApp: hasUsedApp, in: history)?.version
    }

    @Test func aFreshInstallNeverSeesIt() {
        #expect(announced("1.3.0", lastRun: nil, hasUsedApp: false) == nil)
        #expect(announced("1.1.0", lastRun: nil, hasUsedApp: false) == nil)
    }

    @Test func anUpdateShowsTheVersionItInstalled() {
        #expect(announced("1.1.0", lastRun: "1.0.0") == "1.1.0")
        #expect(announced("1.2.0", lastRun: "1.1.0") == "1.2.0")
    }

    @Test func itShowsOnce() {
        #expect(announced("1.1.0", lastRun: "1.1.0") == nil)
    }

    @Test func aPatchAfterASeenVersionShowsNothing() {
        #expect(announced("1.2.1", lastRun: "1.2.0") == nil)
    }

    @Test func aPatchShowsItsVersionsNewsIfItWasMissed() {
        #expect(announced("1.2.1", lastRun: "1.1.0") == "1.2.0")
    }

    @Test func skippingVersionsShowsTheNewest() {
        #expect(announced("1.3.0", lastRun: "1.0.0") == "1.3.0")
    }

    @Test func anInstallFromBeforeVersionsWereKeptCountsAsAnUpdate() {
        #expect(announced("1.1.0", lastRun: nil, hasUsedApp: true) == "1.1.0")
    }

    @Test func goingBackShowsNothing() {
        #expect(announced("1.1.0", lastRun: "1.2.0") == nil)
    }

    @Test func aReleaseNewerThanTheAppIsIgnored() {
        #expect(announced("1.2.1", lastRun: "1.0.0") == "1.2.0")
    }

    @Test func versionsCompareAsNumbers() {
        let history = [release("1.10.0", announced: true), release("1.9.0", announced: true)]
        #expect(WhatsNew.release(toAnnounce: "1.10.0", lastRun: "1.9.0", hasUsedApp: true, in: history)?.version == "1.10.0")
        #expect(AppVersion("1.10.0")! > AppVersion("1.9.0")!)
        #expect(AppVersion("1.2") == AppVersion("1.2.0"))
    }

    @Test func somethingThatIsNotAVersionShowsNothing() {
        #expect(AppVersion("1.0.0-beta.1") == nil)
        #expect(AppVersion("") == nil)
        #expect(AppVersion("1..0") == nil)
        #expect(AppVersion("1.0.0.0") == nil)
        #expect(announced("1.1.0", lastRun: "unknown") == nil)
    }

    @Test func noAnnouncementNoSheet() {
        let history = [release("1.1.0", announced: false), release("1.0.0", announced: false)]
        #expect(WhatsNew.release(toAnnounce: "1.1.0", lastRun: "1.0.0", hasUsedApp: true, in: history) == nil)
    }
}
