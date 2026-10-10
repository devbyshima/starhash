import Foundation
import Testing
@testable import StarHashKit

@Suite("Widget snapshot")
struct WidgetSnapshotTests {
    static func code(_ name: String, pinned: Bool = false) -> USSDShortcut {
        USSDShortcut(name: name, code: "*182*\(name.count)#", isPinned: pinned)
    }

    @Test func pinnedCodesComeFirst() {
        let snapshot = WidgetSnapshot.make(
            shortcuts: [Self.code("Airtime"), Self.code("Bundles", pinned: true), Self.code("Water"), Self.code("Power", pinned: true)],
            wallet: .mtn
        )
        #expect(snapshot.codes.map(\.name) == ["Bundles", "Power", "Airtime", "Water"])
    }

    @Test func atMostEightCodes() {
        let codes = (1...12).map { Self.code("Code \($0)") }
        #expect(WidgetSnapshot.make(shortcuts: codes, wallet: .airtel).codes.count == 8)
    }

    @Test func survivesTheAppGroup() throws {
        let snapshot = WidgetSnapshot.make(
            shortcuts: [Self.code("Airtime", pinned: true)],
            wallet: .airtel,
            now: Date(timeIntervalSince1970: 1_790_000_000)
        )
        let decoded = try #require(WidgetSnapshot.decode(snapshot.encoded()))
        #expect(decoded == snapshot)
    }
}
