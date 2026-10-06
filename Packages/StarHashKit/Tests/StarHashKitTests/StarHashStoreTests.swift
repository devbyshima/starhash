import Foundation
import Testing
@testable import StarHashKit

@MainActor
@Suite struct StarHashStoreTests {
    private let john = Recipient(name: "John Doe", destination: "0788123456", kind: .phone)
    private let pili = Recipient(name: "Pili-Pili Invest", destination: "020205", kind: .merchant)
    private let noon = Date(timeIntervalSince1970: 1_727_000_000)

    /// A fresh folder per test, removed by the caller.
    private func temporaryFile() throws -> URL {
        let folder = FileManager.default.temporaryDirectory.appending(path: "StarHashStoreTests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        return folder.appending(path: "transactions.json")
    }

    private func sentSMS(amount: Int = 5_000, at date: Date?, reference: String? = nil) -> ParsedSMS {
        ParsedSMS(
            direction: .outgoing,
            counterparty: Recipient(name: "John Doe", destination: "0788123456", kind: .phone),
            amount: amount, fee: 100, date: date, reference: reference, balanceAfter: 12_000
        )
    }

    // MARK: Recording

    @Test func aRetriedDialReusesThePendingPayment() {
        let store = StarHashStore(fileURL: nil)
        let first = store.recordPayment(to: pili, amount: 15_000, date: noon, retryWindow: 300)
        let retry = store.recordPayment(to: pili, amount: 15_000, date: noon.addingTimeInterval(60), retryWindow: 300)
        #expect(store.transactions.count == 1)
        #expect(retry.id == first.id)
        #expect(retry.date == noon.addingTimeInterval(60))
    }

    @Test func aDifferentAmountOrALaterDialIsANewPayment() {
        let store = StarHashStore(fileURL: nil)
        store.recordPayment(to: pili, amount: 15_000, date: noon, retryWindow: 300)
        store.recordPayment(to: pili, amount: 16_000, date: noon.addingTimeInterval(60), retryWindow: 300)
        store.recordPayment(to: pili, amount: 15_000, date: noon.addingTimeInterval(600), retryWindow: 300)
        #expect(store.transactions.count == 3)
    }

    @Test func aPaymentKeepsTheWalletItWasDialledWith() throws {
        let store = StarHashStore(fileURL: nil)
        let payment = store.recordPayment(to: john, amount: 5_000, date: noon, wallet: .airtel, retryWindow: 300)
        #expect(payment.wallet == .airtel)
        let retry = store.recordPayment(to: john, amount: 5_000, date: noon.addingTimeInterval(60), wallet: .mtn, retryWindow: 300)
        #expect(retry.wallet == .mtn)

        // A payment saved before the wallet was kept still decodes.
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        var json = try #require(JSONSerialization.jsonObject(with: encoder.encode(retry)) as? [String: Any])
        json["wallet"] = nil
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let old = try decoder.decode(Transaction.self, from: JSONSerialization.data(withJSONObject: json))
        #expect(old.wallet == nil)
    }

    @Test func aMessageOnlyConfirmsAPaymentFromItsOwnWallet() {
        let store = StarHashStore(fileURL: nil)
        store.recordPayment(to: john, amount: 5_000, date: noon, wallet: .airtel)
        var mtn = sentSMS(amount: 5_000, at: noon.addingTimeInterval(30))
        mtn.wallet = .mtn
        store.apply(mtn)
        #expect(store.transactions.count == 2)
        #expect(store.transactions.contains { $0.status == .pending && $0.wallet == .airtel })

        var airtel = sentSMS(amount: 5_000, at: noon.addingTimeInterval(60), reference: "A1")
        airtel.wallet = .airtel
        store.apply(airtel)
        #expect(store.transactions.count == 2)
        #expect(store.transactions.allSatisfy { $0.status == .confirmed })
    }

    /// The shop's sign can say one thing and its code be registered under
    /// another: the message's name is the code's from then on.
    @Test func aMerchantTakesTheNameItsCodeIsRegisteredUnder() {
        let store = StarHashStore(fileURL: nil)
        store.recordPayment(to: Recipient(name: "Java House", destination: "020205", kind: .merchant), amount: 15_000, date: noon)
        store.apply(ParsedSMS(
            direction: .outgoing,
            counterparty: Recipient(name: "Pili-Pili Invest", destination: "020205", kind: .merchant),
            amount: 15_000, fee: 0, date: noon.addingTimeInterval(30), reference: "1203948571"
        ))
        #expect(store.transactions[0].counterparty.name == "Pili-Pili Invest")
        #expect(store.recentRecipients().first?.name == "Pili-Pili Invest")
    }

    /// A message without the code may be another payment's of the same
    /// amount: it fills a missing name but never replaces one.
    @Test func aMessageWithoutTheCodeNeverRenamesAMerchant() {
        let store = StarHashStore(fileURL: nil)
        let named = store.recordPayment(to: Recipient(name: "Java House", destination: "020205", kind: .merchant), amount: 15_000, date: noon)
        store.apply(ParsedSMS(
            direction: .outgoing,
            counterparty: Recipient(name: "Kongeza Ltd", destination: "", kind: .merchant),
            amount: 15_000, fee: 0, date: noon.addingTimeInterval(30), reference: "145891386684"
        ))
        #expect(store.transaction(id: named.id)?.status == .confirmed)
        #expect(store.transaction(id: named.id)?.counterparty.name == "Java House")

        let unnamed = store.recordPayment(to: Recipient(destination: "556677", kind: .merchant), amount: 30_000, date: noon)
        store.apply(ParsedSMS(
            direction: .outgoing,
            counterparty: Recipient(name: "Kigali Heights Gym", destination: "", kind: .merchant),
            amount: 30_000, fee: 0, date: noon.addingTimeInterval(30), reference: "145891386685"
        ))
        #expect(store.transaction(id: unnamed.id)?.counterparty.name == "Kigali Heights Gym")
    }

    @Test func aPersonKeepsTheNameTheyWerePaidUnder() {
        let store = StarHashStore(fileURL: nil)
        store.recordPayment(to: john, amount: 5_000, date: noon)
        var message = sentSMS(amount: 5_000, at: noon.addingTimeInterval(30))
        message.counterparty.name = "Jean Mugisha"
        store.apply(message)
        #expect(store.transactions[0].counterparty.name == "John Doe")
    }

    @Test func wipingTheLocationsMovesTheGenerationOn() {
        let store = StarHashStore(fileURL: nil)
        let start = store.locationsGeneration
        store.clearLocations()
        #expect(store.locationsGeneration == start + 1)
        store.eraseAll()
        #expect(store.locationsGeneration == start + 2)
    }

    @Test func theFeeComesOnlyFromTheSMS() {
        let store = StarHashStore(fileURL: nil)
        store.recordPayment(to: john, amount: 5_000, date: noon)
        #expect(store.transactions[0].fee == nil)
        store.apply(sentSMS(amount: 5_000, at: noon.addingTimeInterval(30)))
        #expect(store.transactions[0].fee == 100)
        #expect(store.transactions[0].status == .confirmed)

        let silent = StarHashStore(fileURL: nil)
        silent.recordPayment(to: john, amount: 5_000, date: noon)
        var noFee = sentSMS(amount: 5_000, at: noon.addingTimeInterval(30))
        noFee.fee = nil
        silent.apply(noFee)
        #expect(silent.transactions[0].fee == nil)
    }

    @Test func withoutARetryWindowEveryDialIsRecorded() {
        let store = StarHashStore(fileURL: nil)
        store.recordPayment(to: john, amount: 5_000, date: noon)
        store.recordPayment(to: john, amount: 5_000, date: noon.addingTimeInterval(30))
        #expect(store.transactions.count == 2)
    }

    // MARK: Persistence

    @Test func savesAndReloads() throws {
        let url = try temporaryFile()
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }

        let store = StarHashStore(fileURL: url)
        store.recordPayment(to: john, amount: 5_000, date: noon)
        store.recordPayment(to: pili, amount: 15_000, date: noon.addingTimeInterval(60))

        let reopened = StarHashStore(fileURL: url)
        #expect(reopened.transactions.map(\.amount) == [15_000, 5_000])
        #expect(reopened.transactions.first?.counterparty == pili)
    }

