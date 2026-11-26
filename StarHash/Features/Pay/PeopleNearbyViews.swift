import StarHashKit
import SwiftUI

/// People Nearby on Pay: the faces of StarHash users close by, under the
/// amount while no one is chosen. A tap asks their phone for its number
/// and chooses them as a scanned StarHash code does, so Pay dials them
/// once there is an amount.
struct PeopleNearbyRow: View {
    @Environment(PeopleNearbyService.self) private var nearby
    let onChoose: (PaymentRequest) -> Void

    @State private var unreachable: PeopleNearby.Person?

    var body: some View {
        let row = nearby.found.row
        // Centred while they fit; a row to scroll once they don't.
        ViewThatFits(in: .horizontal) {
            faces(row)
                .padding(.horizontal, StarHashMetrics.screenPadding)
            ScrollView(.horizontal, showsIndicators: false) {
                faces(row)
                    .padding(.horizontal, StarHashMetrics.screenPadding)
            }
            .scrollClipDisabled()
        }
        .animation(.smooth(duration: 0.3), value: row.map(\.id))
        .unreachableAlert($unreachable)
    }

    private func faces(_ row: [PeopleNearby.Person]) -> some View {
        HStack(alignment: .top, spacing: 12) {
            ForEach(row) { person in
                PeopleNearbyFace(person: person, isReaching: nearby.reaching == person.id) {
                    reach(person)
                }
                .transition(.scale(scale: 0.6).combined(with: .opacity))
            }
        }
    }

    private func reach(_ person: PeopleNearby.Person) {
        Task {
            if let recipient = await nearby.reach(person) {
                onChoose(PaymentRequest(recipient: recipient, photoID: person.photoID, isStarHashCode: true))
            } else {
                unreachable = person
            }
        }
    }
}

/// One face in Pay's row: their photo, or their initials, with their first
/// name under it. Dimmed, with a spinner, while a tap reaches them.
private struct PeopleNearbyFace: View {
    let person: PeopleNearby.Person
    let isReaching: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                PeopleNearbyTile(person: person, size: 48)
                    .opacity(isReaching ? 0.4 : 1)
                    .overlay {
                        if isReaching { ProgressView().tint(Color.payPrimaryText) }
                    }
                Text(verbatim: person.firstName)
                    .font(.starhash(.caption, weight: .semibold))
                    .foregroundStyle(Color.payPrimaryText)
                    .lineLimit(1)
                    .frame(maxWidth: 64)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.hapticPlain)
        .disabled(isReaching)
        .accessibilityLabel(Text("Pay \(person.name)"))
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
/// be paid at.
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
        let browses = isOn && hasOnboarded && introPast && scenePhase == .active
        // Read for the redraw: a photo added or removed changes what is
        // announced.
        let photo = ProfilePhoto.shared.image != nil ? AppEnvironment.serverSync.sharedPhotoID : nil
        let announcement = browses && visible
            ? PeopleNearby.Announcement(name: owner.name, photoID: photo, number: owner.defaultSIM)
            : nil
        return PeopleNearbyService.Setup(browses: browses, announcement: announcement, handoff: PeopleNearby.Handoff(number: owner.defaultSIM))
    }
}

/// Shown once when People Nearby comes, in two steps. First what it is,
/// with one button, Continue, after which iOS asks for the local network
/// (a screen before a system prompt has only Continue). Then whether people
/// nearby may see the owner, which is StarHash's own question.
struct PeopleNearbyIntroSheet: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage(PreferenceKey.peopleNearbyIntroSeen) private var introSeen = false
    @AppStorage(PreferenceKey.peopleNearbyAsked) private var asked = false
    @AppStorage(Preferences.peopleNearbyVisible) private var visible: Bool
    @State private var height: CGFloat = 400
    @State private var asksToBeSeen: Bool

    init() {
        var startsOnQuestion = UserDefaults.standard.bool(forKey: PreferenceKey.peopleNearbyIntroSeen)
        #if DEBUG
        if DebugLaunch.value(after: "-peopleNearbyIntro") == "2" { startsOnQuestion = true }
        #endif
        _asksToBeSeen = State(initialValue: startsOnQuestion)
    }

    private var points: [(symbol: String, text: String)] {
        if asksToBeSeen {
            [
                ("eye.fill", String(starhash: "Your name and photo show on their Pay while StarHash is open")),
                ("lock.fill", String(starhash: "Your number goes only to someone who taps you, to pay you")),
                ("gearshape.fill", String(starhash: "Change it any time in Settings, under Your SIMs")),
            ]
        } else {
            [
                ("person.2.fill", String(starhash: "StarHash users near you show up on Pay while StarHash is open")),
                ("qrcode", String(starhash: "Tap one to pay them, with no QR code")),
            ]
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            SheetHeader(asksToBeSeen ? String(starhash: "Let people near you see you?") : String(starhash: "People Nearby"))

            VStack(spacing: 24) {
                VStack(spacing: 0) {
                    ForEach(Array(points.enumerated()), id: \.offset) { index, point in
                        if index > 0 { SheetDivider().padding(.leading, 54) }
                        HStack(spacing: 16) {
                            SheetIconCircle(symbol: point.symbol)
                            Text(verbatim: point.text)
                                .font(.sheetBody)
                                .lineSpacing(2)
                                .foregroundStyle(Color.starhashPrimaryText)
                                .fixedSize(horizontal: false, vertical: true)
                            Spacer(minLength: 0)
                        }
                        .padding(.vertical, 14)
                        .accessibilityElement(children: .combine)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 4)
                .sheetCard()
                .id(asksToBeSeen)
                .transition(.opacity)

                if asksToBeSeen {
                    VStack(spacing: 6) {
                        Button("Let Them See Me") { answer(visible: true) }
                            .buttonStyle(.sheetPrimary)
                        SheetTextButton("Not Now") { answer(visible: false) }
                    }
                } else {
                    // Looking for people starts here, and iOS asks for the
                    // local network over the sheet.
                    Button("Continue") {
                        introSeen = true
                        withAnimation(.smooth(duration: 0.3)) { asksToBeSeen = true }
                    }
                    .buttonStyle(.sheetPrimary)
                }
            }
            .padding(.top, 16)
            .padding(.horizontal, 18)
            .padding(.bottom, 16)
        }
        .sheetHeight($height)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .ignoresSafeArea(.container, edges: .bottom)
        .sheetGlass(detents: [.height(height - 4)])
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
