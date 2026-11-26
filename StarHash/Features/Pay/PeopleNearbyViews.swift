import StarHashKit
import SwiftUI

/// People Nearby on Pay, after the owner's reference: Pay's pill (`PayPill`),
/// "ARIANE IS NEARBY" by their photo, turning through everyone close by. A
/// tap opens People Nearby (`PeopleNearbyRadar`), everyone close by on its
/// rings, where a tap on one chooses them.
struct PeopleNearbyPill: View {
    @Environment(PeopleNearbyService.self) private var nearby
    let onOpen: () -> Void

    var body: some View {
        PayPill(items: nearby.found.row, onTap: { _ in onOpen() }) { person in
            HStack(spacing: 8) {
                PeopleNearbyTile(person: person, size: 24)
                PayPillText(text: Text("\(person.firstName) is nearby"))
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Text("\(person.name) is nearby"))
            .accessibilityHint(Text("Shows everyone nearby"))
        }
        #if DEBUG
        // -peopleNearbyRadar: People Nearby opened from the pill, for
        // screenshots (with -peopleNearbyPick, someone on it tapped).
        .task {
            guard DebugLaunch.arguments.contains("-peopleNearbyRadar") || DebugLaunch.arguments.contains("-peopleNearbyPick") else { return }
            try? await Task.sleep(for: .seconds(1.5))
            onOpen()
        }
        #endif
    }
}

/// A person nearby's tile: the photo their phone announced, once it has
/// come from StarHash's server, and their initials until then (or with no
/// photo, or no internet).
struct PeopleNearbyTile: View {
    let person: PeopleNearby.Person
    var size: CGFloat = 44

    @State private var photo: UIImage?

    var body: some View {
        RecipientTile(tile: photo.map { .image($0) } ?? .monogram(PayContact.initials(for: person.name)), size: size)
            .task(id: person.photoID) {
                photo = nil
                guard let id = person.photoID else { return }
                #if DEBUG
                if let sample = PeopleNearbyDebug.photo(for: id) {
                    photo = sample
                    return
                }
                #endif
                photo = await StarHashCloud.photo(id)
            }
    }
}

extension PeopleNearby.Person {
    /// The first word of their name, for a face's label.
    var firstName: String {
        name.split(separator: " ").first.map(String.init) ?? name
    }
}

extension View {
    /// "Couldn't reach Ariane": a tap on someone nearby that got no number.
    func unreachableAlert(_ person: Binding<PeopleNearby.Person?>) -> some View {
        alert(
            person.wrappedValue.map { String(starhash: "Couldn't reach \($0.firstName)") } ?? "",
            isPresented: Binding(get: { person.wrappedValue != nil }, set: { if !$0 { person.wrappedValue = nil } })
        ) {
            Button("OK") { person.wrappedValue = nil }
        } message: {
            Text("Ask them to keep StarHash open, then try again.")
        }
    }
}

/// Keeps `PeopleNearbyService` in step with the app: looking for people
/// while StarHash is in front, the feature on and its intro past, and
/// being seen too when the owner said yes and has a name and a number to
/// be paid at, or while they hold out a request to be tapped.
struct PeopleNearbySync: ViewModifier {
    @Environment(\.scenePhase) private var scenePhase
    @Environment(Owner.self) private var owner
    @FeatureFlagged(.peopleNearby) private var isOn
    @AppStorage(PreferenceKey.hasOnboarded) private var hasOnboarded = false
    @AppStorage(PreferenceKey.peopleNearbyIntroSeen) private var introSeen = false
    @AppStorage(Preferences.peopleNearbyVisible) private var visible: Bool

    func body(content: Content) -> some View {
        content.task(id: setup) {
            let setup = setup
            // Stopping is at once, as StarHash leaves the front. A start, or
            // a name typed letter by letter on Profile, waits a moment, so
            // the announcement is made once.
            if setup.browses {
                try? await Task.sleep(for: .milliseconds(600))
                guard !Task.isCancelled else { return }
            }
            AppEnvironment.peopleNearby.apply(setup)
        }
    }

