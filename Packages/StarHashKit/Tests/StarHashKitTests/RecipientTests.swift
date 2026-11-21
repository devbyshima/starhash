import Testing
@testable import StarHashKit

@Suite struct RecipientTests {
    @Test func tenDigitsIsAPhone() {
        let r = Recipient(input: "0781234567")
        #expect(r?.kind == .phone)
        #expect(r?.destination == "0781234567")
    }

    @Test func internationalNumberBecomesLocal() {
        #expect(Recipient(input: "+250 781 234 567")?.destination == "0781234567")
    }

    @Test func fewerThanTenDigitsIsAMerchantCode() {
        let r = Recipient(input: "020205")
        #expect(r?.kind == .merchant)
        #expect(r?.destination == "020205")
    }

    /// A merchant code has no network, so the input must read first: nil
    /// from a failed read would pass for it.
    @Test(arguments: [
        ("0781234567", Recipient.Network.mtn),
        ("0791234567", .mtn),
        ("0722497291", .airtel),
        ("+250 733 123 456", .airtel),
        ("020205", nil),
    ] as [(String, Recipient.Network?)])
    func networkComesFromThePrefix(input: String, network: Recipient.Network?) throws {
        let recipient = try #require(Recipient(input: input))
        #expect(recipient.network == network)
    }

    @Test func noDigitsIsNil() {
        #expect(Recipient(input: "abc") == nil)
    }

    @Test(arguments: [
        ("0781234567", 5000, "*182*1*1*0781234567*5000#"),
        ("020205", 15000, "*182*8*1*020205*15000#"),
        ("0722497291", 5000, "*182*1*2*0722497291*5000#"),
        ("+250 731 234 567", 700, "*182*1*2*0731234567*700#"),
        ("0791234567", 700, "*182*1*1*0791234567*700#"),
    ])
    func ussdCodesFromMTN(input: String, amount: Int, code: String) throws {
        let recipient = try #require(Recipient(input: input))
        #expect(USSD.payment(to: recipient, amount: amount, from: .mtn) == code)
    }

    @Test func mtnCodesDialAsTelURLs() throws {
        #expect(USSD.telURL(for: USSD.balance(for: .mtn))?.absoluteString == "tel:*182*6*1%23")
        let send = USSD.payment(to: try #require(Recipient(input: "+250 781 234 567")), amount: 5000, from: .mtn)
        #expect(USSD.telURL(for: send)?.absoluteString == "tel:*182*1*1*0781234567*5000%23")
    }

    /// Airtel Money mirrors MTN's menu: its own network is 1, 1 and MTN is
    /// the other network, 1, 2.
    @Test(arguments: [
        ("0722497291", 5000, "*182*1*1*0722497291*5000#"),
        ("0731234567", 700, "*182*1*1*0731234567*700#"),
        ("0781234567", 5000, "*182*1*2*0781234567*5000#"),
        ("0791234567", 700, "*182*1*2*0791234567*700#"),
        ("020205", 15000, "*182*8*1*020205*15000#"),
    ])
    func ussdCodesFromAirtel(input: String, amount: Int, code: String) throws {
        let recipient = try #require(Recipient(input: input))
        #expect(USSD.payment(to: recipient, amount: amount, from: .airtel) == code)
    }

    @Test func airtelsBalanceDialsAsATelURL() {
        #expect(USSD.telURL(for: USSD.balance(for: .airtel))?.absoluteString == "tel:*182%23")
    }

    @Test func nineDigitsIsStillAMerchantCode() {
        #expect(Recipient(input: "123456789")?.kind == .merchant)
        #expect(Recipient(input: "1234567890")?.kind == .phone)
    }

    @Test func onlyFullNumbersAndCodesArePayable() {
        #expect(Recipient(input: "0781234567")?.isPayable == true)
        #expect(Recipient(input: "+250 722 123 456")?.isPayable == true)
        // Abroad or a landline: no wallet code pays them.
        #expect(Recipient(input: "+1 415 555 1234")?.isPayable == false)
        #expect(Recipient(input: "0252 123 456")?.isPayable == false)
        #expect(Recipient(input: "020205")?.isPayable == true)
        // Masked senders and bank deposits read from an SMS.
        #expect(Recipient(name: "Ariane", destination: "998", kind: .phone).isPayable == false)
        #expect(Recipient(name: "Bank deposit", destination: "", kind: .merchant).isPayable == false)
    }

    @Test func money() {
        #expect(Money.format(1072780) == "1,072,780")
        #expect(Money.format(700) == "700")
        #expect(Money.compact(843_000) == "843k")
        #expect(Money.compact(13_100_000) == "13.1M")
    }
}
