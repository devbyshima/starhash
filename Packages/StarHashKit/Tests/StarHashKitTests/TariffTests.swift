import Testing
@testable import StarHashKit

struct TariffTests {
    private let mtnNumber = Recipient(name: nil, destination: "0788123456", kind: .phone)
    private let airtelNumber = Recipient(name: nil, destination: "0728123456", kind: .phone)
    private let merchant = Recipient(name: "Shop", destination: "020205", kind: .merchant)

    @Test(arguments: [
        (700, 20), (1_000, 20), (1_001, 100), (5_000, 100), (10_000, 100),
        (10_001, 250), (150_000, 250), (150_001, 1_500), (2_000_000, 1_500),
        (2_000_001, 3_000), (5_000_000, 3_000), (5_000_001, 5_000), (10_000_000, 5_000),
    ])
    func mtnToMTNFollowsTheBands(amount: Int, fee: Int) {
        #expect(Tariff.fee(sending: amount, to: mtnNumber, from: .mtn) == fee)
    }

    @Test func aboveTheLastBandIsUnknown() {
        #expect(Tariff.fee(sending: 10_000_001, to: mtnNumber, from: .mtn) == nil)
    }

    @Test func theOtherNetworkIsTheEKashCap() {
        #expect(Tariff.fee(sending: 1_500, to: airtelNumber, from: .mtn) == 20)
        #expect(Tariff.fee(sending: 900_000, to: mtnNumber, from: .airtel) == 20)
    }

    @Test func airtelToAirtelIsFree() {
        #expect(Tariff.fee(sending: 50_000, to: airtelNumber, from: .airtel) == 0)
    }

    @Test func merchantsAreFreeForThePayer() {
        #expect(Tariff.fee(sending: 76_480, to: merchant, from: .mtn) == 0)
        #expect(Tariff.fee(sending: 76_480, to: merchant, from: .airtel) == 0)
    }
}
