import Foundation
import Testing
@testable import StarHashKit

@Suite struct ScamCheckTests {
    private let received = "You have received 50000 RWF from Jean Bosco (*********123) on your mobile money account at 2026-10-09 18:22:01. Message from sender: . Your new balance:51200 RWF. Financial Transaction Id: 31234567890."

    @Test func genuineSenderPasses() {
        #expect(ScamCheck.check(received, sender: "M-Money") == nil)
        #expect(ScamCheck.check(received, sender: "MTN MoMo") == nil)
        #expect(ScamCheck.check(received, sender: nil) == nil)
    }

    @Test func phoneNumberSenderIsWarned() throws {
        let warning = try #require(ScamCheck.check(received, sender: "+250 788 555 123"))
        #expect(warning.reason == .unofficialSender)
        #expect(warning.wallet == .mtn)
        #expect(warning.claimed?.amount == 50_000)
        #expect(warning.claimed?.direction == .incoming)
    }

    @Test func emailAndUnknownNamesAreWarned() {
        #expect(ScamCheck.check(received, sender: "someone@icloud.com")?.reason == .unofficialSender)
        // A name that is not the wallet's, on a whole transaction message.
        #expect(ScamCheck.check(received, sender: "Jean")?.reason == .unofficialSender)
    }

    @Test func wordingIsWarnedWithoutASender() throws {
        let text = received + " I sent it by mistake, please send it back."
        let warning = try #require(ScamCheck.check(text, sender: nil))
        #expect(warning.reason == .suspiciousWording)
    }

    @Test func bankAndOtherMessagesAreLeftAlone() {
        #expect(ScamCheck.check("Your OTP is 123456", sender: "+250788555123") == nil)
        #expect(ScamCheck.check("BK: Your account was credited RWF 20,000", sender: "BK") == nil)
    }

    @Test func senderFolding() {
        #expect(ScamCheck.fold("M-Money") == "mmoney")
        #expect(ScamCheck.isPersonal("0788 555 123"))
        #expect(ScamCheck.isPersonal("a@b.rw"))
        #expect(!ScamCheck.isPersonal("M-Money"))
    }
}

@Suite struct CategoryTests {
    @Test func airtimePurchaseIsBought() throws {
        let sms = try #require(CarrierSMS.parse(
            "*164*S*Y'ello, You have bought 1,000 RWF of airtime for 0788123456 at 2026-10-09 09:12:44. Fee was 0 RWF. Your new balance: 4,000 RWF. TxId: 31200000011."
        ))
        #expect(sms.direction == .outgoing)
        #expect(sms.amount == 1_000)
        #expect(sms.category == TransactionCategory.airtime.rawValue)
        #expect(sms.isPurchase)
        #expect(sms.counterparty.name == "Airtime")
        #expect(!sms.counterparty.isPayable)
    }

    @Test func bundleAndCashPowerPurchases() throws {
        let bundle = try #require(CarrierSMS.parse(
            "TxId: 31200000012. You have purchased a Data Bundle of 500 RWF on your MoMo account. Fee was 0 RWF. New balance: 3,500 RWF."
        ))
        #expect(bundle.amount == 500)
        #expect(bundle.category == TransactionCategory.bundles.rawValue)

        let power = try #require(CarrierSMS.parse(
            "TxId: 31200000013. Y'ello, Cash Power token bought for 5,000 RWF with MoMo. Token: 1234-5678-9012. New balance: 1,000 RWF."
        ))
        #expect(power.amount == 5_000)
        #expect(power.category == TransactionCategory.electricity.rawValue)
    }

    @Test func partnerPaymentIsCategorisedByName() throws {
        let sms = try #require(CarrierSMS.parse(
            "TxId:31200000014*S*Your payment of 2,000 RWF to MTN Airtime with token and ET Id: FT123 was completed at 2026-10-09 10:00:00. Fee was 0 RWF. Your new balance: 1,000 RWF."
        ))
        #expect(sms.category == TransactionCategory.airtime.rawValue)
        #expect(sms.isPurchase)
    }

    @Test func transferAdvertDoesNotMakeAPurchase() throws {
        let sms = try #require(CarrierSMS.parse(
            "*165*S*5000 RWF transferred to John Doe (250788123456) from 12345678 at 2024-10-20 16:13:05 . Fee was: 100 RWF. New balance: 12000 RWF. Kugura ama inite cg interineti kuri MoMo, Kanda *182*2*1# . *EN#"
        ))
        #expect(sms.category == nil)
        #expect(!sms.isPurchase)
    }

    @Test func namesPointToCategories() {
        #expect(TransactionCategorizer.category(name: "EUCL Cash Power") == .electricity)
        #expect(TransactionCategorizer.category(name: "WASAC") == .water)
        #expect(TransactionCategorizer.category(name: "Canal+ Rwanda") == .tv)
        #expect(TransactionCategorizer.category(name: "Simba Supermarket") == .groceries)
        #expect(TransactionCategorizer.category(name: "Java House") == .restaurant)
        #expect(TransactionCategorizer.category(name: "Yego Moto") == .transport)
        #expect(TransactionCategorizer.category(name: "Regional Traders") == nil)
        // A person says nothing of what they were paid for.
        #expect(TransactionCategorizer.category(name: "Simba", kind: .phone) == nil)
    }

    @Test @MainActor func storeKeepsTheMessagesCategory() {
        let store = StarHashStore(fileURL: nil)
        let sms = ParsedSMS(
            direction: .outgoing, counterparty: Recipient(name: "Airtime", destination: "", kind: .merchant),
            amount: 1_000, reference: "1", category: "airtime"
        )
        let applied = store.apply(sms)
        #expect(applied.category == "airtime")
        #expect(applied.isPurchase)
    }
}

