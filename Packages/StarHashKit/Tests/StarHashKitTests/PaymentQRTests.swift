import Foundation
import Testing
@testable import StarHashKit

@Suite struct PaymentQRTests {
    // MARK: StarHash's own codes

    @Test func ownLinkRoundTrips() throws {
        let recipient = Recipient(name: "Ariane Ishimwe", destination: "0788123998", kind: .phone)
        let link = PaymentQR.link(for: recipient)
        #expect(link.absoluteString == "starhash://pay?to=0788123998&name=Ariane%20Ishimwe")
        let request = try #require(PaymentQR.parse(link.absoluteString))
        #expect(request.recipient == recipient)
        #expect(request.amount == nil)
    }

    @Test func ownLinkWithAmountAndMerchant() throws {
        let link = PaymentQR.link(for: Recipient(name: "Pili-Pili", destination: "020205", kind: .merchant), amount: 15_000)
        let request = try #require(PaymentQR.parse(link.absoluteString))
        #expect(request.recipient.kind == .merchant)
        #expect(request.recipient.destination == "020205")
        #expect(request.recipient.name == "Pili-Pili")
        #expect(request.amount == 15_000)
    }

    @Test func linkWithoutAName() throws {
        let request = try #require(PaymentQR.parse("starhash://pay?to=%2B250%20788%20123%20456"))
        #expect(request.recipient.destination == "0788123456")
        #expect(request.recipient.name == nil)
    }

    // MARK: USSD

    @Test func merchantUSSD() throws {
        let request = try #require(PaymentQR.parse("*182*8*1*020205#"))
        #expect(request.recipient == Recipient(destination: "020205", kind: .merchant))
        #expect(request.amount == nil)
    }

    @Test func merchantUSSDWithAmountAsTelLink() throws {
        let request = try #require(PaymentQR.parse("tel:*182*8*1*184522*2500%23"))
        #expect(request.recipient.destination == "184522")
        #expect(request.amount == 2_500)
    }

    @Test func transferUSSD() throws {
        let request = try #require(PaymentQR.parse("*182*1*1*0788123456#"))
        #expect(request.recipient.kind == .phone)
        #expect(request.recipient.destination == "0788123456")
    }

    // MARK: EMV

    /// Builds an EMV field: tag, two-digit length, value.
    private func field(_ tag: String, _ value: String) -> String {
        tag + String(format: "%02d", value.count) + value
    }

    @Test func emvMerchantPayload() throws {
        let account = field("00", "rw.momo.mtn") + field("01", "020205")
        let payload = field("00", "01") + field("01", "11") + field("26", account)
            + field("52", "5812") + field("53", "646") + field("54", "1500.00")
            + field("58", "RW") + field("59", "PILI-PILI INVEST") + field("60", "KIGALI") + "6304ABCD"
        let request = try #require(PaymentQR.parse(payload))
        #expect(request.recipient.kind == .merchant)
        #expect(request.recipient.destination == "020205")
        #expect(request.recipient.name == "Pili-Pili Invest")
        #expect(request.amount == 1_500)
    }

    @Test func emvWithMobileNumberInAdditionalData() throws {
        let payload = field("00", "01") + field("26", field("00", "rw.wallet")) + field("59", "Jean")
            + field("62", field("02", "250788123456")) + "6304ABCD"
        let request = try #require(PaymentQR.parse(payload))
        #expect(request.recipient.destination == "0788123456")
        #expect(request.recipient.name == "Jean")
    }

    // MARK: Loose codes

    @Test func bareCodesAndNumbers() throws {
        #expect(PaymentQR.parse("020205")?.recipient == Recipient(destination: "020205", kind: .merchant))
        #expect(PaymentQR.parse("+250 788 123 456")?.recipient.destination == "0788123456")
        #expect(PaymentQR.parse("MoMo Pay: 184522")?.recipient.destination == "184522")
    }

    @Test func notPayable() {
        #expect(PaymentQR.parse("https://example.com/menu") == nil)
        #expect(PaymentQR.parse("WIFI:S:Cafe;T:WPA;P:secret;;") == nil)
        #expect(PaymentQR.parse("12") == nil)
        #expect(PaymentQR.parse("") == nil)
        // A link from elsewhere naming a number that is not Rwandan.
        #expect(PaymentQR.parse("https://pay.example.com/?phone=4155550123") == nil)
    }

    @Test func amountOutOfRangeIsDropped() throws {
        let request = try #require(PaymentQR.parse("starhash://pay?to=020205&amount=999999999"))
        #expect(request.amount == nil)
    }

    // MARK: Own number

    @Test func ownNumber() {
        #expect(Recipient.ownNumber("0788 123 456")?.destination == "0788123456")
        #expect(Recipient.ownNumber("+250 732 561 240")?.network == .airtel)
        #expect(Recipient.ownNumber("0712345678") == nil)
        #expect(Recipient.ownNumber("020205") == nil)
        #expect(OwnerProfile(name: " Shima ", number: "0788123456").recipient?.name == "Shima")
        #expect(OwnerProfile(name: "", number: "0788123456").recipient?.name == nil)
        #expect(OwnerProfile(name: "Shima").recipient == nil)
    }
}