    @Test func damagedFileIsSetAsideNotOverwritten() throws {
        let url = try temporaryFile()
        let folder = url.deletingLastPathComponent()
        defer { try? FileManager.default.removeItem(at: folder) }
        try Data("not json".utf8).write(to: url)

        let store = StarHashStore(fileURL: url)
        #expect(store.transactions.isEmpty)
        store.recordPayment(to: john, amount: 700, date: noon)

        let files = try FileManager.default.contentsOfDirectory(atPath: folder.path)
        #expect(files.contains { $0.hasPrefix("transactions.damaged-") })
        #expect(StarHashStore(fileURL: url).transactions.count == 1)
    }

    @Test func clearLocationsRemovesEveryCoordinate() {
        let store = StarHashStore(fileURL: nil)
        var paid = store.recordPayment(to: john, amount: 700, date: noon)
        paid.location = .init(latitude: -1.95, longitude: 30.09)
        store.update(paid)
        store.clearLocations()
        #expect(store.transactions.allSatisfy { $0.location == nil })
    }

    @Test func eraseAllRemovesTheFileAndItsDamagedCopies() throws {
        let url = try temporaryFile()
        let folder = url.deletingLastPathComponent()
        defer { try? FileManager.default.removeItem(at: folder) }
        try Data("not json".utf8).write(to: url)
        let store = StarHashStore(fileURL: url)
        store.recordPayment(to: john, amount: 700, date: noon)
        try Data("other".utf8).write(to: folder.appending(path: "unrelated.txt"))

        store.eraseAll()

        #expect(store.transactions.isEmpty)
        let files = try FileManager.default.contentsOfDirectory(atPath: folder.path)
        #expect(files == ["unrelated.txt"])
        #expect(StarHashStore(fileURL: url).transactions.isEmpty)
    }

