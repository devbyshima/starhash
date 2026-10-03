import Foundation
import Observation

/// A code Buy keeps on hand to dial in a tap: a name, the code, and for the
/// ones StarHash comes with, a line on what it does and a symbol.
public struct USSDShortcut: Codable, Hashable, Identifiable, Sendable {
    public var id: UUID
    public var name: String
    public var code: String
    /// What it does ("Approve payments waiting for you"); none for codes
    /// the person adds.
    public var detail: String?
    /// An SF Symbol; codes the person adds take a plain one in the app.
    public var symbol: String?

    public init(id: UUID = UUID(), name: String, code: String, detail: String? = nil, symbol: String? = nil) {
        self.id = id
        self.name = name
        self.code = code
        self.detail = detail
        self.symbol = symbol
    }

    /// The codes StarHash comes with, MTN MoMo's and MTN's. Fixed ids, so
    /// one edited or deleted stays that way.
    public static let defaults: [USSDShortcut] = [
        USSDShortcut(
            id: UUID(uuidString: "5E2A7C1E-0001-4000-8000-000000000001")!,
            name: "Pending approvals",
            code: "*182*7*1#",
            detail: "Approve payments waiting for you",
            symbol: "checkmark.seal.fill"
        ),
        USSDShortcut(
            id: UUID(uuidString: "5E2A7C1E-0002-4000-8000-000000000002")!,
            name: "Cash out",
            code: "*182*7*2#",
            detail: "Start a withdrawal before the agent's prompt",
            symbol: "banknote.fill"
        ),
        USSDShortcut(
            id: UUID(uuidString: "5E2A7C1E-0003-4000-8000-000000000003")!,
            name: "Gwamon' Pack",
            code: "*154*0#",
            detail: "MTN's minutes and data, for 7 days",
            symbol: "gift.fill"
        ),
        USSDShortcut(
            id: UUID(uuidString: "5E2A7C1E-0004-4000-8000-000000000004")!,
            name: "Airport parking",
            code: "*182*3*8#",
            detail: "Pay a Kigali airport parking ticket",
            symbol: "parkingsign.circle.fill"
        ),
    ]

    /// `input` as a code to dial, or nil if it is not one: spaces dropped,
    /// then a * or # first, a # last, and only digits, * and # between,
    /// with at least one digit (*182*7*1#, #100#).
    public static func code(from input: String) -> String? {
        let code = input.filter { !$0.isWhitespace }
        guard code.count >= 3,
              let first = code.first, first == "*" || first == "#",
              code.last == "#",
              code.allSatisfy({ $0.isASCII && ($0.isNumber || $0 == "*" || $0 == "#") }),
              code.contains(where: \.isNumber)
        else { return nil }
        return code
    }
}

/// Buy's codes, kept on the device in UserDefaults: the defaults until the
/// person changes the list, then theirs, in their order.
@MainActor
@Observable
public final class USSDShortcutList {
    public private(set) var shortcuts: [USSDShortcut]

    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored private let key: String

    public init(defaults: UserDefaults = .standard, key: String = "buyShortcuts") {
        self.defaults = defaults
        self.key = key
        if let data = defaults.data(forKey: key),
           let saved = try? JSONDecoder().decode([USSDShortcut].self, from: data) {
            shortcuts = saved
        } else {
            shortcuts = USSDShortcut.defaults
        }
    }

    /// Adds a code at the end. False, and nothing added, for a name left
    /// empty or a code that is not one.
    @discardableResult
    public func add(name: String, code: String) -> Bool {
        let name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty, let code = USSDShortcut.code(from: code) else { return false }
        shortcuts.append(USSDShortcut(name: name, code: code))
        save()
        return true
    }

    /// Renames or recodes one. False, and nothing changed, as `add`.
    @discardableResult
    public func update(_ id: USSDShortcut.ID, name: String, code: String) -> Bool {
        let name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty, let code = USSDShortcut.code(from: code),
              let index = shortcuts.firstIndex(where: { $0.id == id }) else { return false }
        shortcuts[index].name = name
        shortcuts[index].code = code
        save()
        return true
    }

    public func remove(_ id: USSDShortcut.ID) {
        shortcuts.removeAll { $0.id == id }
        save()
    }

    /// Back to the defaults, forgetting every change (Delete All Data).
    public func reset() {
        defaults.removeObject(forKey: key)
        shortcuts = USSDShortcut.defaults
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(shortcuts) else { return }
        defaults.set(data, forKey: key)
    }
}
