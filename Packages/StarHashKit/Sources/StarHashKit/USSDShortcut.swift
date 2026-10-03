import Foundation
import Observation

/// A code Buy keeps on hand to dial in a tap: a name, the code, and for the
/// ones StarHash comes with, a line on what it does and a symbol.
public struct USSDShortcut: Codable, Hashable, Identifiable, Sendable {
    public var id: UUID
    public var name: String
    public var code: String
    /// What it does ("Approve payments waiting for you"), or the person's
    /// own note; none if they left it empty.
    public var detail: String?
    /// The SF Symbol it shows, chosen when it is added; none shows a plain
    /// one in the app.
    public var symbol: String?
    /// Pinned to the top of Buy, where a tap dials it at once.
    public var isPinned: Bool

    public init(id: UUID = UUID(), name: String, code: String, detail: String? = nil, symbol: String? = nil, isPinned: Bool = false) {
        self.id = id
        self.name = name
        self.code = code
        self.detail = detail
        self.symbol = symbol
        self.isPinned = isPinned
    }

    /// A list saved before pinning came in has no `isPinned`: unpinned.
    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        code = try container.decode(String.self, forKey: .code)
        detail = try container.decodeIfPresent(String.self, forKey: .detail)
        symbol = try container.decodeIfPresent(String.self, forKey: .symbol)
        isPinned = try container.decodeIfPresent(Bool.self, forKey: .isPinned) ?? false
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
            detail: "Start a withdrawal at an agent",
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
            symbol: "parkingsign"
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

    /// Adds a code at the end, with its symbol and an optional note. False,
    /// and nothing added, for a name left empty or a code that is not one.
    @discardableResult
    public func add(name: String, code: String, detail: String? = nil, symbol: String? = nil) -> Bool {
        let name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty, let code = USSDShortcut.code(from: code) else { return false }
        shortcuts.append(USSDShortcut(name: name, code: code, detail: Self.note(detail), symbol: symbol))
        save()
        return true
    }

    /// Changes one: its name, code, note and symbol. False, and nothing
    /// changed, as `add`.
    @discardableResult
    public func update(_ id: USSDShortcut.ID, name: String, code: String, detail: String? = nil, symbol: String? = nil) -> Bool {
        let name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty, let code = USSDShortcut.code(from: code),
              let index = shortcuts.firstIndex(where: { $0.id == id }) else { return false }
        shortcuts[index].name = name
        shortcuts[index].code = code
        shortcuts[index].detail = Self.note(detail)
        shortcuts[index].symbol = symbol
        save()
        return true
    }

    /// A note with nothing in it is no note.
    private static func note(_ detail: String?) -> String? {
        let trimmed = detail?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmed.isEmpty ? nil : trimmed
    }

    /// The pinned codes, in the list's order.
    public var pinned: [USSDShortcut] { shortcuts.filter(\.isPinned) }
    /// The rest, in the list's order.
    public var unpinned: [USSDShortcut] { shortcuts.filter { !$0.isPinned } }

    /// How many codes can be pinned: two rows of four at most.
    public static let maxPinned = 8

    /// Whether one more can be pinned.
    public var canPin: Bool { pinned.count < Self.maxPinned }

    /// Pins or unpins one. False, and nothing pinned, when eight already
    /// are.
    @discardableResult
    public func setPinned(_ id: USSDShortcut.ID, _ isPinned: Bool) -> Bool {
        guard let index = shortcuts.firstIndex(where: { $0.id == id }) else { return false }
        if isPinned, !shortcuts[index].isPinned, !canPin { return false }
        shortcuts[index].isPinned = isPinned
        save()
        return true
    }

    /// Moves a pinned code to where `target` is, the codes between
    /// shuffling along: dragging one pinned tile over another. Pinned
    /// codes keep the list's order, so this is their order too.
    public func movePinned(_ id: USSDShortcut.ID, to target: USSDShortcut.ID) {
        guard id != target,
              let from = shortcuts.firstIndex(where: { $0.id == id }),
              let to = shortcuts.firstIndex(where: { $0.id == target }),
              shortcuts[from].isPinned, shortcuts[to].isPinned else { return }
        // Out, then in where the target was: after it when moving down the
        // list, before it when moving up.
        let moving = shortcuts.remove(at: from)
        shortcuts.insert(moving, at: to)
        save()
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
