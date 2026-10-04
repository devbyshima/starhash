import Foundation
import Testing
@testable import StarHashKit

struct NearbyTests {
    private let shop = Recipient(name: "Simba", destination: "009911", kind: .merchant)
    private let moto = Recipient(name: nil, destination: "0722497291", kind: .phone)
    private let kiosk = Recipient(name: "Kiosk", destination: "184522", kind: .merchant)
    /// Kigali Heights.
    private let here = (lat: -1.9536, lon: 30.0928)
    private let now = Date(timeIntervalSince1970: 1_800_000_000)

    /// `metres` north of `here` (about 111,320 m per degree of latitude).
    private func north(_ metres: Double) -> Double { here.lat + metres / 111_320 }

    /// A payment made `metres` north of `here`, `minutesAgo` before `now`.
    private func paid(
        _ recipient: Recipient, north metres: Double = 0, accuracy: Double? = 10, minutesAgo: Double = 0,
        status: Transaction.Status = .confirmed, direction: Transaction.Direction = .outgoing
    ) -> Transaction {
        Transaction(
            direction: direction, counterparty: recipient, amount: 1_000,
            date: now.addingTimeInterval(-minutesAgo * 60), status: status, source: .app,
            location: .init(latitude: north(metres), longitude: here.lon, accuracy: accuracy)
        )
    }

    private func suggestions(_ transactions: [Transaction], north metres: Double = 0, accuracy: Double = 10) -> [Nearby.Suggestion] {
        Nearby.suggestions(from: transactions, latitude: north(metres), longitude: here.lon, accuracy: accuracy)
    }

    @Test func distanceIsInMetres() {
        let d = Nearby.distance(here.lat, here.lon, north(100), here.lon)
        #expect(abs(d - 100) < 1)
    }

    @Test func suggestsWhatWasPaidRightHere() {
        #expect(suggestions([paid(shop)], north: 15).map(\.recipient) == [shop])
    }

    @Test func ignoresPaymentsFurtherThanTheFixesCanAccountFor() {
        #expect(suggestions([paid(shop)], north: 120).isEmpty)
    }

    @Test func aRoughCurrentFixSuggestsNothing() {
        #expect(suggestions([paid(shop)], accuracy: 200).isEmpty)
    }

    @Test func aPaymentWithARoughFixDoesNotCount() {
        #expect(suggestions([paid(shop, accuracy: 120)]).isEmpty)
    }

    /// Saved before accuracy was kept: as rough as a fix may be, 50 m.
    @Test func aPlaceWithoutItsAccuracyCountsAsTheRoughestAllowed() {
        #expect(suggestions([paid(shop, north: 55, accuracy: nil)]).map(\.recipient) == [shop])
        #expect(suggestions([paid(shop, north: 70, accuracy: nil)]).isEmpty)
    }

    @Test func nearestFirstThenMostPaid() {
        let found = suggestions([
            paid(kiosk, north: 30, accuracy: 8, minutesAgo: 1),
            paid(shop, accuracy: 8, minutesAgo: 2),
            paid(moto, north: 3, accuracy: 8, minutesAgo: 3),
            paid(moto, north: 4, accuracy: 8, minutesAgo: 4),
        ], accuracy: 8)
        // Shop and Moto are within ten metres of each other, so the more
        // paid Moto leads; the kiosk is further.
        #expect(found.map(\.recipient) == [moto, shop, kiosk])
        #expect(found.first?.visits == 2)
    }

    /// Newest first, as the store keeps them: the newest payment with a
    /// name names the suggestion, so a merchant's registered name, once
    /// its message is in, wins over an older one and over a payment still
    /// waiting for its message.
    @Test func oneEntryPerRecipientUnderItsLatestName() {
        var unnamed = shop
        unnamed.name = nil
        var registered = shop
        registered.name = "Simba Supermarket"
        let found = suggestions([
            paid(unnamed, minutesAgo: 1, status: .pending),
            paid(registered, north: 2, minutesAgo: 5),
            paid(shop, minutesAgo: 60),
        ])
        #expect(found.count == 1)
        #expect(found.first?.recipient.name == "Simba Supermarket")
        #expect(found.first?.visits == 3)
    }

    @Test func failedAndIncomingPaymentsDoNotCount() {
        #expect(suggestions([paid(shop, status: .failed), paid(kiosk, direction: .incoming)]).isEmpty)
    }

    @Test func aPaymentWithNoPlaceDoesNotCount() {
        var noPlace = paid(shop)
        noPlace.location = nil
        #expect(suggestions([noPlace]).isEmpty)
    }
}
