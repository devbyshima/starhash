import Foundation
import Testing
@testable import StarHashKit

@Suite struct CarrierSMSTests {
    /// A Kigali wall-clock time as a Date.
    private func kigali(_ y: Int, _ mo: Int, _ d: Int, _ h: Int, _ mi: Int, _ s: Int = 0) -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Africa/Kigali")!
        return calendar.date(from: DateComponents(year: y, month: mo, day: d, hour: h, minute: mi, second: s))!
    }

    // MARK: Transfers sent

    @Test func transferSent() throws {
        let sms = try #require(CarrierSMS.parse(
            "*165*S*5000 RWF transferred to John Doe (250788123456) from 12345678 at 2024-10-20 16:13:05 . Fee was: 100 RWF. New balance: 12000 RWF. Kugura ama inite cg interineti kuri MoMo, Kanda *182*2*1# . *EN#"
        ))
        #expect(sms.direction == .outgoing)
        #expect(sms.amount == 5000)
        #expect(sms.fee == 100)
        #expect(sms.balanceAfter == 12000)
        #expect(sms.counterparty.name == "John Doe")
        #expect(sms.counterparty.destination == "0788123456")
        #expect(sms.counterparty.kind == .phone)
        #expect(sms.date == kigali(2024, 10, 20, 16, 13, 5))
        // The number after "from" is the sender's account, not a reference.
        #expect(sms.reference == nil)
    }

    @Test func transferWithCommasAndCapitals() throws {
        let sms = try #require(CarrierSMS.parse(
            "*165*S*1,250,000 RWF transferred to ALAIN MUGISHA (0784950091) from 36421234 at 2025-01-03 08:02:44 . Fee was: 1,500 RWF. New balance: 3,400 RWF."
        ))
        #expect(sms.amount == 1_250_000)
        #expect(sms.fee == 1_500)
        #expect(sms.balanceAfter == 3_400)
        #expect(sms.counterparty.name == "Alain Mugisha")
        #expect(sms.counterparty.destination == "0784950091")
    }

    @Test func currencyBeforeTheAmount() throws {
        let sms = try #require(CarrierSMS.parse(
            "*165*S*RWF 2,000 transferred to Moto (250722497291) from 12345678 at 2024-10-21 07:45:00 . Fee was: RWF 20. New balance: RWF 9,980."
        ))
        #expect(sms.amount == 2000)
        #expect(sms.fee == 20)
        #expect(sms.balanceAfter == 9980)
        #expect(sms.counterparty.destination == "0722497291")
    }

    @Test func messageSplitOverLines() throws {
        let sms = try #require(CarrierSMS.parse(
            "*165*S*700 RWF transferred to\nJohn  Doe (250780123456)\nfrom 12345678 at 2024-10-20 18:40:00 .\nFee was: 20 RWF."
        ))
        #expect(sms.amount == 700)
        #expect(sms.counterparty.name == "John Doe")
        #expect(sms.fee == 20)
    }

    // MARK: Merchant payments

    @Test func merchantPayment() throws {
        let sms = try #require(CarrierSMS.parse(
            "TxId: 73214484437. Your payment of 15,000 RWF to PILI-PILI INVEST 020205 has been completed at 2024-10-20 16:13:05. Your new balance: 10,000 RWF. Fee was 0 RWF. Kanda *182*16# wiyandikishe muri poromosiyo ya BivaMoMotima."
        ))
        #expect(sms.direction == .outgoing)
        #expect(sms.amount == 15_000)
        #expect(sms.fee == 0)
        #expect(sms.balanceAfter == 10_000)
        #expect(sms.reference == "73214484437")
        #expect(sms.counterparty.name == "Pili-Pili Invest")
        #expect(sms.counterparty.destination == "020205")
        #expect(sms.counterparty.kind == .merchant)
        #expect(sms.date == kigali(2024, 10, 20, 16, 13, 5))
    }

    @Test func merchantPaymentWithoutCode() throws {
        let sms = try #require(CarrierSMS.parse(
            "TxId: 99887766. Your payment of 3500 RWF to Simba Supermarket has been completed at 2024-11-02 19:20:11. Your new balance: 500 RWF. Fee was 0 RWF."
        ))
        #expect(sms.counterparty.name == "Simba Supermarket")
        #expect(sms.counterparty.destination == "")
        #expect(sms.counterparty.kind == .merchant)
    }

    @Test func approvedMerchantPrompt() throws {
        let sms = try #require(CarrierSMS.parse(
            "*164*S*Y'ello,A transaction of 5000 RWF by KONGEZA LTD on your MOMO account was successfully completed at 2024-10-22 11:20:30. Message from debit receiver: . Your new balance:7000 RWF. Fee was 0 RWF. Financial Transaction Id: 1203700001. External Transaction Id: 5521."
        ))
        #expect(sms.direction == .outgoing)
        #expect(sms.amount == 5000)
        #expect(sms.counterparty.name == "Kongeza Ltd")
        #expect(sms.balanceAfter == 7000)
        #expect(sms.reference == "1203700001")
    }

    // MARK: Money received

    @Test func moneyReceived() throws {
        let sms = try #require(CarrierSMS.parse(
            "You have received 35000 RWF from Ariane ISHIMWE (*********998) on your mobile money account at 2024-10-20 10:04:11. Message from sender: . Your new balance:47000 RWF. Financial Transaction Id: 1203940012."
        ))
        #expect(sms.direction == .incoming)
        #expect(sms.amount == 35_000)
        #expect(sms.counterparty.name == "Ariane Ishimwe")
        #expect(sms.counterparty.destination == "998")
        #expect(sms.balanceAfter == 47_000)
        #expect(sms.reference == "1203940012")
        #expect(sms.fee == nil)
        #expect(sms.date == kigali(2024, 10, 20, 10, 4, 11))
    }

    @Test func moneyReceivedWithFullNumber() throws {
        let sms = try #require(CarrierSMS.parse(
            "You have received 120,000 RWF from Grace Uwase (250785550123) on your mobile money account at 2024-09-23 15:45:00. Your new balance: 140,000 RWF. Financial Transaction Id: 1203755512."
        ))
        #expect(sms.counterparty.destination == "0785550123")
        #expect(sms.counterparty.kind == .phone)
        #expect(sms.amount == 120_000)
    }

    @Test func bankDeposit() throws {
        let sms = try #require(CarrierSMS.parse(
            "*113*R*A bank deposit of 20000 RWF has been added to your mobile money account at 2024-10-19 09:00:00. Your NEW BALANCE :32000 RWF. Cash in details: Amount: 20000 RWF. Financial Transaction Id: 1203800000."
        ))
        #expect(sms.direction == .incoming)
        #expect(sms.amount == 20_000)
        #expect(sms.counterparty.name == "Bank deposit")
        #expect(sms.balanceAfter == 32_000)
        #expect(sms.reference == "1203800000")
    }

    // MARK: Not transactions

    @Test(arguments: [
        "",
        "Hello, are we still meeting at 6?",
        "Your MoMo verification code is 482913. Do not share it with anyone.",
        "Gura 1GB ku 500 RWF gusa! Kanda *345# ubu.",
        "Y'ello! Get 20% bonus on airtime bought with MoMo until 2024-12-31. Dial *182*2*1#.",
        "*165*S*Your transfer of 5000 RWF to John Doe (250788123456) failed. Insufficient balance.",
        "Transaction of 9000 RWF was cancelled at 2024-10-20 16:13:05.",
    ])
    func junkIsNotATransaction(_ text: String) {
        #expect(CarrierSMS.parse(text) == nil)
    }

    /// Banks text in RWF too, so the automation hands their messages over
    /// as well; StarHash only reads MTN MoMo's for now.
    @Test(arguments: [
        "BK: Your account 00040-0123456-01 has been debited with RWF 20,000 on 02/10/2026 12:00. Avail Bal: RWF 150,000.",
        "Equity Bank: You have received RWF 50,000 from JOHN DOE on 02-10-2026. Ref: FT2627512345. Bal: RWF 210,500.",
        "I&M Bank: Dear Customer, RWF 10,000.00 has been credited to your account 1234567 by transfer from Ariane Ishimwe at 2026-10-02 09:15:00.",
    ])
    func bankMessagesAreNotMoMo(_ text: String) {
        #expect(CarrierSMS.parse(text) == nil)
    }

    // MARK: Names

    @Test func displayNames() {
        #expect(CarrierSMS.displayName("PILI-PILI INVEST") == "Pili-Pili Invest")
        #expect(CarrierSMS.displayName("Ariane ISHIMWE") == "Ariane Ishimwe")
        #expect(CarrierSMS.displayName("McDonald A") == "McDonald A")
        #expect(CarrierSMS.displayName("  ") == nil)
    }
}
