import StarHashKit
import SwiftUI

/// Shown once to owners who set StarHash up before Show My Name came, since
/// it starts on: who now sees their name and photo, and where to turn it
/// off. Got It keeps it on; Turn Off turns it off there and then. New
/// owners are told on onboarding's number page instead.
struct ShowMyNameNoticeSheet: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage(Preferences.showMyName) private var showMyName: Bool
    private var profile: ProfilePhoto { .shared }

    var body: some View {
        // Got It and Turn Off are its two answers, so no close button.
        HeroSheet(
            caption: String(starhash: "Your SIMs"),
            title: String(starhash: "Payers See Your Name")
        ) {
            if let photo = profile.image {
                TileHero { RecipientTile(tile: .image(photo), size: 84) }
            } else {
                SymbolHero(symbol: "eye.fill")
            }
        } actions: {
            Button("Got It") { dismiss() }
                .buttonStyle(.sheetPrimary)
            SheetTextButton("Turn Off") {
                showMyName = false
                dismiss()
            }
        }
    }

    /// `-showMyNameNotice` (DEBUG) shows it at launch, for screenshots.
    static var forcedAtLaunch: Bool {
        #if DEBUG
        DebugLaunch.arguments.contains("-showMyNameNotice")
        #else
        false
        #endif
    }
}
