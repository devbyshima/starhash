import Foundation
import Testing
@testable import StarHashKit

@MainActor
struct USSDShortcutTests {
    private func freshDefaults() -> UserDefaults {
        let name = "USSDShortcutTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        defaults.removePersistentDomain(forName: name)
        return defaults
    }

    @Test func startsWithTheFourDefaults() {
        let list = USSDShortcutList(defaults: freshDefaults())
        #expect(list.shortcuts.map(\.code) == ["*182*7*1#", "*182*7*2#", "*154*0#", "*182*3*8#"])
    }

    @Test func acceptsOnlyRealCodes() {
        #expect(USSDShortcut.code(from: " *182 *7*1# ") == "*182*7*1#")
        #expect(USSDShortcut.code(from: "#100#") == "#100#")
        #expect(USSDShortcut.code(from: "182#") == nil)
        #expect(USSDShortcut.code(from: "*182*7") == nil)
        #expect(USSDShortcut.code(from: "*abc#") == nil)
        #expect(USSDShortcut.code(from: "*#") == nil)
        #expect(USSDShortcut.code(from: "*1٢3#") == nil)
    }

    @Test func addsEditsAndRemovesAndRemembers() {
        let defaults = freshDefaults()
        let list = USSDShortcutList(defaults: defaults)
        #expect(list.add(name: "  Airtime ", code: "*182*2*1#"))
        #expect(!list.add(name: "", code: "*182*2*1#"))
        #expect(!list.add(name: "Nope", code: "182"))
        let added = list.shortcuts.last!
        #expect(added.name == "Airtime")

        #expect(added.detail == nil && added.symbol == nil)

        #expect(list.update(added.id, name: "Top up", code: "*182*2*1*1#", detail: "  For my number ", symbol: "phone.fill"))
        list.remove(USSDShortcut.defaults[0].id)

        let reloaded = USSDShortcutList(defaults: defaults)
        #expect(reloaded.shortcuts.count == 4)
        #expect(reloaded.shortcuts.last?.name == "Top up")
        #expect(reloaded.shortcuts.last?.code == "*182*2*1*1#")
        #expect(reloaded.shortcuts.last?.detail == "For my number")
        #expect(reloaded.shortcuts.last?.symbol == "phone.fill")
        #expect(!reloaded.shortcuts.contains { $0.id == USSDShortcut.defaults[0].id })

        reloaded.reset()
        #expect(reloaded.shortcuts == USSDShortcut.defaults)
        #expect(USSDShortcutList(defaults: defaults).shortcuts == USSDShortcut.defaults)
    }
}