    private var setup: PeopleNearbyService.Setup {
        var introPast = introSeen
        #if DEBUG
        if PeopleNearbyDebug.samples != nil { introPast = true }
        #endif
        // Inactive is still in front: a system alert (Contacts, the local
        // network) or Control Center over StarHash. Stopping then would
        // make every face drop off and come back. Background is gone.
        let browses = isOn && hasOnboarded && introPast && scenePhase != .background
        // Read for the redraw: a photo added or removed changes what is
        // announced.
        let photo = ProfilePhoto.shared.image != nil ? AppEnvironment.serverSync.sharedPhotoID : nil
        let announcement = browses && visible
            ? PeopleNearby.Announcement(name: owner.name, photoID: photo, number: owner.defaultSIM)
            : nil
        // Holding out a request to be tapped, while StarHash is in front.
        let offersTap = AppEnvironment.tapToRequest.offersTap && scenePhase != .background
        return PeopleNearbyService.Setup(
            browses: browses, announcement: announcement, handoff: PeopleNearby.Handoff(number: owner.defaultSIM), offersTap: offersTap
        )
    }
}

/// Shown once when People Nearby comes, in two steps, as a hero sheet over
/// two phones nodding together. First what it is, with one button,
/// Continue, after which iOS asks for the local network (a screen before a
/// system prompt has only Continue, and no way out). Then whether people
/// nearby may see the owner, which is StarHash's own question: Let Them
/// See Me, or the close button for not now.
struct PeopleNearbyIntroSheet: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage(PreferenceKey.peopleNearbyIntroSeen) private var introSeen = false
    @AppStorage(PreferenceKey.peopleNearbyAsked) private var asked = false
    @AppStorage(Preferences.peopleNearbyVisible) private var visible: Bool
    @State private var asksToBeSeen: Bool

    init() {
        var startsOnQuestion = UserDefaults.standard.bool(forKey: PreferenceKey.peopleNearbyIntroSeen)
        #if DEBUG
        if DebugLaunch.value(after: "-peopleNearbyIntro") == "2" { startsOnQuestion = true }
        #endif
        _asksToBeSeen = State(initialValue: startsOnQuestion)
    }

    var body: some View {
        HeroSheet(
            caption: String(starhash: "People Nearby"),
            title: asksToBeSeen ? String(starhash: "Let People Nearby See You?") : String(starhash: "Pay Who's Close By"),
            onClose: asksToBeSeen ? { answer(visible: false) } : nil,
            closeLabel: "Not Now"
        ) {
            PhonesNodHero()
        } actions: {
            if asksToBeSeen {
                Button("Let Them See Me") { answer(visible: true) }
                    .buttonStyle(.sheetPrimary)
            } else {
                // Looking for people starts here, and iOS asks for the
                // local network over the sheet.
                Button("Continue") {
                    introSeen = true
                    withAnimation(.smooth(duration: 0.35)) { asksToBeSeen = true }
                }
                .buttonStyle(.sheetPrimary)
            }
        }
        // Only an answer closes it: the question comes after iOS's prompt.
        .interactiveDismissDisabled()
    }

    private func answer(visible: Bool) {
        self.visible = visible
        asked = true
        dismiss()
    }

    /// `-peopleNearbyIntro [2]` (DEBUG) shows it at launch, on its question
    /// with 2, for screenshots.
    static var forcedAtLaunch: Bool {
        #if DEBUG
        DebugLaunch.arguments.contains("-peopleNearbyIntro")
        #else
        false
        #endif
    }

    /// `-peopleNearby` (DEBUG) shows the sample people straight away, with
    /// no intro over them.
    static var skippedAtLaunch: Bool {
        #if DEBUG
        PeopleNearbyDebug.samples != nil && !forcedAtLaunch
        #else
        false
        #endif
    }
}
