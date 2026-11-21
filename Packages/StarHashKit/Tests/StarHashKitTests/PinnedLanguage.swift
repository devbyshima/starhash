import Foundation
import Testing
@testable import StarHashKit

/// The kit's strings in English for every test under it. They follow the
/// Mac's language otherwise, and the copy these tests read is English.
struct PinnedLanguage: SuiteTrait, TestTrait, TestScoping {
    let locale: Locale

    // Each test gets the scope itself, so the language reaches it however
    // the suite's tests are run.
    var isRecursive: Bool { true }

    func provideScope(
        for test: Test, testCase: Test.Case?, performing function: @Sendable () async throws -> Void
    ) async throws {
        try await StarHashLanguage.$pinned.withValue(locale) {
            try await function()
        }
    }
}

extension Trait where Self == PinnedLanguage {
    static var english: Self { PinnedLanguage(locale: Locale(identifier: "en")) }
}
