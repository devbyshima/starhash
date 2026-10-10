import CoreImage.CIFilterBuiltins
import StarHashKit
import SwiftUI
import UIKit

/// The owner's code as a plain image to share: black on white, its
/// modules scaled up without smoothing, as any scanner reads best.
enum QRCodeImage {
    /// The code as an image, a few modules' quiet zone round it, or nil if
    /// it would not encode.
    static func image(for text: String, scale: CGFloat = 12) -> UIImage? {
        let filter = CIFilter.qrCodeGenerator()
        filter.message = Data(text.utf8)
        filter.correctionLevel = "M"
        guard let output = filter.outputImage?.transformed(by: CGAffineTransform(scaleX: scale, y: scale)),
              let cgImage = CIContext().createCGImage(output, from: output.extent) else { return nil }
        return UIImage(cgImage: cgImage)
    }
}

/// What a code is shared as: the image, with the link in its message.
struct MyCodeShareButton: View {
    let recipient: Recipient

    var body: some View {
        if let image = QRCodeImage.image(for: PaymentQR.link(for: recipient).absoluteString) {
            ShareLink(
                item: Image(uiImage: image),
                message: Text("Pay me with StarHash: \(recipient.formattedDestination)"),
                preview: SharePreview("My StarHash code", image: Image(uiImage: image))
            ) {
                Label("Share Code", systemImage: "square.and.arrow.up")
            }
        }
    }
}

/// The scanner's My Code: the owner's code as the voxel tree on the sheet
/// itself, turning into the QR code at a tap, with Share under it; or,
/// before they have given their number, a field for it.
struct MyCodeSheet: View {
    @AppStorage(PreferenceKey.profileName) private var name = ""
    @AppStorage(PreferenceKey.profileNumber) private var number = ""
    @State private var height: CGFloat = 0

    private var recipient: Recipient? { OwnerProfile(name: name, number: number).recipient }

    var body: some View {
        VStack(spacing: 18) {
            SheetHeader("My Code")
            if let recipient {
                QRTreeView(text: PaymentQR.link(for: recipient).absoluteString)
                    .frame(maxWidth: 320)
                MyCodeShareButton(recipient: recipient)
                    .buttonStyle(.sheetPrimary)
            } else {
                ProfileFields(name: $name, number: $number, onSheet: true)
            }
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 20)
        .sheetHeight($height)
        .sheetGlass(detents: [.height(max(height, 200) + 8)])
    }
}

/// The name and number fields, as onboarding, Profile and My Code show
/// them: the number checked as it is typed.
struct ProfileFields: View {
    @Binding var name: String
    @Binding var number: String
    /// In a sheet's card rather than on the page.
    var onSheet = false
    /// The name's field too; Profile types the name large in its header.
    var showsName = true
    /// The number in the middle of its field, with no symbol, as Profile
    /// sets everything down the middle.
    var centred = false

    @FocusState private var focus: Field?
    @State private var draftNumber = ""
    @AppStorage(PreferenceKey.wallet) private var wallet: Recipient.Network = .mtn

    private enum Field { case name, number }

    /// What is wrong with the number typed, once it is long enough to tell.
    private var problem: String? {
        let digits = draftNumber.filter(\.isNumber)
        guard digits.count >= 10 else { return nil }
        guard let recipient = Recipient.ownNumber(draftNumber) else {
            return String(localized: "Enter a Rwandan mobile number: 078, 079, 072 or 073.")
        }
        if let network = recipient.network, network != wallet {
            return String(localized: "That is an \(network.name) number; you pay with \(wallet.walletName).")
        }
        return nil
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if showsName {
            field(
                "Your name",
                text: $name,
                prompt: "Name (optional)",
                symbol: "person.fill"
            )
            .focused($focus, equals: .name)
            .textContentType(.name)
            .textInputAutocapitalization(.words)
            .submitLabel(.next)
            .onSubmit { focus = .number }
            }

            field(
                "Your number",
                text: $draftNumber,
                prompt: "07X XXX XXXX",
                symbol: "phone.fill"
            )
            .focused($focus, equals: .number)
            .keyboardType(.phonePad)
            .textContentType(.telephoneNumber)
            .onChange(of: draftNumber) { _, typed in
                // Saved only once it is a number the code can carry.
                if let recipient = Recipient.ownNumber(typed) {
                    number = recipient.destination
                } else if typed.filter(\.isNumber).isEmpty {
                    number = ""
                }
            }

            if let problem {
                Text(problem)
                    .font(.starhash(.footnote))
                    .foregroundStyle(Color.starhashDestructive)
                    .padding(.horizontal, 6)
                    .transition(.opacity)
            }
        }
        .animation(.smooth(duration: 0.2), value: problem)
        .onAppear {
            if draftNumber.isEmpty, let saved = Recipient.ownNumber(number) { draftNumber = saved.formattedDestination }
        }
    }

    private func field(_ label: String, text: Binding<String>, prompt: String, symbol: String) -> some View {
        HStack(spacing: 12) {
            if !centred {
                Image(systemName: symbol)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Color.starhashSecondaryText)
                    .frame(width: 22)
                    .accessibilityHidden(true)
            }
            TextField(label, text: text, prompt: Text(catalog: prompt).foregroundStyle(Color.starhashTertiaryText))
                .starhashFont(17, weight: .medium, relativeTo: .body)
                .foregroundStyle(Color.starhashPrimaryText)
                .multilineTextAlignment(centred ? .center : .leading)
                .accessibilityLabel(label)
        }
        .padding(.horizontal, 18)
        .frame(minHeight: StarHashMetrics.primaryButtonHeight)
        .modifier(ProfileFieldBackground(onSheet: onSheet))
    }
}

/// A field's box: a sheet's card in a sheet, the cards' solid foreground
/// on the page.
private struct ProfileFieldBackground: ViewModifier {
    let onSheet: Bool

    func body(content: Content) -> some View {
        if onSheet {
            content.sheetCard(radius: 29)
        } else {
            content.starhashContainer(.starhashCard, in: Capsule())
        }
    }
}
