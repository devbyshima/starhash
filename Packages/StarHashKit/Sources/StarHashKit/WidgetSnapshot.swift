import Foundation

/// What StarHash's Buy widget shows, written by the app whenever it goes to
/// the background and read by the widget extension: Buy's codes to dial and
/// the wallet, for its balance code. Kept in the App Group the two share,
/// when the build has one; without it the widget falls back to
/// `placeholder`.
public struct WidgetSnapshot: Codable, Equatable, Sendable {
    /// The codes the widget offers: the pinned ones, then the rest, in Buy's
    /// order, at most eight.
    public var codes: [USSDShortcut]
    public var wallet: Recipient.Network
    public var updatedAt: Date

    public init(codes: [USSDShortcut], wallet: Recipient.Network, updatedAt: Date) {
        self.codes = codes
        self.wallet = wallet
        self.updatedAt = updatedAt
    }

    /// The defaults key, in the App Group's defaults.
    public static let key = "widgetSnapshot"

    /// Before the app has written one, or where no App Group is shared:
    /// StarHash's own codes.
    public static let placeholder = WidgetSnapshot(codes: USSDShortcut.defaults, wallet: .mtn, updatedAt: .distantPast)

    /// The snapshot of `shortcuts` as they stand at `now`.
    public static func make(shortcuts: [USSDShortcut], wallet: Recipient.Network, now: Date = .now) -> WidgetSnapshot {
        let ordered = shortcuts.filter(\.isPinned) + shortcuts.filter { !$0.isPinned }
        return WidgetSnapshot(codes: Array(ordered.prefix(8)), wallet: wallet, updatedAt: now)
    }

    public func encoded() -> Data? {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return try? encoder.encode(self)
    }

    public static func decode(_ data: Data?) -> WidgetSnapshot? {
        guard let data else { return nil }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try? decoder.decode(WidgetSnapshot.self, from: data)
    }
}
