import Foundation

/// Where `StarHashStore` keeps its transactions: the store's one seam to
/// storage. On the phone, one JSON file (`JSONTransactionFile`); in tests
/// and previews, memory (`MemoryTransactionFile`), which can also play the
/// file sealed or damaged.
@MainActor
public protocol TransactionFile: AnyObject {
    /// What the file holds now.
    func read() -> TransactionFileState
    /// Every transaction, replacing what was there.
    func write(_ transactions: [Transaction])
    /// A damaged file moved out of the way, never overwritten, so it can
    /// still be recovered.
    func setAside()
    /// The file and every copy set aside, gone (Delete All Data).
    func erase()
}

/// What reading a `TransactionFile` found.
public enum TransactionFileState: Equatable, Sendable {
    /// Nothing saved yet: a fresh install.
    case missing
    /// There, but not to be read yet: Data Protection keeps it sealed until
    /// the phone is first unlocked after a restart, and the Shortcuts
    /// automation can wake StarHash before that.
    case sealed
    /// There, but not transactions StarHash can decode.
    case damaged
    case read([Transaction])
}

/// The transactions as one JSON file on the phone, readable once it has
/// been unlocked after a restart.
public final class JSONTransactionFile: TransactionFile {
    public let url: URL

    public init(url: URL) {
        self.url = url
    }

    /// Application Support's StarHash/transactions.json.
    public static var standardURL: URL {
        let folder = URL.applicationSupportDirectory.appending(path: "StarHash", directoryHint: .isDirectory)
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        return folder.appending(path: "transactions.json")
    }

    public func read() -> TransactionFileState {
        guard FileManager.default.fileExists(atPath: url.path) else { return .missing }
        guard let data = try? Data(contentsOf: url) else { return .sealed }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        guard let decoded = try? decoder.decode([Transaction].self, from: data) else { return .damaged }
        return .read(decoded)
    }

    /// Readable once the phone has been unlocked after a restart, so the
    /// Process Carrier SMS action can log a payment while it is locked.
    public func write(_ transactions: [Transaction]) {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        if let data = try? encoder.encode(transactions) {
            try? data.write(to: url, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
        }
    }

    /// "transactions.json" becomes "transactions.damaged-<time>.json".
    public func setAside() {
        let stamp = Int(Date.now.timeIntervalSince1970)
        let backup = url.deletingPathExtension().appendingPathExtension("damaged-\(stamp).json")
        try? FileManager.default.moveItem(at: url, to: backup)
    }

    public func erase() {
        let folder = url.deletingLastPathComponent()
        let stem = url.deletingPathExtension().lastPathComponent
        let files = (try? FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil)) ?? []
        for file in files where file.lastPathComponent.hasPrefix(stem) {
            try? FileManager.default.removeItem(at: file)
        }
    }
}

/// The transactions in memory: tests and previews. `isSealed` and
/// `isDamaged` play the file as the phone can find it.
public final class MemoryTransactionFile: TransactionFile {
    /// What was last written; nil until something is.
    public private(set) var saved: [Transaction]?
    public var isSealed = false
    public var isDamaged = false
    /// Damaged files moved aside, in order.
    public private(set) var setAsideCopies: [[Transaction]?] = []

    public init(saved: [Transaction]? = nil) {
        self.saved = saved
    }

    public func read() -> TransactionFileState {
        guard let saved else { return isDamaged ? .damaged : .missing }
        if isSealed { return .sealed }
        return isDamaged ? .damaged : .read(saved)
    }

    public func write(_ transactions: [Transaction]) {
        guard !isSealed else { return }
        saved = transactions
        isDamaged = false
    }

    public func setAside() {
        setAsideCopies.append(saved)
        saved = nil
        isDamaged = false
    }

    public func erase() {
        saved = nil
        setAsideCopies = []
        isDamaged = false
    }
}
