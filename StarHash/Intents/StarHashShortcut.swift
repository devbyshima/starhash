import SwiftUI
import UIKit

/// The ready-made "StarHash SMS" shortcut auto-verify installs and runs:
/// the Process Carrier SMS action fed the shortcut's input. Its automation
/// (when a message containing RWF arrives, which every M-Money and
/// AirtelMoney message does, run immediately) is made by hand, as the
/// guide shows: the one written into the shared file for iOS 27 never
/// appeared on a real iPhone. It is shared
/// from iCloud, so one tap opens Shortcuts' own Add Shortcut screen. With
/// no link it would fall back to a signed file in the bundle
/// (scripts/make_shortcut.py) through the share sheet; that file is not
/// bundled at present.
@MainActor
enum StarHashShortcut {
    /// The name the shortcut is installed under, and run by.
    static let name = AutoVerificationSample.shortcutName

    /// The shared shortcut for each build's bundle id (Share › Copy iCloud
    /// Link in Shortcuts on iOS 27), made by scripts/make_shortcut.py with
    /// that id: its action names the app by bundle id and team, and
    /// Shortcuts only runs it, and only shows StarHash's icon on it rather
    /// than its own wand, when they are the app's on that iPhone. Share it
    /// again after changing the shortcut: a link is a copy of the shortcut
    /// as it was when shared.
    private static let iCloudLinks: [String: URL] = [:]

    /// The October link, shared from the old id and team
    /// (com.fulltimestudio.starhash, 7WHQR6L96K), kept until each build
    /// has its own above.
    private static let legacyLink = URL(string: "https://www.icloud.com/shortcuts/d13eee82797e4c41b2da5a6b5aa03309")

    static var iCloudLink: URL? {
        Bundle.main.bundleIdentifier.flatMap { iCloudLinks[$0] } ?? legacyLink
    }

    /// Opens Shortcuts on the shortcut's Add Shortcut screen.
    static func install(openURL: OpenURLAction) {
        if let iCloudLink {
            openURL(iCloudLink)
            return
        }
        guard let file = bundledFile() else { return }
        let share = UIActivityViewController(activityItems: [file], applicationActivities: nil)
        topViewController()?.present(share, animated: true)
    }

    /// Runs the shortcut with the sample message and comes back to
    /// StarHash, telling it how the run went (`AppRouter.shortcutCallback`).
    static var verificationURL: URL? {
        var components = URLComponents()
        components.scheme = "shortcuts"
        components.host = "x-callback-url"
        components.path = "/run-shortcut"
        components.queryItems = [
            URLQueryItem(name: "name", value: name),
            URLQueryItem(name: "input", value: "text"),
            URLQueryItem(name: "text", value: AutoVerificationSample.message),
            URLQueryItem(name: "x-success", value: "starhash://shortcut/success"),
            URLQueryItem(name: "x-error", value: "starhash://shortcut/error"),
            URLQueryItem(name: "x-cancel", value: "starhash://shortcut/cancel"),
        ]
        return components.url
    }

    /// The bundled file, copied under its own name to a temporary folder:
    /// Shortcuts names the shortcut after the file.
    private static func bundledFile() -> URL? {
        guard let source = Bundle.main.url(forResource: name, withExtension: "shortcut") else { return nil }
        let folder = URL.temporaryDirectory.appending(path: "Shortcut", directoryHint: .isDirectory)
        let target = folder.appending(path: "\(name).shortcut")
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        try? FileManager.default.removeItem(at: target)
        do {
            try FileManager.default.copyItem(at: source, to: target)
            return target
        } catch {
            return source
        }
    }

    private static func topViewController() -> UIViewController? {
        let scene = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first { $0.activationState == .foregroundActive }
        var top = scene?.keyWindow?.rootViewController
        while let presented = top?.presentedViewController { top = presented }
        return top
    }
}
