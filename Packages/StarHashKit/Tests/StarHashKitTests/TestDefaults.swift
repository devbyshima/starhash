import Foundation

/// UserDefaults of one test's own, gone with the last thing that holds it.
/// A suite named like an app's is a plist in ~/Library/Preferences that
/// outlives the run, and one left behind by every test piled up in the
/// thousands. Deleting that file is not enough: cfprefsd writes the suite
/// out again seconds later. A suite named by a path is kept at that path
/// instead, so this one lives in a folder of its own that can go for good.
final class TestDefaults: UserDefaults, @unchecked Sendable {
    /// The name to hand `removePersistentDomain(forName:)`, as Delete All
    /// Data does.
    let suiteName: String
    private let folder: URL

    init(_ tests: String) {
        folder = FileManager.default.temporaryDirectory.appending(path: "\(tests)-\(UUID().uuidString)", directoryHint: .isDirectory)
        // Without the folder the suite still works, in memory only.
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        suiteName = folder.appending(path: tests).path
        // Only the app's own domain and the global one are refused.
        super.init(suiteName: suiteName)!
    }

    deinit {
        // A write still on its way finds no folder and goes nowhere.
        try? FileManager.default.removeItem(at: folder)
    }
}
