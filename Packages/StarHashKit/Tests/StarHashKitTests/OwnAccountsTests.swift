import Foundation
import Testing
@testable import StarHashKit

@MainActor
@Suite struct OwnAccountsTests {
    let own = OwnAccounts(numbers: ["0788 123 456", "0722 000 515"], name: "Shima Byiringiro")!

    @Test func sentToTheOtherSIMIsMatchedByItsFullNumber() {
        #expect(own.owns(Recipient(name: "Shima", destination: "0722000515", kind: .phone)))
        #expect(!own.owns(Recipient(name: "Shima", destination: "0722000516", kind: .phone)))
        #expect(!own.owns(Recipient(name: "Shop", destination: "020205", kind: .merchant)))
    }

    @Test func aMaskedSenderNeedsTheDigitsAndAName() {
        // "*********515" keeps "515".
        #expect(own.owns(Recipient(name: "Serein Shima", destination: "515", kind: .phone)))
        #expect(!own.owns(Recipient(name: "John Doe", destination: "515", kind: .phone)))
        #expect(!own.owns(Recipient(name: "Serein Shima", destination: "999", kind: .phone)))
        #expect(OwnAccounts(numbers: ["0722000515"], name: nil)?.owns(Recipient(name: "Shima", destination: "515", kind: .phone)) == false)
    }

    @Test func noRealNumberMeansNone() {
        #expect(OwnAccounts(numbers: ["", "123"], name: "Shima") == nil)
    }

    @Test func theStoreFilesMovesBetweenOwnSIMs() {
        let store = StarHashStore(fileURL: nil)
        store.ownAccounts = { own }
        let sent = store.recordPayment(to: Recipient(name: "Me", destination: "0722000515", kind: .phone), amount: 5000)
        #expect(sent.isOwnTransfer)
        let received = store.apply(ParsedSMS(
            wallet: .mtn, direction: .incoming,
            counterparty: Recipient(name: "Serein Shima", destination: "515", kind: .phone),
            amount: 2000, fee: nil, date: .now, reference: "1", balanceAfter: nil, category: nil
        ))
        #expect(received.isOwnTransfer)
        let other = store.recordPayment(to: Recipient(name: "Ariane", destination: "0788999000", kind: .phone), amount: 700)
        #expect(!other.isOwnTransfer)
    }

    @Test func numbersGivenLaterFileWhatCameBefore() {
        let store = StarHashStore(fileURL: nil)
        store.recordPayment(to: Recipient(name: "Me", destination: "0722000515", kind: .phone), amount: 5000)
        #expect(store.markOwnTransfers() == 0)
        store.ownAccounts = { own }
        #expect(store.markOwnTransfers() == 1)
        #expect(store.transactions.first?.isOwnTransfer == true)
    }
}
