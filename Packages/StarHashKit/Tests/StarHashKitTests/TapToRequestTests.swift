import Foundation
import Testing
@testable import StarHashKit

@Suite("Tap to Request")
struct TapToRequestTests {
    static let start = Date(timeIntervalSince1970: 1_800_000_000)

    /// Measurements a tenth of a second apart, from `start`.
    static func measure(_ distances: [Float?], into detector: inout TapToRequest.Detector, from offset: TimeInterval = 0) -> [Bool] {
        distances.enumerated().map { index, distance in
            detector.measure(distance, at: start.addingTimeInterval(offset + Double(index) * 0.1))
        }
    }

    // MARK: When a tap counts

    @Test func twoMeasurementsInARowWithinReachMakeATouch() {
        var detector = TapToRequest.Detector()
        let taps = Self.measure([0.8, 0.4, 0.12, 0.08], into: &detector)
        #expect(taps == [false, false, false, true])
        #expect(detector.touchedAt == Self.start.addingTimeInterval(0.3))
    }

    /// Standing side by side at a counter is not holding phones together.
    @Test func phonesCloseButNotTouchingNeverTap() {
        var detector = TapToRequest.Detector()
        let taps = Self.measure([0.3, 0.25, 0.2, 0.18, 0.2, 0.3], into: &detector)
        #expect(!taps.contains(true))
        #expect(detector.touchedAt == nil)
    }

    @Test func oneStrayReadingNeverTaps() {
        var detector = TapToRequest.Detector()
        let taps = Self.measure([0.6, 0.05, 0.6, 0.05, 0.6], into: &detector)
        #expect(!taps.contains(true))
    }

    /// No measurement (the other phone out of view) breaks the run.
    @Test func aLostMeasurementBreaksTheRun() {
        var detector = TapToRequest.Detector()
        let taps = Self.measure([0.1, nil, 0.1, 0.1], into: &detector)
        #expect(taps == [false, false, false, true])
    }

    /// Measurements a long while apart are not in a row.
    @Test func measurementsFarApartInTimeAreNotInARow() {
        var detector = TapToRequest.Detector()
        let first = detector.measure(0.1, at: Self.start)
        let late = detector.measure(0.1, at: Self.start.addingTimeInterval(2))
        let next = detector.measure(0.1, at: Self.start.addingTimeInterval(2.1))
        #expect([first, late, next] == [false, false, true])
    }

    /// Held together, a tap counts once; parted and brought back, again.
    @Test func aTouchCountsOnceUntilThePhonesPart() {
        var detector = TapToRequest.Detector()
        let held = Self.measure([0.1, 0.1, 0.05, 0.1, 0.3, 0.1, 0.1], into: &detector)
        #expect(held == [false, true, false, false, false, false, false])
        // Parted past the release distance, then together again.
        let again = Self.measure([0.5, 0.1, 0.1], into: &detector, from: 0.7)
        #expect(again == [false, false, true])
    }

    /// Lost for a while as they are held, then still together: they may
    /// have parted meanwhile, so it is a new tap.
    @Test func aTouchLostForAWhileCountsAgain() {
        var detector = TapToRequest.Detector()
        let held = Self.measure([0.1, 0.1], into: &detector)
        #expect(held == [false, true])
        let again = Self.measure([0.1, 0.1], into: &detector, from: 2)
        #expect(again == [false, true])
    }

    @Test func aRequestIsTakenOnlyCloseAfterATouch() {
        var detector = TapToRequest.Detector()
        #expect(!detector.touchedRecently(at: Self.start))
        _ = Self.measure([0.1, 0.1], into: &detector)
        let touched = Self.start.addingTimeInterval(0.1)
        #expect(detector.touchedRecently(at: touched))
        #expect(detector.touchedRecently(at: touched.addingTimeInterval(TapToRequest.touchMemory)))
        #expect(!detector.touchedRecently(at: touched.addingTimeInterval(TapToRequest.touchMemory + 0.1)))
        // A clock that went back is no proof.
        #expect(!detector.touchedRecently(at: touched.addingTimeInterval(-1)))
    }

