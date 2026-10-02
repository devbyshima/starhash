#if DEBUG
import Foundation
import StarHashKit

/// Launch arguments for screenshots and previews (DEBUG builds only):
///   -inMemory        a fresh in-memory store with sample transactions
///   -tab <name>      pay, activity or settings
///   -skipOnboarding  start on the tabs
@MainActor
enum DebugLaunch {
    static let arguments = ProcessInfo.processInfo.arguments

    static var inMemory: Bool { arguments.contains("-inMemory") }

    static func value(after flag: String) -> String? {
        guard let i = arguments.firstIndex(of: flag), i + 1 < arguments.count else { return nil }
        return arguments[i + 1]
    }

    static func seededStore() -> StarHashStore {
        let store = StarHashStore(fileURL: nil)
        for t in SampleData.transactions() { store.add(t) }
        return store
    }
}
#endif
