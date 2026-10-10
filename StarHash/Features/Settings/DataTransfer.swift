import StarHashKit
import SwiftUI
import UniformTypeIdentifiers

/// Export and Import in Settings: everything StarHash keeps as one JSON
/// file (`StarHashBackup`), saved wherever the owner chooses (Files, iCloud
/// Drive, AirDrop to another iPhone), and read back by adding what is not
/// already here. Nothing is ever sent anywhere by StarHash itself.
struct BackupDocument: FileDocument {
    static let readableContentTypes: [UTType] = [.json]

    let data: Data

    init(data: Data) {
        self.data = data
    }

    init(configuration: ReadConfiguration) throws {
        data = configuration.file.regularFileContents ?? Data()
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}

@MainActor
enum DataTransfer {
    /// The backup of everything as it stands now.
    static func export(store: StarHashStore, shortcuts: USSDShortcutList) throws -> BackupDocument {
        let profile = StarHashPreferences.profile
        let backup = StarHashBackup(
            appVersion: SettingsVersion.short,
            transactions: store.transactions,
            shortcuts: shortcuts.shortcuts,
            profile: profile.name?.isEmpty == false || profile.number?.isEmpty == false || profile.avatar != nil ? profile : nil
        )
        return BackupDocument(data: try backup.encoded())
    }

    /// What Import added, for the alert after it.
    struct Outcome: Identifiable {
        let id = UUID()
        let title: String
        let message: String
    }

    /// Reads the file at `url` (from the Files picker, so it is opened with
    /// its security scope) and adds what is not already here: transactions,
    /// Buy's codes, and the profile when none is set.
    static func importFile(at url: URL, store: StarHashStore, shortcuts: USSDShortcutList) -> Outcome {
        let scoped = url.startAccessingSecurityScopedResource()
        defer { if scoped { url.stopAccessingSecurityScopedResource() } }
        guard let data = try? Data(contentsOf: url) else {
            return Outcome(title: String(localized: "Couldn't Open the File"), message: String(localized: "StarHash couldn't read it. Try saving it to your iPhone first."))
        }
        let backup: StarHashBackup
        do {
            backup = try StarHashBackup.decode(data)
        } catch .tooNew {
            return Outcome(title: String(localized: "Update StarHash First"), message: String(localized: "This file is from a newer StarHash. Update from the App Store, then import it again."))
        } catch {
            return Outcome(title: String(localized: "Not a StarHash File"), message: String(localized: "Choose a file you exported from StarHash's Settings."))
        }

        let transactions = store.merge(backup.transactions)
        let codes = shortcuts.merge(backup.shortcuts ?? [])
        if let profile = backup.profile {
            let current = StarHashPreferences.profile
            if (current.number ?? "").isEmpty, (current.name ?? "").isEmpty { StarHashPreferences.saveProfile(profile) }
        }

        guard transactions + codes > 0 else {
            return Outcome(title: String(localized: "Already Up to Date"), message: String(localized: "Everything in this file is already in StarHash."))
        }
        var parts: [String] = []
        if transactions > 0 { parts.append(transactions == 1 ? String(localized: "1 transaction") : String(localized: "\(transactions) transactions")) }
        if codes > 0 { parts.append(codes == 1 ? String(localized: "1 code") : String(localized: "\(codes) codes")) }
        let added = parts.joined(separator: String(localized: " and "))
        return Outcome(title: String(localized: "Imported"), message: String(localized: "Added \(added). Nothing already here was changed."))
    }
}
