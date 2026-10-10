import Foundation

/// Everything StarHash keeps that is worth taking to another iPhone, as one
/// JSON file: the transactions, Buy's codes and the owner's profile. Made
/// by Export in Settings and read back by Import, which adds what is not
/// already there rather than replacing anything.
public struct StarHashBackup: Codable, Sendable {
    /// What the file says it is, so Import can turn anything else away.
    public static let format = "starhash-backup"
    /// Raised when the file changes in a way an older StarHash cannot read.
    public static let currentVersion = 1

    public var format: String
    public var version: Int
    public var exportedAt: Date
    /// The version of StarHash that made it ("1.1.0").
    public var appVersion: String?
    public var transactions: [Transaction]
    public var shortcuts: [USSDShortcut]?
    public var profile: OwnerProfile?

    public init(
        exportedAt: Date = .now,
        appVersion: String? = nil,
        transactions: [Transaction],
        shortcuts: [USSDShortcut]? = nil,
        profile: OwnerProfile? = nil
    ) {
        format = Self.format
        version = Self.currentVersion
        self.exportedAt = exportedAt
        self.appVersion = appVersion
        self.transactions = transactions
        self.shortcuts = shortcuts
        self.profile = profile
    }

    public enum ReadError: Error, Equatable {
        /// Not JSON, or not StarHash's.
        case notABackup
        /// From a newer StarHash than this one.
        case tooNew
    }

    public func encoded() throws -> Data {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(self)
    }

    /// Reads a backup file. A file that is a bare list of transactions (the
    /// store's own file, copied out) reads too.
    public static func decode(_ data: Data) throws(ReadError) -> StarHashBackup {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        if let backup = try? decoder.decode(StarHashBackup.self, from: data) {
            guard backup.format == format else { throw .notABackup }
            guard backup.version <= currentVersion else { throw .tooNew }
            return backup
        }
        if let transactions = try? decoder.decode([Transaction].self, from: data) {
            return StarHashBackup(transactions: transactions)
        }
        throw .notABackup
    }

    /// "StarHash 2026-10-10.json"
    public static func fileName(on date: Date = .now, calendar: Calendar = .current) -> String {
        let parts = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "StarHash %04d-%02d-%02d.json", parts.year ?? 0, parts.month ?? 0, parts.day ?? 0)
    }
}

/// The owner's own details, for the QR code others scan to pay them: their
/// name and their wallet number. Both optional; the code needs the number.
public struct OwnerProfile: Codable, Hashable, Sendable {
    public var name: String?
    /// A Rwandan mobile number in local form (0788123456).
    public var number: String?
    /// The face the owner picked for their profile, by the app's name for
    /// it.
    public var avatar: String?

    public init(name: String? = nil, number: String? = nil, avatar: String? = nil) {
        self.name = name
        self.number = number
        self.avatar = avatar
    }

    /// Who pays the owner: their number, named, when it is one.
    public var recipient: Recipient? {
        guard let number, var recipient = Recipient.ownNumber(number) else { return nil }
        let trimmed = name?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        recipient.name = trimmed.isEmpty ? nil : trimmed
        return recipient
    }
}

extension USSDShortcutList {
    /// Adds the codes this list does not have yet, by id and by code, at
    /// the end, unpinned once eight are. Returns how many it added.
    @discardableResult
    public func merge(_ incoming: [USSDShortcut]) -> Int {
        var added = 0
        for shortcut in incoming {
            guard !shortcuts.contains(where: { $0.id == shortcut.id || $0.code == shortcut.code }),
                  add(name: shortcut.name, code: shortcut.code, detail: shortcut.detail, symbol: shortcut.symbol),
                  let new = shortcuts.last else { continue }
            if shortcut.isPinned { setPinned(new.id, true) }
            added += 1
        }
        return added
    }
}
