import Foundation

/// What StarHash's widgets show, written by the app whenever Buy's codes or
/// the wallet change and read by the widget extension: Buy's codes, for the
/// Buy widget to dial and its owner to choose from, and the wallet, for
/// Quick Pay's balance code. Kept in the App Group the two share,
/// when the build has one; without it the widget falls back to
/// `placeholder`.
public struct WidgetSnapshot: Codable, Equatable, Sendable {
    /// Every one of Buy's codes: the pinned ones, then the rest, in Buy's
    /// order. The Buy widget shows the first ones until its owner chooses.
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
        return WidgetSnapshot(codes: ordered, wallet: wallet, updatedAt: now)
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
