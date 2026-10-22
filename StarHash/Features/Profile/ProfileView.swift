import StarHashKit
import SwiftUI

/// Settings' Profile, everything down the middle: the owner's photo (tap
/// it to choose one), their name large under it and typed in place, their
/// number, and once it is in, their code as the voxel tree that turns into
/// the QR code others scan to pay them, with Share under it. Kept on the
/// iPhone, in Settings' preferences and the photo's own file.
struct ProfileView: View {
    @AppStorage(PreferenceKey.profileName) private var name = ""
    @AppStorage(PreferenceKey.profileNumber) private var number = ""
    @FocusState private var editsName: Bool
    /// The scroll view's visible height, so the empty state can sit in the
    /// middle of the room under the fields.
    @State private var viewport: CGFloat = 0
    /// The photo, name and number's height, the part above the code.
    @State private var headerHeight: CGFloat = 0

    private var recipient: Recipient? { OwnerProfile(name: name, number: number).recipient }

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                VStack(spacing: 0) {
                    ProfilePhotoPicker(size: 120)
                        .padding(.top, 8)

                    nameField
                        .padding(.top, 18)

                    ProfileFields(name: $name, number: $number, showsName: false, centred: true)
                        .frame(maxWidth: 360)
                        .padding(.top, 20)
                }
                .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { headerHeight = $0 }

                if let recipient {
                    VStack(spacing: 18) {
                        QRTreeView(text: PaymentQR.link(for: recipient, photoID: StarHashCloud.sharedPhotoID).absoluteString)
                            .frame(maxWidth: 340)
                        MyCodeShareButton(recipient: recipient)
                            .buttonStyle(.starhashPrimary)
                            .frame(maxWidth: 360)
                    }
                    .padding(.top, 22)
                    .transition(.scale(scale: 0.96).combined(with: .opacity))
                } else {
                    // In the middle of the room left under the fields.
                    EmptyStateView(doodle: .matches, title: "No Code Yet")
                        .padding(.vertical, 24)
                        .frame(maxWidth: .infinity, minHeight: max(0, viewport - headerHeight - 38))
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal, SettingsLayout.screenMargin + 6)
            .padding(.bottom, 30)
            .animation(.smooth(duration: 0.3), value: recipient)
        }
        .scrollDismissesKeyboard(.interactively)
        // The height inside the bars, which the content can fill.
        .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { viewport = $0 }
        .starhashSoftEdge()
        .starhashReadableScrollContent()
        .background(Color.starhashBackground.ignoresSafeArea())
        // The page is its own title: the bar keeps only the back button.
        .navigationTitle(String(localized: "Profile"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) { Color.clear.frame(width: 1, height: 1) }
        }
    }

    private var nameField: some View {
        TextField(
            String(localized: "Your name"),
            text: $name,
            prompt: Text("Your name").foregroundStyle(Color.starhashTertiaryText),
            axis: .vertical
        )
        .starhashFont(34, weight: .bold, relativeTo: .largeTitle)
        .foregroundStyle(Color.starhashPrimaryText)
        .multilineTextAlignment(.center)
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
}
