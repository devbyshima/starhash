import Foundation
import Testing
@testable import StarHashKit

@Suite("Owner's wallets")
struct OwnerWalletsTests {
    @Test func twoCarriersGiveBothWallets() {
        let wallets = OwnerWallets(numbers: ["0788 123 456", "0722 123 456"], chosen: .mtn)
        #expect(wallets.wallets.map(\.network) == [.mtn, .airtel])
        #expect(wallets.wallets.map(\.sim?.destination) == ["0788123456", "0722123456"])
        #expect(wallets.hasTwoSIMs)
        #expect(wallets.hasBothCarriers)
        #expect(wallets.selected?.sim?.destination == "0788123456")
        #expect(wallets.messagesName == "\(Recipient.Network.mtn.messagesName) or \(Recipient.Network.airtel.messagesName)")
    }

    @Test func twoSIMsOnOneCarrierGiveTwoWallets() {
        // The default SIM second in the menu: it keeps the numbers' order.
        let wallets = OwnerWallets(numbers: ["0791234567", "0788123456"], chosen: .mtn)
        #expect(wallets.wallets.map(\.network) == [.mtn, .mtn])
        #expect(wallets.wallets.map(\.sim?.destination) == ["0788123456", "0791234567"])
        #expect(wallets.defaultSIM?.destination == "0791234567")
        #expect(wallets.selected?.sim?.destination == "0791234567")
        #expect(wallets.hasTwoSIMs)
        #expect(!wallets.hasBothCarriers)
        #expect(wallets.messagesName == Recipient.Network.mtn.messagesName)
    }

    @Test func oneNumberTypedTwiceIsOneSIM() {
        let wallets = OwnerWallets(numbers: ["0788123456", "0788 123 456"], chosen: .mtn)
        #expect(wallets.wallets.count == 1)
        #expect(!wallets.hasTwoSIMs)
    }

    @Test func theChosenWalletIsAlwaysOffered() {
        // Paying with Airtel Money while the only number in is MTN's.
        let wallets = OwnerWallets(numbers: ["0788123456"], chosen: .airtel)
        #expect(wallets.wallets.map(\.network) == [.mtn, .airtel])
        #expect(wallets.wallets.last?.sim == nil)
        #expect(wallets.selected == wallets.wallets.last)
        #expect(!wallets.hasBothCarriers)
        #expect(wallets.messagesName == Recipient.Network.airtel.messagesName)
    }

    @Test func noNumbersOfferBoth() {
        let wallets = OwnerWallets(numbers: ["", "07"], chosen: .mtn)
        #expect(wallets.wallets.map(\.network) == [.mtn, .airtel])
        #expect(wallets.wallets.allSatisfy { $0.sim == nil })
        #expect(wallets.selected?.network == .mtn)
    }
}

@Suite("A number's carrier")
struct NumberCarrierTests {
    private let mtn = Recipient.ownNumber("0788123456")!
    private let airtel = Recipient.ownNumber("0722123456")!

    @Test func aScannedNumbersCarrierPicksTheCode() throws {
        // A friend's StarHash code for an Airtel number, and one for MTN.
        let toAirtel = try #require(PaymentQR.parse(PaymentQR.link(for: airtel).absoluteString)).recipient
        let toMTN = try #require(PaymentQR.parse(PaymentQR.link(for: mtn).absoluteString)).recipient
        #expect(toAirtel.network == .airtel)
        #expect(toMTN.network == .mtn)
        // From the default SIM's wallet: its own network, or the other.
        #expect(USSD.payment(to: toAirtel, amount: 2_000, from: .airtel) == "*182*1*1*0722123456*2000#")
        #expect(USSD.payment(to: toAirtel, amount: 2_000, from: .mtn) == "*182*1*2*0722123456*2000#")
        #expect(USSD.payment(to: toMTN, amount: 2_000, from: .mtn) == "*182*1*1*0788123456*2000#")
        #expect(USSD.payment(to: toMTN, amount: 2_000, from: .airtel) == "*182*1*2*0788123456*2000#")
        // A MoMo code made for one network is read for its number alone.
        let scanned = try #require(PaymentQR.parse("*182*1*1*0733123456*500#"))
        #expect(USSD.payment(to: scanned.recipient, amount: 500, from: .mtn) == "*182*1*2*0733123456*500#")
    }

    @Test func aNumberWithNoKnownCarrierIsNotPaid() {
        #expect(PaymentQR.parse("*182*1*1*256712345678#") == nil)
        #expect(PaymentQR.parse("starhash://pay?to=0812345678") == nil)
    }
}
