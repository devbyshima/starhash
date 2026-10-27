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
        #expect(store.refileOwnTransfers() == 0)
        store.ownAccounts = { own }
        #expect(store.refileOwnTransfers() == 1)
        #expect(store.transactions.first?.isOwnTransfer == true)
    }

    @Test func aNumberNoLongerOwnLeavesOwnAccounts() {
        // Back to one SIM: the other number is someone else's again.
        let store = StarHashStore(fileURL: nil)
        store.ownAccounts = { own }
        store.recordPayment(to: Recipient(name: "Me", destination: "0722000515", kind: .phone), amount: 5000)
        #expect(store.transactions.first?.isOwnTransfer == true)
        store.ownAccounts = { nil }
        #expect(store.refileOwnTransfers() == 1)
        #expect(store.transactions.first?.category == nil)
        #expect(store.refileOwnTransfers() == 0)
    }

    @Test func aCategoryChosenByHandStays() throws {
        let store = StarHashStore(fileURL: nil)
        let toOther = store.recordPayment(to: Recipient(name: "Me", destination: "0722000515", kind: .phone), amount: 5000)
        var gift = try #require(store.transaction(id: toOther.id))
        gift.category = TransactionCategory.family.rawValue
        gift.categoryChosenByHand = true
        store.update(gift)
        // Picked as Your own accounts by hand, with no second SIM given.
        let toFriend = store.recordPayment(to: Recipient(name: "Ariane", destination: "0788999000", kind: .phone), amount: 700)
        var mine = try #require(store.transaction(id: toFriend.id))
        mine.category = TransactionCategory.ownAccounts.rawValue
        mine.categoryChosenByHand = true
        store.update(mine)

        store.ownAccounts = { own }
        #expect(store.refileOwnTransfers() == 0)
        #expect(store.transaction(id: toOther.id)?.category == TransactionCategory.family.rawValue)
        #expect(store.transaction(id: toFriend.id)?.isOwnTransfer == true)
    }

    @Test func aVirtualCardMoveStaysOwn() {
        // The message calls it the owner's own; no number of theirs is in it.
        let store = StarHashStore(fileURL: nil)
        store.apply(ParsedSMS(
            wallet: .mtn, direction: .outgoing,
            counterparty: Recipient(name: "MoMo Virtual Card", destination: "", kind: .merchant),
            amount: 10_000, fee: nil, date: .now, reference: "2", balanceAfter: nil,
            category: TransactionCategory.ownAccounts.rawValue
        ))
        #expect(store.refileOwnTransfers() == 0)
        #expect(store.transactions.first?.isOwnTransfer == true)
    }

    @Test func aHandChoiceIsKeptOnlyWhenMade() throws {
        var transaction = Transaction(
            direction: .outgoing, counterparty: Recipient(name: "Ariane", destination: "0788999000", kind: .phone),
            amount: 700, date: Date(timeIntervalSince1970: 0), status: .confirmed, source: .app
        )
        let before = String(decoding: try JSONEncoder().encode(transaction), as: UTF8.self)
        #expect(!before.contains("chosenByHand"))
        #expect(try JSONDecoder().decode(Transaction.self, from: Data(before.utf8)).categoryChosenByHand == false)
        transaction.categoryChosenByHand = true
        let after = try JSONDecoder().decode(Transaction.self, from: JSONEncoder().encode(transaction))
        #expect(after.categoryChosenByHand)
    }
}
