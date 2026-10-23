import Foundation
import Testing
@testable import StarHashKit

@Suite("Owner's wallets")
struct OwnerWalletsTests {
    @Test func twoCarriersGiveBothWallets() {
        let wallets = OwnerWallets(numbers: ["0788 123 456", "0722 123 456"], chosen: .mtn)
        #expect(wallets.wallets.map(\.network) == [.mtn, .airtel])
        #expect(wallets.wallets.map(\.sim?.destination) == ["0788123456", "0722123456"])
        #expect(wallets.hasBothCarriers)
        #expect(wallets.messagesName == "\(Recipient.Network.mtn.messagesName) or \(Recipient.Network.airtel.messagesName)")
    }

    @Test func twoSIMsOnOneCarrierGiveOneWallet() {
        let wallets = OwnerWallets(numbers: ["0788123456", "0791234567"], chosen: .mtn)
        #expect(wallets.wallets.map(\.network) == [.mtn])
        #expect(!wallets.hasBothCarriers)
        #expect(wallets.messagesName == Recipient.Network.mtn.messagesName)
    }

    @Test func theChosenWalletIsAlwaysOffered() {
        // Paying with Airtel Money while the only number in is MTN's.
        let wallets = OwnerWallets(numbers: ["0788123456"], chosen: .airtel)
        #expect(wallets.wallets.map(\.network) == [.mtn, .airtel])
        #expect(wallets.wallets.last?.sim == nil)
        #expect(!wallets.hasBothCarriers)
        #expect(wallets.messagesName == Recipient.Network.airtel.messagesName)
    }

    @Test func noNumbersOfferBoth() {
        let wallets = OwnerWallets(numbers: ["", "07"], chosen: .mtn)
        #expect(wallets.wallets.map(\.network) == [.mtn, .airtel])
        #expect(wallets.wallets.allSatisfy { $0.sim == nil })
    }
}