    /// The phone locked after a restart: the file exists but cannot be
    /// read. A payment logged then must not replace the history on disk.
    @Test func unreadableFileIsMergedOnceReadable() throws {
        let url = try temporaryFile()
        defer {
            try? FileManager.default.setAttributes([.posixPermissions: 0o644], ofItemAtPath: url.path)
            try? FileManager.default.removeItem(at: url.deletingLastPathComponent())
        }
        let first = StarHashStore(fileURL: url)
        first.recordPayment(to: john, amount: 5_000, date: noon)
        first.recordPayment(to: pili, amount: 15_000, date: noon.addingTimeInterval(60))

        try FileManager.default.setAttributes([.posixPermissions: 0o000], ofItemAtPath: url.path)
        let locked = StarHashStore(fileURL: url)
        #expect(locked.transactions.isEmpty)
        locked.apply(sentSMS(amount: 700, at: noon.addingTimeInterval(120)))
        #expect(locked.transactions.count == 1)

        try FileManager.default.setAttributes([.posixPermissions: 0o644], ofItemAtPath: url.path)
        locked.reloadFromDisk()
        #expect(locked.transactions.map(\.amount) == [700, 15_000, 5_000])
        #expect(StarHashStore(fileURL: url).transactions.count == 3)
    }

    // MARK: Carrier SMS

    @Test func smsConfirmsTheClosestPendingPayment() {
        let store = StarHashStore(fileURL: nil)
        let early = store.recordPayment(to: john, amount: 5_000, date: noon.addingTimeInterval(-3_000))
        let late = store.recordPayment(to: john, amount: 5_000, date: noon.addingTimeInterval(-60))

        let confirmed = store.apply(sentSMS(at: noon))
        #expect(confirmed.id == late.id)
        #expect(confirmed.status == .confirmed)
        #expect(confirmed.fee == 100)
        #expect(confirmed.balanceAfter == 12_000)
        #expect(store.transaction(id: early.id)?.status == .pending)
        #expect(store.transactions.count == 2)
    }

