import Foundation
import Testing
@testable import StarHashKit

@Suite("StarHash links")
struct StarHashLinkTests {
    /// Every link StarHash makes reads back as what it was made from.
    @Test(arguments: [
        StarHashLink.page(.pay), .page(.buy), .page(.activity), .page(.settings),
        .transaction(UUID(uuidString: "6B0F7D8C-2E31-4C49-9D0A-5A3C8B1E2F40")!),
        .scan,
        .dial(code: "*182*2*6#"),
        .dial(code: "*131#"),
        .shortcutRan(.success), .shortcutRan(.cancel),
        .whatsNew(page: 2),
    ])
    func roundTrips(link: StarHashLink) {
        #expect(StarHashLink(url: link.url) == link)
    }

    @Test func aQRCodesLinkChoosesWhoToPay() throws {
        let aline = Recipient(name: "Aline", destination: "0788123456", kind: .phone)
        let url = PaymentQR.link(for: aline, amount: 5_000)
        guard case .payment(let request) = StarHashLink(url: url) else { Issue.record("not a payment"); return }
        #expect(request.recipient.destination == "0788123456")
        #expect(request.amount == 5_000)
    }

    @Test func oldAndOddLinks() throws {
        #expect(StarHashLink(url: URL(string: "starhash://help")!) == .page(.settings))
        #expect(StarHashLink(url: URL(string: "starhash://pay")!) == .page(.pay))
        #expect(StarHashLink(url: URL(string: "starhash://shortcut/whatever")!) == .shortcutRan(.error))
        #expect(StarHashLink(url: URL(string: "starhash://nowhere")!) == nil)
        #expect(StarHashLink(url: URL(string: "starhash://dial?code=hello")!) == nil)
        #expect(StarHashLink(url: URL(string: "https://starhash.app")!) == nil)
    }

    /// The code is kept out of the URL's own syntax: `#` would end it.
    @Test func aDialLinkEncodesItsCode() {
        #expect(StarHashLink.dial(code: "*182*2*6#").url.absoluteString == "starhash://dial?code=%2A182%2A2%2A6%23")
    }
}