    /// The asker's screen: nothing far off, full at a touch, in between
    /// as they come together.
    @Test func progressRunsFromApartToTouching() throws {
        #expect(TapToRequest.progress(distance: nil) == nil)
        #expect(TapToRequest.progress(distance: -0.2) == nil)
        #expect(TapToRequest.progress(distance: 3) == 0)
        #expect(TapToRequest.progress(distance: TapToRequest.approachDistance) == 0)
        #expect(TapToRequest.progress(distance: TapToRequest.touchDistance) == 1)
        #expect(TapToRequest.progress(distance: 0.02) == 1)
        let midway = try #require(TapToRequest.progress(distance: (TapToRequest.approachDistance + TapToRequest.touchDistance) / 2))
        #expect(abs(midway - 0.5) < 0.001)
    }

    /// Touch to pay dials at 1, so one close reading never gets there:
    /// only a touch the detector counts does.
    @Test func touchToPayReachesOneOnlyOnATouch() {
        #expect(TapToRequest.approach(distance: 0.05, touched: false) == TapToRequest.untouchedCeiling)
        #expect(TapToRequest.approach(distance: 0.05, touched: true) == 1)
        #expect(TapToRequest.approach(distance: nil, touched: true) == 1)
        #expect(TapToRequest.approach(distance: nil, touched: false) == nil)
        #expect(TapToRequest.approach(distance: 2, touched: false) == 0)
        #expect(TapToRequest.rangeContext != TapToRequest.inviteContext)
    }

    @Test func aNegativeDistanceIsNoMeasurement() {
        var detector = TapToRequest.Detector()
        let taps = Self.measure([0.1, -0.1, 0.1], into: &detector)
        #expect(!taps.contains(true))
    }

    // MARK: Offer

    /// An owner others may see keeps their name, with the offer beside it.
    @Test func anOfferRidesOnTheAnnouncement() throws {
        let announcement = PeopleNearby.Announcement(name: "Ariane", photoID: nil)
        let info = TapToRequest.Offer.discoveryInfo(adding: announcement.discoveryInfo)
        #expect(TapToRequest.Offer.isOffered(info))
        #expect(PeopleNearby.Announcement(discoveryInfo: info) == announcement)
    }

    /// One kept out of sight offers with no name, so no face shows for them.
    @Test func anOfferAloneShowsNoFace() {
        let info = TapToRequest.Offer.discoveryInfo(adding: nil)
        #expect(TapToRequest.Offer.isOffered(info))
        #expect(PeopleNearby.Announcement(discoveryInfo: info) == nil)
        #expect(info.count == 2)
    }

    @Test func onlyAnOfferFromThisVersionCounts() {
        #expect(!TapToRequest.Offer.isOffered(nil))
        #expect(!TapToRequest.Offer.isOffered(["v": "1", "n": "Ariane"]))
        #expect(!TapToRequest.Offer.isOffered(["v": "2", "t": "1"]))
        #expect(!TapToRequest.Offer.isOffered(["v": "1", "t": "0"]))
    }

    // MARK: Between phones

    @Test func aMessageReadsBackAsItWasSent() {
        let token = Data((0..<300).map { UInt8($0 % 256) })
        #expect(TapToRequest.Message(data: TapToRequest.Message.token(token).data) == .token(token))
        #expect(TapToRequest.Message(data: TapToRequest.Message.touched.data) == .touched)
    }

    @Test func aMessageThatIsNoneIsPassedOver() {
        func data(_ json: String) -> Data { Data(json.utf8) }
        // A request is a request's message, not this.
        let ask = MoneyRequest.Message.ask(.init(id: UUID(), name: "A", number: "0788123456", photoID: nil, amount: 500, note: nil))
        #expect(TapToRequest.Message(data: ask.data) == nil)
        #expect(MoneyRequest.Message(data: TapToRequest.Message.touched.data) == nil)
        #expect(TapToRequest.Message(data: data(#"{"v":2,"kind":"touched"}"#)) == nil)
        #expect(TapToRequest.Message(data: data(#"{"v":1,"kind":"token"}"#)) == nil)
        #expect(TapToRequest.Message(data: data(#"{"v":1,"kind":"token","token":""}"#)) == nil)
        let huge = Data(count: 5_000)
        #expect(TapToRequest.Message(data: TapToRequest.Message.token(huge).data) == nil)
    }
}