    @Test func smsOutsideTheWindowIsANewTransaction() {
        let store = StarHashStore(fileURL: nil)
        store.recordPayment(to: john, amount: 5_000, date: noon.addingTimeInterval(-7 * 3600))
        let logged = store.apply(sentSMS(at: noon))
        #expect(logged.source == .sms)
        #expect(store.transactions.count == 2)
    }

    @Test func sameMessageTwiceIsAppliedOnce() {
        let store = StarHashStore(fileURL: nil)
        store.recordPayment(to: john, amount: 5_000, date: noon.addingTimeInterval(-60))
        // Transfers sent carry no reference; the date tells them apart.
        let first = store.apply(sentSMS(at: noon))
        let again = store.apply(sentSMS(at: noon))
        #expect(again.id == first.id)
        #expect(store.transactions.count == 1)

        let withReference = store.apply(sentSMS(amount: 900, at: nil, reference: "1203948571"))
        let repeated = store.apply(sentSMS(amount: 900, at: nil, reference: "1203948571"))
        #expect(repeated.id == withReference.id)
        #expect(store.transactions.count == 2)
    }

    /// Airtel's merchant messages can leave the code out: the same kind of
    /// payment, of the same amount, is the one it confirms.
    @Test func aMessageWithoutTheCodeConfirmsTheSameKindOfPayment() {
        let store = StarHashStore(fileURL: nil)
        let toJohn = store.recordPayment(to: john, amount: 15_000, date: noon.addingTimeInterval(-90))
        let toPili = store.recordPayment(to: pili, amount: 15_000, date: noon.addingTimeInterval(-60))
        let confirmed = store.apply(ParsedSMS(
            wallet: .airtel,
            direction: .outgoing,
            counterparty: Recipient(name: "Pili-Pili Invest", destination: "", kind: .merchant),
            amount: 15_000, fee: 0, date: noon, reference: "145891386684"
        ))
        #expect(confirmed.id == toPili.id)
        #expect(confirmed.counterparty.destination == "020205")
        #expect(store.transaction(id: toJohn.id)?.status == .pending)
        #expect(store.transactions.count == 2)
    }

    // MARK: MoMoAdvance

    /// MoMoAdvance lending the 5,000 and its fee of 100, at the moment the
    /// transfer's own message gives.
    private var overdraft: OverdraftUse {
        OverdraftUse(amount: 5_100, accessFee: 68, date: noon.addingTimeInterval(30))
    }

    @Test func anOverdraftAfterThePaymentsMessageAddsToItsFee() throws {
        let store = StarHashStore(fileURL: nil)
        store.recordPayment(to: john, amount: 5_000, date: noon, wallet: .mtn)
        store.apply(sentSMS(amount: 5_000, at: noon.addingTimeInterval(30)))
        let paid = try #require(store.applyOverdraft(overdraft))
        #expect(paid.fee == 168)
        #expect(paid.walletFee == 100)
        #expect(paid.accessFee == 68)

        // The automation can run twice for one message.
        store.applyOverdraft(overdraft)
        #expect(store.transactions.map(\.fee) == [168])
    }

    @Test func anOverdraftBeforeThePaymentsMessageWaitsForIt() throws {
        let store = StarHashStore(fileURL: nil)
        store.recordPayment(to: john, amount: 5_000, date: noon, wallet: .mtn)
        let pending = try #require(store.applyOverdraft(overdraft))
        #expect(pending.status == .pending)
        #expect(pending.fee == nil)

        let paid = store.apply(sentSMS(amount: 5_000, at: noon.addingTimeInterval(30)))
        #expect(paid.status == .confirmed)
        #expect(paid.fee == 168)
        #expect(paid.walletFee == 100)
    }

