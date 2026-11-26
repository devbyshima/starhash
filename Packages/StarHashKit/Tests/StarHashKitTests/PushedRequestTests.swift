import Foundation
import Testing
@testable import StarHashKit

/// A request pushed sealed, opened on the iPhone asked: shown only when it
/// passes the checks the app makes on any request from anywhere.
@Suite(.english)
struct PushedRequestTests {
    let asker = RequestSeal.makeKey()
    let owner = RequestSeal.makeKey()
    let ask = MoneyRequest.Message.Ask(id: UUID(), name: "JB", number: "0788123456", photoID: nil, amount: 1_500, note: "Lunch")

    /// The push for `ask`, sealed by `sealer` (the asker unless said).
    func pushed(_ ask: MoneyRequest.Message.Ask? = nil, sealer: RequestSeal.PrivateKey? = nil, id: UUID? = nil) throws -> PushedRequest.Sealed {
        let ask = ask ?? self.ask
        let sealer = sealer ?? asker
        let sealed = try #require(RequestSeal.seal(
            MoneyRequest.Message.ask(ask).data, id: id ?? ask.id, purpose: .ask, to: RequestSeal.publicKey(of: owner), from: sealer
        ))
        return PushedRequest.Sealed(id: id ?? ask.id, sealed: sealed, key: RequestSeal.publicKey(of: sealer))
    }

    /// The directory listing `ask`'s number under `key` (the asker's unless said).
    func listed(_ key: String? = nil) -> (String) async -> RequestsAnywhere.LookUp {
        let key = key ?? RequestSeal.publicKey(of: asker)
        return { _ in .listed(.init(name: "JB", photoID: nil, key: key)) }
    }

    let saved: (Recipient) async -> PushedRequest.Contact = { _ in .saved("Jean Bosco") }

    @Test func aRequestFromAContactListedUnderItsSealerOpensUnderTheirContactsName() async throws {
        let opened = try #require(await PushedRequest.open(try pushed(), with: owner, lookUp: listed(), contact: saved))
        #expect(opened.ask == ask && opened.name == "Jean Bosco")
        let text = PushedRequest.text(for: opened, showsAmounts: true)
        #expect(text.title == "Request for 1,500 RWF from Jean Bosco")
        #expect(text.body == "Lunch")
        // Amounts hidden on the Lock Screen: who asks, and nothing more.
        let hidden = PushedRequest.text(for: opened, showsAmounts: false)
        #expect(hidden.title == "Request from Jean Bosco" && hidden.body.isEmpty)
    }

    @Test func theContactIsAskedAboutTheSealedNumber() async throws {
        var asked: Recipient?
        _ = await PushedRequest.open(try pushed(), with: owner, lookUp: listed()) { recipient in
            asked = recipient
            return .saved("Jean Bosco")
        }
        #expect(asked?.destination == "0788123456")
    }

    @Test func anythingTheAppWouldNotShowKeepsThePushsOwnWords() async throws {
        let stranger = RequestSeal.makeKey()
        // Sealed by a key the number is not listed under: someone else
        // asking in its name.
        #expect(await PushedRequest.open(try pushed(sealer: stranger), with: owner, lookUp: listed(), contact: saved) == nil)
        // Listed under another key, not listed, or the server not reached.
        let other = RequestSeal.publicKey(of: stranger)
        #expect(await PushedRequest.open(try pushed(), with: owner, lookUp: listed(other), contact: saved) == nil)
        #expect(await PushedRequest.open(try pushed(), with: owner, lookUp: { _ in .notListed }, contact: saved) == nil)
        #expect(await PushedRequest.open(try pushed(), with: owner, lookUp: { _ in .failed }, contact: saved) == nil)
        // Not a contact, or Contacts cannot be read.
        #expect(await PushedRequest.open(try pushed(), with: owner, lookUp: listed()) { _ in .unknown } == nil)
        #expect(await PushedRequest.open(try pushed(), with: owner, lookUp: listed()) { _ in .cannotTell } == nil)
        // Sealed for another iPhone, under another id, or changed on the way.
        #expect(await PushedRequest.open(try pushed(), with: stranger, lookUp: listed(), contact: saved) == nil)
        var moved = try pushed()
        moved.id = UUID()
        #expect(await PushedRequest.open(moved, with: owner, lookUp: listed(), contact: saved) == nil)
        let inside = MoneyRequest.Message.Ask(id: UUID(), name: "JB", number: "0788123456", photoID: nil, amount: 1_500, note: nil)
        #expect(await PushedRequest.open(try pushed(inside, id: ask.id), with: owner, lookUp: listed(), contact: saved) == nil)
    }

    @Test func thePushCarriesItUnderSealed() throws {
        let pushed = try pushed()
        let userInfo: [AnyHashable: Any] = [
            "aps": ["alert": ["loc-key": "New request"]],
            "sealed": ["id": pushed.id.uuidString.lowercased(), "sealed": pushed.sealed, "key": pushed.key],
        ]
        #expect(PushedRequest.Sealed(userInfo: userInfo) == pushed)
        #expect(PushedRequest.Sealed(userInfo: ["aps": [:]]) == nil)
        #expect(PushedRequest.Sealed(userInfo: ["sealed": ["id": "x", "sealed": pushed.sealed, "key": pushed.key]]) == nil)
        #expect(PushedRequest.Sealed(userInfo: ["sealed": ["id": pushed.id.uuidString, "sealed": pushed.sealed, "key": "short"]]) == nil)
    }
}
