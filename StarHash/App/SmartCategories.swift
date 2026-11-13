import Foundation
import StarHashKit
#if canImport(FoundationModels)
import FoundationModels
#endif

/// Sorts payments into categories (`TransactionCategory`), so Activity can
/// tell airtime bought from money sent. The rules (`TransactionCategorizer`) go first, on every payment;
/// on iOS 26 and later with Apple Intelligence, the on-device model names
/// what the rules cannot from the merchant's name alone. Nothing leaves the
/// iPhone: the model runs on it, and only a name is asked about, never an
/// amount or a number. A category chosen by hand is never changed.
@MainActor
enum SmartCategories {
    /// Names the model has been asked about, so each is asked once.
    private static let askedKey = "smartCategoriesAsked"
    private static var running = false

    /// Whether the on-device model is there to ask.
    static var isAvailable: Bool {
        #if canImport(FoundationModels)
        if #available(iOS 26.0, *) {
            return SystemLanguageModel.default.availability == .available
        }
        #endif
        return false
    }

    /// Fills in what it can: by the rules at once, then by the model, a
    /// few names at a time, while StarHash is open.
    static func run(on store: StarHashStore) async {
        guard Preferences.smartCategories.value(), !running else { return }
        running = true
        defer { running = false }

        store.categorizeByRules()
        guard isAvailable else { return }
        // What the rules could not name, by the name it was paid under.
        let byName = Dictionary(grouping: store.transactions.filter { $0.awaitsCategory && !($0.counterparty.name ?? "").isEmpty }) {
            $0.counterparty.name ?? ""
        }
        guard !byName.isEmpty else { return }

        var asked = Set(UserDefaults.standard.stringArray(forKey: askedKey) ?? [])
        for name in byName.keys.sorted() where !asked.contains(name.lowercased()) {
            guard !Task.isCancelled else { break }
            asked.insert(name.lowercased())
            guard let category = await ask(about: name) else { continue }
            // Fills only a gap: one named by hand, or gone, while the model
            // thought is left as it is.
            for t in byName[name] ?? [] { store.fillCategory(category, for: t.id) }
        }
        UserDefaults.standard.set(Array(asked), forKey: askedKey)
    }

    /// Forgets which names were asked about (Delete All Data).
    static func reset() {
        UserDefaults.standard.removeObject(forKey: askedKey)
    }

    private static func ask(about name: String) async -> TransactionCategory? {
        #if canImport(FoundationModels)
        if #available(iOS 26.0, *) {
            let session = LanguageModelSession(instructions: """
                You sort payments made with mobile money in Rwanda into categories. \
                You are given only the name of the business that was paid. \
                Choose the category it most likely belongs to. Choose other when the name gives no clue.
                """)
            guard let response = try? await session.respond(
                to: "Business name: \(name)",
                generating: ModelCategory.self
            ) else { return nil }
            return response.content.category
        }
        #endif
        return nil
    }
}

#if canImport(FoundationModels)
/// The categories as the model chooses from them.
@available(iOS 26.0, *)
@Generable(description: "What a payment to a business was for")
enum ModelCategory {
    case airtime
    case bundles
    case electricity
    case water
    case tv
    case restaurant
    case groceries
    case transport
    case bills
    case shopping
    case health
    case education
    case family
    case gifts
    case savings
    case other

    var category: TransactionCategory? {
        TransactionCategory(rawValue: String(describing: self))
    }
}
#endif
