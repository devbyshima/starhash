import Foundation

/// A marketing version as numbers, so 1.10.0 comes after 1.9.0. Missing
/// parts count as 0 ("1.2" is 1.2.0); anything but digits and dots is not
/// a version.
public struct AppVersion: Comparable, Hashable, Sendable {
    public let parts: [Int]

    public init?(_ string: String) {
        let pieces = string.split(separator: ".", omittingEmptySubsequences: false)
        guard !pieces.isEmpty, pieces.count <= 3 else { return nil }
        var parts: [Int] = []
        for piece in pieces {
            guard !piece.isEmpty, piece.allSatisfy(\.isASCII), let number = Int(piece), number >= 0 else { return nil }
            parts.append(number)
        }
        self.parts = parts + Array(repeating: 0, count: 3 - parts.count)
    }

    public static func < (lhs: AppVersion, rhs: AppVersion) -> Bool {
        lhs.parts.lexicographicallyPrecedes(rhs.parts)
    }
}

/// When the What's New sheet shows: once, as the first launch after an
/// update, and never on a fresh install, so someone new meets StarHash
/// through onboarding rather than a list of changes.
public enum WhatsNew {
    /// The release whose sheet to show as `current` launches, or nil.
    ///
    /// It is the newest release with an announcement that is newer than the
    /// version that ran before and no newer than this one, so an update
    /// that skips a version shows the newest news, and a patch after an
    /// announced version shows that version's if it was never seen.
    ///
    /// - Parameters:
    ///   - lastRun: The version that last ran on this iPhone, nil when none
    ///     was recorded.
    ///   - hasUsedApp: Whether this install was set up before. With no
    ///     `lastRun`, a used install is an update from a version that kept
    ///     no record (1.0), and an unused one is new.
    public static func release(
        toAnnounce current: String,
        lastRun: String?,
        hasUsedApp: Bool,
        in releases: [Release]
    ) -> Release? {
        guard let now = AppVersion(current) else { return nil }
        let before: AppVersion?
        if let lastRun {
            guard let then = AppVersion(lastRun), then < now else { return nil }
            before = then
        } else {
            guard hasUsedApp else { return nil }
            before = nil
        }
        return releases
            .compactMap { release -> (AppVersion, Release)? in
                guard release.announcement != nil, let version = AppVersion(release.version) else { return nil }
                guard version <= now, before.map({ version > $0 }) ?? true else { return nil }
                return (version, release)
            }
            .max { $0.0 < $1.0 }?
            .1
    }
}
