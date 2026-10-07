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

    // MARK: Airtel Money
    //
    // Airtel Africa's template, as its Ugandan and Zambian messages read, in
    // RWF with the currency first: no Rwandan message has been published.

    @Test func airtelSent() throws {
        let sms = try #require(CarrierSMS.parse(
            "SENT.TID 143284610198. RWF 1,000 to JEAN BOSCO  0732561240. Fee RWF 0. Bal RWF 2,214. Date 20-March-2026 20:36."
        ))
        #expect(sms.wallet == .airtel)
        #expect(sms.direction == .outgoing)
        #expect(sms.amount == 1_000)
        #expect(sms.fee == 0)
        #expect(sms.balanceAfter == 2_214)
        #expect(sms.counterparty.name == "Jean Bosco")
        #expect(sms.counterparty.destination == "0732561240")
        #expect(sms.counterparty.kind == .phone)
        #expect(sms.reference == "143284610198")
        #expect(sms.date == kigali(2026, 3, 20, 20, 36))
    }

    @Test func airtelSentNumberFirst() throws {
        let sms = try #require(CarrierSMS.parse(
            "SENT.TID 143284610199. RWF2,500 to 250788123456 John DOE. Fee RWF 20. Bal RWF 9,000. Date 21-March-2026 08:05."
        ))
        #expect(sms.amount == 2_500)
        #expect(sms.fee == 20)
        #expect(sms.counterparty.name == "John Doe")
        #expect(sms.counterparty.destination == "0788123456")
    }

    @Test func airtelSentToTheOtherNetwork() throws {
        let sms = try #require(CarrierSMS.parse(
            "Sent to JEAN BOSCO in MTN . Amt RWF 2,000. Fee RWF 20. TID 150000000001."
        ))
        #expect(sms.direction == .outgoing)
        #expect(sms.amount == 2_000)
        #expect(sms.fee == 20)
        #expect(sms.counterparty.name == "Jean Bosco")
        #expect(sms.counterparty.destination == "")
    }

    @Test func airtelMoneySentTo() throws {
        let sms = try #require(CarrierSMS.parse(
            "Money sent to JEAN BOSCO on 0732561240. Amount RWF 205. Your bal is RWF 260. TID: PP260727.1512.M73944"
        ))
        #expect(sms.amount == 205)
        #expect(sms.balanceAfter == 260)
        #expect(sms.counterparty.destination == "0732561240")
        #expect(sms.reference == "PP260727.1512.M73944")
    }

    @Test func airtelReceived() throws {
        let sms = try #require(CarrierSMS.parse(
            "RECEIVED. TID 143487144326. RWF 40,000 from 732561240, ARIANE ISHIMWE. Bal RWF 40,000. View txns on MyAirtel App"
        ))
        #expect(sms.wallet == .airtel)
        #expect(sms.direction == .incoming)
        #expect(sms.amount == 40_000)
        #expect(sms.counterparty.name == "Ariane Ishimwe")
        // Airtel leaves the 0 off the sender's number.
        #expect(sms.counterparty.destination == "0732561240")
        #expect(sms.balanceAfter == 40_000)
        #expect(sms.date == nil)
    }

    @Test func airtelReceivedByName() throws {
        let sms = try #require(CarrierSMS.parse(
            "You have received RWF 300 from ARIANE ISHIMWE. Txn. ID: CI260726.1522.A37452. Reason: Mobile Money Transfer."
        ))
        #expect(sms.wallet == .airtel)
        #expect(sms.direction == .incoming)
        #expect(sms.amount == 300)
        #expect(sms.counterparty.name == "Ariane Ishimwe")
        #expect(sms.reference == "CI260726.1522.A37452")
    }

    @Test func airtelMerchantPayment() throws {
        let sms = try #require(CarrierSMS.parse(
            "PAID.TID 134346936087. RWF 5,000 to KIGALI COFFEE LTD 300770 Charge RWF 0. Bal RWF 35,415. 07-November-2025 20:27"
        ))
        #expect(sms.direction == .outgoing)
        #expect(sms.amount == 5_000)
        #expect(sms.fee == 0)
        #expect(sms.counterparty.name == "Kigali Coffee Ltd")
        #expect(sms.counterparty.destination == "300770")
        #expect(sms.counterparty.kind == .merchant)
        #expect(sms.date == kigali(2025, 11, 7, 20, 27))
    }

    @Test func airtelMerchantPaymentWithoutCode() throws {
        let sms = try #require(CarrierSMS.parse(
            "PAID RWF 5,000 to SIMBA SUPERMARKET Charge RWF 0, TID 145891386684. Bal RWF 1,750 Date: 26-April-2026 10:13."
        ))
        #expect(sms.counterparty.name == "Simba Supermarket")
        #expect(sms.counterparty.destination == "")
        #expect(sms.reference == "145891386684")
        #expect(sms.balanceAfter == 1_750)
        #expect(sms.date == kigali(2026, 4, 26, 10, 13))
    }

    @Test func airtelTillPayment() throws {
        let sms = try #require(CarrierSMS.parse(
            "Payment of RWF 1,500 Till Number 300770 KIGALI COFFEE LTD. Airtel Money bal is RWF 466. TID : MP260727.1129.Y34799."
        ))
        #expect(sms.amount == 1_500)
        #expect(sms.counterparty.name == "Kigali Coffee Ltd")
        #expect(sms.counterparty.destination == "300770")
        #expect(sms.balanceAfter == 466)
        #expect(sms.reference == "MP260727.1129.Y34799")
    }

    @Test func airtelCashDeposit() throws {
        let sms = try #require(CarrierSMS.parse(
            "CASH DEPOSIT of RWF 9,000 from  KCB BANK RWANDA. Bal RWF 11,214. TID 143323980086. 21-March-2026 14:15"
        ))
        #expect(sms.direction == .incoming)
        #expect(sms.amount == 9_000)
        #expect(sms.counterparty.name == "Kcb Bank Rwanda")
        #expect(sms.date == kigali(2026, 3, 21, 14, 15))
    }

    /// Cash taken out at an agent is not a payment, as with MTN.
    @Test(arguments: [
        "WITHDRAWN. TID 145041307719. RWF216,000 with Agent ID: 4324353.Fee RWF 3,575.Bal RWF 765. 14-April-2026 18:28.",
        "Transaction failed. TID 145041307720. RWF 1,000 to JEAN BOSCO 0732561240. Insufficient funds.",
        "Airtel: Get 2GB for RWF 500 today only. Dial *140#.",
    ])
    func airtelMessagesThatAreNotPayments(_ text: String) {
        #expect(CarrierSMS.parse(text) == nil)
    }

    @Test func mtnMessagesSayTheyAreMTN() throws {
        let sms = try #require(CarrierSMS.parse(
            "TxId: 1203948571. Your payment of 15,000 RWF to PILI-PILI INVEST 020205 has been completed at 2024-10-20 13:12:41. Your new balance: 47,000 RWF. Fee was 0 RWF."
        ))
        #expect(sms.wallet == .mtn)
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
    /// as well; StarHash reads only MTN MoMo's and Airtel Money's.
    @Test(arguments: [
        "BK: Your account 00040-0123456-01 has been debited with RWF 20,000 on 02/10/2026 12:00. Avail Bal: RWF 150,000.",
        "Equity Bank: You have received RWF 50,000 from JOHN DOE on 02-10-2026. Ref: FT2627512345. Bal: RWF 210,500.",
        "I&M Bank: Dear Customer, RWF 10,000.00 has been credited to your account 1234567 by transfer from Ariane Ishimwe at 2026-10-02 09:15:00.",
    ])
    func bankMessagesAreNotMoMo(_ text: String) {
        #expect(CarrierSMS.parse(text) == nil)
    }

    // MARK: Names

    // MARK: Real MTN MoMo messages (September 2026)

    @Test func realMoneyReceived() throws {
        let sms = try #require(CarrierSMS.parse(
            "You have received 2000 RWF from Serein SHIMA BYIRINGIRO (*********062) at 2026-09-30 16:36:29 . Balance:3719 RWF. FT Id: 30911702283"
        ))
        #expect(sms.wallet == .mtn)
        #expect(sms.direction == .incoming)
        #expect(sms.amount == 2000)
        #expect(sms.counterparty.name == "Serein Shima Byiringiro")
        #expect(sms.balanceAfter == 3719)
        #expect(sms.reference == "30911702283")
        #expect(sms.date == kigali(2026, 9, 30, 16, 36, 29))
    }

    @Test func realApprovedMerchantPrompt() throws {
        let sms = try #require(CarrierSMS.parse(
            "*164*S*Y'ello, A transaction of 300 RWF by INFORMATION TECHNOLOGY  ENGINEERING CONSTRUCTION   ITEC Ltd was completed at 2026-09-30 12:37:08. Balance:2719 RWF. Fee  0 RWF. FT Id: 30906497755. ET  Id: 250813310.*EN#"
        ))
        #expect(sms.direction == .outgoing)
        #expect(sms.amount == 300)
        #expect(sms.counterparty.kind == .merchant)
        #expect(sms.counterparty.name == "Information Technology Engineering Construction Itec Ltd")
        #expect(sms.fee == 0)
        #expect(sms.balanceAfter == 2719)
        #expect(sms.reference == "30906497755")
        #expect(sms.date == kigali(2026, 9, 30, 12, 37, 8))
    }

    @Test func realMerchantPayment() throws {
        let sms = try #require(CarrierSMS.parse(
            "TxId:30898115353*S*Your payment of 14,886 RWF to EVPLUGIN EMOBILITY SOLUTIONS L 59971 was completed at 2026-09-29 22:07:00.  Balance: 3,019 RWF. Fee 0 RWF.*EN#"
        ))
        #expect(sms.direction == .outgoing)
        #expect(sms.amount == 14_886)
        #expect(sms.counterparty.kind == .merchant)
        #expect(sms.counterparty.destination == "59971")
        #expect(sms.counterparty.name == "Evplugin Emobility Solutions L")
        #expect(sms.fee == 0)
        #expect(sms.balanceAfter == 3_019)
        #expect(sms.reference == "30898115353")
    }

    @Test(arguments: [
        ("*165*S*5000 RWF transferred to Eric RIZINDA (250788893323) at 2026-09-24 15:34:33 .Fee: 100RWF.Balance: 66807RWF.Dial *182*1*3# and send money abroad *EN#",
         5000, 100, 66807, "0788893323", "Eric Rizinda"),
        ("*165*S*24700 RWF transferred to Jean Claude TUYISENGE (250788301945) at 2026-09-24 15:00:30 .Fee: 250RWF.Balance: 81717RWF.Dial *182*1*3# and send money abroad *EN#",
         24700, 250, 81717, "0788301945", "Jean Claude Tuyisenge"),
    ])
    func realTransferSent(text: String, amount: Int, fee: Int, balance: Int, number: String, name: String) throws {
        let sms = try #require(CarrierSMS.parse(text))
        #expect(sms.direction == .outgoing)
        #expect(sms.amount == amount)
        #expect(sms.fee == fee)
        #expect(sms.balanceAfter == balance)
        #expect(sms.counterparty.destination == number)
        #expect(sms.counterparty.name == name)
    }

    @Test func realFailedTransfer() throws {
        let text = "Your transfer of 10000 RWF to Serein SHIMA BYIRINGIRO (250788335935) has failed at 2026-09-14 11:27:16. Message: . Financial Transaction Id: 30557484114.}."
        #expect(CarrierSMS.parse(text) == nil)
        let sms = try #require(CarrierSMS.parseFailure(text))
        #expect(sms.wallet == .mtn)
        #expect(sms.amount == 10_000)
        #expect(sms.counterparty.destination == "0788335935")
        #expect(sms.reference == "30557484114")
        #expect(sms.date == kigali(2026, 9, 14, 11, 27, 16))
    }

    /// A payment through one of MoMo's partners: the partner's name ends
    /// where "with token" starts.
    @Test(arguments: [
        ("*162*TxId:19349635627*S*Your payment of 100 RWF to Airtime with token  has been completed at 2025-03-07 09:49:55. Fee was 0 RWF. Your new balance: 6312 RWF . Message: - -. *EN#",
         100, 0, "Airtime", "19349635627"),
        ("*162*TxId:28293231288*S*Your payment of 56500 RWF to Bank of Kigali  with token  and ET Id: FTCM26153ZNMO2M3O was completed at 2026-06-02 14:33:29. Fee 1000 RWF. Balance: 9855 RWF . Message: - -. *EN#",
         56_500, 1_000, "Bank of Kigali", "28293231288"),
        ("*162*TxId:21356253230*S*Your payment of 3000 RWF to RWANDA AIRPORTS COMPANY Limited with token  and External Transaction Id: 651385 has been completed at 2025-06-25 19:03:21. Fee was 0 RWF.",
         3_000, 0, "Rwanda Airports Company Limited", "21356253230"),
    ])
    func realPaymentThroughAPartner(text: String, amount: Int, fee: Int, name: String, reference: String) throws {
        let sms = try #require(CarrierSMS.parse(text))
        #expect(sms.direction == .outgoing)
        #expect(sms.amount == amount)
        #expect(sms.fee == fee)
        #expect(sms.counterparty.kind == .merchant)
        #expect(sms.counterparty.name == name)
        #expect(sms.reference == reference)
    }

    /// The same failed has no code to tie it to a payment, and the year of
    /// its date is not one.
    @Test func realFailedPaymentThroughAPartner() {
        let text = "*143*TxId:27229144322*S*Your payment of 4000 RWF to RWANDA AIRPORTS COMPANY Limited with token  has failed at 2026-04-10 10:27:21. Message: - -. *EN#"
        #expect(CarrierSMS.parse(text) == nil)
        #expect(CarrierSMS.parseFailure(text) == nil)
    }

    @Test func realTransferWithoutTheNumber() throws {
        let sms = try #require(CarrierSMS.parse(
            "TransactionId: 30329341273 Your payment of 1000 RWF to SEREIN SHIMA BYIRINGIRO with token and ET Id:  SUCCESSFUL at 2026-09-04T08:45:12.498+02:00.Fee:20 RWF. Balance 145829 RWF."
        ))
        #expect(sms.wallet == .mtn)
        #expect(sms.direction == .outgoing)
        #expect(sms.amount == 1_000)
        #expect(sms.fee == 20)
        #expect(sms.balanceAfter == 145_829)
        #expect(sms.counterparty.kind == .phone)
        #expect(sms.counterparty.destination == "")
        #expect(sms.counterparty.name == "Serein Shima Byiringiro")
        #expect(sms.reference == "30329341273")
        #expect(sms.date == kigali(2026, 9, 4, 8, 45, 12))
    }

    @Test func realRefund() throws {
        let sms = try #require(CarrierSMS.parse(
            "*165*R*Y'ello, MTN RWANDACELL  LIMITED has successfully refunded 1000 RWF to your mobile money account at 2025-05-15 14:28:09. Message from refunder: Optional.absent(). Your new balance:18501 RWF.Thank you for using MTN MobileMoney.*EN#"
        ))
        #expect(sms.direction == .incoming)
        #expect(sms.amount == 1_000)
        #expect(sms.counterparty.kind == .merchant)
        #expect(sms.counterparty.name == "Mtn Rwandacell Limited")
        #expect(sms.balanceAfter == 18_501)
    }

    // MARK: Real MTN MoMo messages (October 2026)

    /// A loan repaid from the balance pays back money already counted when
    /// it was spent, so it is not a payment either.
    @Test func realLoanRepaymentIsNotAPayment() {
        #expect(CarrierSMS.parse("10631 RWF has been used to pay your loan at 2026-10-06 19:14:18. Your new balance: 9369 RWF. Financial Transaction Id: 31055953312") == nil)
    }

    @Test func displayNames() {
        #expect(CarrierSMS.displayName("PILI-PILI INVEST") == "Pili-Pili Invest")
        #expect(CarrierSMS.displayName("Ariane ISHIMWE") == "Ariane Ishimwe")
        #expect(CarrierSMS.displayName("McDonald A") == "McDonald A")
        #expect(CarrierSMS.displayName("  ") == nil)
    }
}
