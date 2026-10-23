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

@Suite("Owner's default SIM")
struct OwnerSIMsTests {
    private let mtn = Recipient.ownNumber("0788123456")!
    private let airtel = Recipient.ownNumber("0722123456")!

    @Test func choosingTheOtherSIMTradesTheNumbers() {
        var sims = OwnerSIMs(number: "0788123456", otherNumber: "0722 123 456", wallet: .mtn)
        sims.makeDefault(airtel)
        #expect(sims == OwnerSIMs(number: "0722123456", otherNumber: "0788 123 456", wallet: .airtel))
        // The default again changes nothing.
        sims.makeDefault(airtel)
        #expect(sims.number == "0722123456")
    }

    @Test func twoSIMsOnOneCarrierKeepTheWallet() {
        var sims = OwnerSIMs(number: "0788123456", otherNumber: "0791 234 567", wallet: .mtn)
        sims.makeDefault(Recipient.ownNumber("0791234567")!)
        #expect(sims == OwnerSIMs(number: "0791234567", otherNumber: "0788 123 456", wallet: .mtn))
    }

    @Test func aWalletChosenBeforeTheDefaultMakesItsSIMTheDefault() {
        // Airtel Money chosen on Pay while the MTN SIM came first.
        var sims = OwnerSIMs(number: "0788123456", otherNumber: "0722 123 456", wallet: .airtel)
        sims.followWallet()
        #expect(sims == OwnerSIMs(number: "0722123456", otherNumber: "0788 123 456", wallet: .airtel))
    }

    @Test func theWalletFollowsTheDefaultSIM() {
        // The default SIM's number changed to an Airtel one.
        var sims = OwnerSIMs(number: "0733123456", otherNumber: "0788 123 456", wallet: .mtn)
        sims.followDefaultSIM()
        #expect(sims.wallet == .airtel)
        #expect(sims.number == "0733123456")
    }

    @Test func aWalletNeitherSIMIsOnGoesToTheDefaults() {
        // Airtel Money left chosen, and both SIMs on MTN.
        var sims = OwnerSIMs(number: "0788123456", otherNumber: "0791 234 567", wallet: .airtel)
        sims.followWallet()
        #expect(sims.number == "0788123456")
        sims.followDefaultSIM()
        #expect(sims.wallet == .mtn)
    }

    @Test func oneSIMIsLeftAlone() {
        // One SIM on another carrier than the wallet is Profile's warning to
        // give, not a change to make.
        let before = OwnerSIMs(number: "0788123456", otherNumber: nil, wallet: .airtel)
        var sims = before
        sims.followWallet()
        sims.followDefaultSIM()
        #expect(sims == before)
        // Nor before the other number is whole.
        var typing = OwnerSIMs(number: "0788123456", otherNumber: "0722 12", wallet: .airtel)
        typing.followWallet()
        typing.followDefaultSIM()
        #expect(typing.number == "0788123456")
        #expect(typing.wallet == .airtel)
    }

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