    @Test func anOverdraftStaysInAFeeConfirmedByHand() throws {
        let store = StarHashStore(fileURL: nil)
        store.recordPayment(to: john, amount: 5_000, date: noon, wallet: .mtn)
        store.applyOverdraft(overdraft)
        let payment = try #require(store.transactions.first)
        #expect(payment.confirmedByHand(wallet: .mtn).fee == 168)
        #expect(payment.markedFailed().confirmedByHand(wallet: .mtn).fee == 168)
    }

    /// An overdraft larger than a payment and its fee paid for something
    /// else: an Airtel payment, or a smaller one made about the same time.
    @Test func anOverdraftOnlyPaysForAnMTNPaymentItCouldCover() {
        let store = StarHashStore(fileURL: nil)
        store.recordPayment(to: john, amount: 500, date: noon, wallet: .mtn)
        store.recordPayment(to: pili, amount: 5_000, date: noon, wallet: .airtel)
        #expect(store.applyOverdraft(overdraft) == nil)
        #expect(store.transactions.allSatisfy { $0.accessFee == nil })
    }

    // MARK: Verify

    /// A moment as MTN writes it in a message, in Kigali time.
    private func kigaliText(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: "Africa/Kigali")
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return formatter.string(from: date)
    }

    private func transferText(amount: Int = 5_000, at date: Date) -> String {
        "*165*S*\(amount) RWF transferred to John DOE (250788123456) at \(kigaliText(date)) .Fee: 100RWF.Balance: 12000RWF.Dial *182*1*3# and send money abroad *EN#"
    }

    @Test func verifyConfirmsThePaymentItsMessageIsAbout() throws {
        let store = StarHashStore(fileURL: nil)
        let payment = store.recordPayment(to: john, amount: 5_000, date: noon, wallet: .mtn)
        let result = store.verify(payment.id, withMessage: transferText(at: noon.addingTimeInterval(30)))
        guard case .confirmed(let confirmed) = result else { Issue.record("\(String(describing: result))"); return }
        #expect(confirmed.id == payment.id)
        #expect(confirmed.status == .confirmed)
        #expect(confirmed.fee == 100)
        #expect(confirmed.balanceAfter == 12_000)
    }

    @Test func verifyRefusesAnotherPaymentsMessage() throws {
        let store = StarHashStore(fileURL: nil)
        let payment = store.recordPayment(to: john, amount: 5_000, date: noon, wallet: .mtn)
        // Another amount, then the right amount on another day.
        let other = store.verify(payment.id, withMessage: transferText(amount: 7_000, at: noon.addingTimeInterval(30)))
        #expect(other == .anotherPayment(amount: 7_000, counterparty: Recipient(input: "0788123456", name: "John Doe")))
        let lastWeek = store.verify(payment.id, withMessage: transferText(at: noon.addingTimeInterval(-7 * 86_400)))
        guard case .anotherPayment = lastWeek else { Issue.record("\(String(describing: lastWeek))"); return }
        #expect(store.transactions.map(\.status) == [.pending])
    }

    /// Failed by hand, the payment was no match for its message, which the
    /// automation logged on its own: verified, the two become one.
    @Test func verifyTakesBackAMessageLoggedOnItsOwn() throws {
        let store = StarHashStore(fileURL: nil)
        let payment = store.recordPayment(to: john, amount: 5_000, date: noon, wallet: .mtn)
        store.update(payment.markedFailed())
        let text = transferText(at: noon.addingTimeInterval(30))
        store.apply(try #require(CarrierSMS.parse(text)))
        #expect(store.transactions.count == 2)

        let result = store.verify(payment.id, withMessage: text)
        guard case .confirmed = result else { Issue.record("\(String(describing: result))"); return }
        #expect(store.transactions.count == 1)
        #expect(store.transactions.first?.id == payment.id)
        #expect(store.transactions.first?.status == .confirmed)
    }

    @Test func verifyNeverTakesAnotherDialledPaymentsMessage() throws {
        let store = StarHashStore(fileURL: nil)
        let first = store.recordPayment(to: john, amount: 5_000, date: noon, wallet: .mtn)
        let second = store.recordPayment(to: john, amount: 5_000, date: noon.addingTimeInterval(600), wallet: .mtn)
        let text = "TxId: 31057741814. " + transferText(at: noon.addingTimeInterval(30))
        store.apply(try #require(CarrierSMS.parse(text)))
        #expect(store.transaction(id: first.id)?.status == .confirmed)

        let result = store.verify(second.id, withMessage: text)
        guard case .confirmedAnother(let other) = result else { Issue.record("\(String(describing: result))"); return }
        #expect(other.id == first.id)
        #expect(store.transaction(id: second.id)?.status == .pending)
    }

    @Test func verifyWithAFailureMessageFailsThePayment() throws {
        let store = StarHashStore(fileURL: nil)
        let payment = store.recordPayment(to: john, amount: 5_000, date: noon, wallet: .mtn)
        let text = "Your transfer of 5000 RWF to John DOE (250788123456) has failed at \(kigaliText(noon.addingTimeInterval(30))). Message: . Financial Transaction Id: 30557484114.}."
        let result = store.verify(payment.id, withMessage: text)
        guard case .failed(let failed) = result else { Issue.record("\(String(describing: result))"); return }
        #expect(failed.status == .failed)
        #expect(failed.failureReason == .message)
    }

    @Test func verifyWithMoMoAdvancesMessageAddsItsFee() throws {
        let store = StarHashStore(fileURL: nil)
        let payment = store.recordPayment(to: john, amount: 5_000, date: noon, wallet: .mtn)
        let text = "You have used 5100 RWF on FRI:12345678/MM with access fee 68 RWF on \(kigaliText(noon.addingTimeInterval(30))) from MoMoAdvance. Your available overdraft balance is 7019 RWF."
        let result = store.verify(payment.id, withMessage: text)
        guard case .overdraft(let paid) = result else { Issue.record("\(String(describing: result))"); return }
        #expect(paid.status == .pending)
        #expect(paid.accessFee == 68)

        guard case .confirmed(let confirmed) = store.verify(payment.id, withMessage: transferText(at: noon.addingTimeInterval(30))) else {
            Issue.record("not confirmed"); return
        }
        #expect(confirmed.fee == 168)
    }

    @Test func verifyIgnoresAnythingElse() {
        let store = StarHashStore(fileURL: nil)
        let payment = store.recordPayment(to: john, amount: 5_000, date: noon, wallet: .mtn)
        #expect(store.verify(payment.id, withMessage: "") == .notAMessage)
        #expect(store.verify(payment.id, withMessage: "Hello, are we still meeting at 6?") == .notAMessage)
        #expect(store.verify(UUID(), withMessage: transferText(at: noon)) == nil)
        #expect(store.transactions.map(\.status) == [.pending])
    }

    // MARK: Recipients

    @Test func recentsSkipRecipientsThatCannotBeDialled() {
        let store = StarHashStore(fileURL: nil)
        store.recordPayment(to: john, amount: 700, date: noon)
        store.apply(ParsedSMS(
            direction: .outgoing,
            counterparty: Recipient(name: "Kongeza Ltd", destination: "", kind: .merchant),
            amount: 5_000, date: noon.addingTimeInterval(60)
        ))
        #expect(store.recentRecipients() == [john])
    }

    @Test func yearToDateCountsOneRecipient() {
        let store = StarHashStore(fileURL: nil)
        let now = Date.now
        store.recordPayment(to: john, amount: 700, date: now)
        store.recordPayment(to: john, amount: 300, date: now)
        store.recordPayment(to: pili, amount: 15_000, date: now)
        let ytd = store.yearToDate(for: john, now: now)
        #expect(ytd.amount == 1_000)
        #expect(ytd.count == 2)
    }
}