@Suite struct BackupTests {
    @Test func roundTrip() throws {
        let t = Transaction(direction: .outgoing, counterparty: Recipient(name: "A", destination: "020205", kind: .merchant), amount: 100, date: Date(timeIntervalSince1970: 1_700_000_000), status: .confirmed, source: .app, reference: "R1")
        let backup = StarHashBackup(appVersion: "1.1.0", transactions: [t], shortcuts: USSDShortcut.defaults, profile: OwnerProfile(name: "Shima", number: "0788123456"))
        let read = try StarHashBackup.decode(try backup.encoded())
        #expect(read.transactions == [t])
        #expect(read.shortcuts?.count == USSDShortcut.defaults.count)
        #expect(read.profile?.number == "0788123456")
    }

    @Test func rejectsOtherFiles() {
        #expect(throws: StarHashBackup.ReadError.notABackup) { try StarHashBackup.decode(Data("{\"a\":1}".utf8)) }
        #expect(throws: StarHashBackup.ReadError.notABackup) { try StarHashBackup.decode(Data("not json".utf8)) }
        var newer = StarHashBackup(transactions: [])
        newer.version = 99
        #expect(throws: StarHashBackup.ReadError.tooNew) { try StarHashBackup.decode(try newer.encoded()) }
    }

    @Test @MainActor func mergeAddsOnlyWhatIsMissing() {
        let store = StarHashStore(fileURL: nil)
        let a = Transaction(direction: .outgoing, counterparty: Recipient(destination: "020205", kind: .merchant), amount: 100, date: .now, status: .confirmed, source: .app, reference: "R1")
        store.add(a)
        let sameMessage = Transaction(direction: .outgoing, counterparty: a.counterparty, amount: 100, date: .now, status: .confirmed, source: .sms, reference: "R1")
        let b = Transaction(direction: .incoming, counterparty: Recipient(destination: "0788123456", kind: .phone), amount: 50, date: .now, status: .confirmed, source: .sms)
        #expect(store.merge([a, sameMessage, b, b]) == 1)
        #expect(store.transactions.count == 2)
    }

    @Test @MainActor func shortcutsMergeByCode() {
        let name = "BackupTests.\(UUID())"
        let defaults = UserDefaults(suiteName: name)!
        defer { defaults.removePersistentDomain(forName: name) }
        let list = USSDShortcutList(defaults: defaults)
        let added = list.merge(USSDShortcut.defaults + [USSDShortcut(name: "Water", code: "*182*3*1#", isPinned: true)])
        #expect(added == 1)
        #expect(list.shortcuts.last?.name == "Water")
        #expect(list.shortcuts.last?.isPinned == true)
    }
}
