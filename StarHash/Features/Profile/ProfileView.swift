import StarHashKit
import SwiftUI

/// Settings' Profile, after the reference: the owner's face large at the
/// top (tap it to pick another, "Pick your vibe"), their name large under
/// it and typed in place, and faint rings round the StarHash mark behind,
/// off the top right corner. Under the name, their number and, once it is
/// in, their StarHash QR code for others to scan and pay them, with a way
/// to share it. Kept on the iPhone, in Settings' preferences.
struct ProfileView: View {
    @AppStorage(PreferenceKey.profileName) private var name = ""
    @AppStorage(PreferenceKey.profileNumber) private var number = ""
    @AppStorage(PreferenceKey.profileAvatar) private var avatar = AvatarFace.standard.rawValue
    @State private var picksAvatar = false
    @FocusState private var editsName: Bool

    private var recipient: Recipient? { OwnerProfile(name: name, number: number).recipient }
    private var face: Binding<AvatarFace> {
        Binding(
            get: { AvatarFace(rawValue: avatar) ?? .standard },
            set: { avatar = $0.rawValue }
        )
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                header
                    .padding(.horizontal, 6)

                VStack(alignment: .leading, spacing: 10) {
                    ProfileFields(name: $name, number: $number, showsName: false)
                    SettingsFootnote("Your number goes in your QR code, so StarHash knows where others' payments go. Nothing leaves your iPhone.")
                        .padding(.horizontal, 6)
                }
                .padding(.top, 26)

                if let recipient {
                    VStack(spacing: 14) {
                        MyCodeCard(recipient: recipient)
                        MyCodeShareButton(recipient: recipient)
                            .buttonStyle(.starhashPrimary)
                    }
                    .padding(.top, 22)
                    .transition(.scale(scale: 0.96).combined(with: .opacity))
                } else {
                    EmptyStateView(
                        doodle: .matches,
                        title: "No Code Yet",
                        message: "Add your number to get a QR code others scan to pay you."
                    )
                    .frame(maxWidth: .infinity)
                    .padding(.top, 30)
                }
            }
            .padding(.horizontal, SettingsLayout.screenMargin + 6)
            .padding(.bottom, 30)
            .animation(.smooth(duration: 0.3), value: recipient)
        }
        .scrollDismissesKeyboard(.interactively)
        .starhashSoftEdge()
        .starhashReadableScrollContent()
        .background(alignment: .topTrailing) {
            ProfileBackdrop()
                .ignoresSafeArea()
        }
        .background(Color.starhashBackground.ignoresSafeArea())
        // The page is its own title, as the reference's: the bar keeps
        // only the back button.
        .navigationTitle(String(localized: "Profile"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) { Color.clear.frame(width: 1, height: 1) }
        }
        .sheet(isPresented: $picksAvatar) { AvatarPickerSheet(selection: face) }
        #if DEBUG
        // -pickAvatar: "Pick your vibe" open, for screenshots.
        .task {
            guard DebugLaunch.arguments.contains("-pickAvatar") else { return }
            try? await Task.sleep(for: .milliseconds(600))
            picksAvatar = true
        }
        #endif
    }

    /// The face and the name, the top of the page.
    private var header: some View {
        VStack(alignment: .leading, spacing: 18) {
            Button { picksAvatar = true } label: {
                AvatarView(face: face.wrappedValue, size: 128)
                    .overlay(alignment: .bottomTrailing) {
                        Image(systemName: "pencil")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(Color.brandBlue)
                            .frame(width: 34, height: 34)
                            .background(Color.avatarFace, in: Circle())
                            .offset(x: -2, y: -2)
                            .accessibilityHidden(true)
                    }
            }
            .buttonStyle(PressScaleButtonStyle())
            .accessibilityLabel(String(localized: "Your face: \(face.wrappedValue.title)"))
            .accessibilityHint(String(localized: "Picks another"))

            TextField(
                String(localized: "Your name"),
                text: $name,
                prompt: Text("Your name").foregroundStyle(Color.starhashTertiaryText),
                axis: .vertical
            )
            .starhashFont(44, weight: .bold, relativeTo: .largeTitle)
            .foregroundStyle(Color.starhashPrimaryText)
            .lineLimit(1...2)
            .focused($editsName)
            .textContentType(.name)
            .textInputAutocapitalization(.words)
            .submitLabel(.done)
            .onChange(of: name) { _, typed in
                // A return ends the name rather than starting a line.
                if typed.contains("\n") {
                    name = typed.replacingOccurrences(of: "\n", with: "")
                    editsName = false
                }
            }
            .accessibilityLabel(String(localized: "Your name"))
        }
        .padding(.top, 8)
    }
}
