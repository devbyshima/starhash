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
        var profile = AppEnvironment.owner.profile
        profile.photo = ProfilePhoto.shared.data
        let backup = StarHashBackup(
            appVersion: SettingsVersion.short,
            transactions: store.transactions,
            shortcuts: shortcuts.shortcuts,
            profile: profile.name?.isEmpty == false || profile.number?.isEmpty == false || profile.photo != nil ? profile : nil
        )
        return BackupDocument(data: try backup.encoded())
    }

    /// What Import added, or why Export or Import didn't work, for the alert
    /// after it.
    struct Outcome: Identifiable {
        let id = UUID()
        let title: String
        let message: String
        /// Nothing was imported or saved, so the haptic is the error one.
        var failed = false

        /// The picked file couldn't be opened or read.
        static var unreadable: Outcome {
            Outcome(title: String(starhash: "Couldn't Open the File"), message: String(starhash: "StarHash couldn't read it. Try saving it to your iPhone first."), failed: true)
        }

        /// Export couldn't make the file, or the save sheet couldn't save it.
        static var notSaved: Outcome {
            Outcome(title: String(starhash: "Couldn't Save the File"), message: String(starhash: "Nothing was saved. Try again, or choose another place."), failed: true)
        }
    }

    /// Closing the save or open sheet comes back as an error; it isn't one.
    static func wasCancelled(_ error: any Error) -> Bool {
        (error as? CocoaError)?.code == .userCancelled
    }

    /// Reads the file at `url` (from the Files picker, so it is opened with
    /// its security scope) and adds what is not already here: transactions,
    /// Buy's codes, and the profile when none is set.
    static func importFile(at url: URL, store: StarHashStore, shortcuts: USSDShortcutList) -> Outcome {
        let scoped = url.startAccessingSecurityScopedResource()
        defer { if scoped { url.stopAccessingSecurityScopedResource() } }
        guard let data = try? Data(contentsOf: url) else { return .unreadable }
        let backup: StarHashBackup
        do {
            backup = try StarHashBackup.decode(data)
        } catch .tooNew {
            return Outcome(title: String(starhash: "Update StarHash First"), message: String(starhash: "This file is from a newer StarHash. Update from the App Store, then import it again."), failed: true)
        } catch {
            return Outcome(title: String(starhash: "Not a StarHash File"), message: String(starhash: "Choose a file you exported from StarHash's Settings."), failed: true)
        }

        let transactions = store.merge(backup.transactions)
        let codes = shortcuts.merge(backup.shortcuts ?? [])
        // The profile only when none is set, its photo with it.
        var addedProfile = false
        if let profile = backup.profile, AppEnvironment.owner.restore(profile) {
            addedProfile = true
            if let photo = profile.photo { ProfilePhoto.shared.restore(photo) }
        }

        guard transactions + codes > 0 else {
            // A profile on its own still counts as imported, not as nothing new.
            if addedProfile {
                return Outcome(title: String(starhash: "Imported"), message: String(starhash: "Added your profile. Nothing already here was changed."))
            }
            return Outcome(title: String(starhash: "Already Up to Date"), message: String(starhash: "Everything in this file is already in StarHash."))
        }
        var parts: [String] = []
        if transactions > 0 { parts.append(transactions == 1 ? String(starhash: "1 transaction") : String(starhash: "\(transactions) transactions")) }
        if codes > 0 { parts.append(codes == 1 ? String(starhash: "1 code") : String(starhash: "\(codes) codes")) }
        let added = parts.joined(separator: String(starhash: " and "))
        var message = String(starhash: "Added \(added). Nothing already here was changed.")
        if addedProfile { message += " " + String(starhash: "Your profile was added too.") }
        return Outcome(title: String(starhash: "Imported"), message: message)
    }
}
