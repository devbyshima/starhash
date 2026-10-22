import CoreImage.CIFilterBuiltins
import StarHashKit
import SwiftUI
import UIKit

/// The owner's code as an image to share, StarHash's own: the modules as
/// rounded near-black dots on white, the three corner squares rounded with
/// their eyes in the deep green, and the StarHash mark in the accent on a
/// white tile in the middle. Error correction H leaves a third of the code
/// to spare, far more than the mark covers, so any scanner still reads it.
enum QRCodeImage {
    /// The code as a square image `side` pixels wide, a quiet zone of four
    /// modules round it, or nil if it would not encode.
    static func image(for text: String, side: CGFloat = 1024) -> UIImage? {
        guard let modules = QRModules(text: text, correction: "H") else { return nil }
        let count = modules.count
        let quiet = 4
        let module = side / CGFloat(count + quiet * 2)
        let origin = CGFloat(quiet) * module
        let ink = UIColor(red: 23 / 255, green: 23 / 255, blue: 23 / 255, alpha: 1)
        let eye = UIColor(red: 53 / 255, green: 116 / 255, blue: 68 / 255, alpha: 1)
        let accent = UIColor(red: 100 / 255, green: 210 / 255, blue: 123 / 255, alpha: 1)

        // The mark's tile: about a quarter of the code across, on whole
        // modules, an odd number so it sits dead centre.
        var tileModules = Int((Double(count) * 0.26).rounded())
        if tileModules % 2 == 0 { tileModules += 1 }
        let tileStart = (count - tileModules) / 2
        let tileRange = tileStart..<(tileStart + tileModules)

        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        return UIGraphicsImageRenderer(size: CGSize(width: side, height: side), format: format).image { context in
            let cg = context.cgContext
            UIColor.white.setFill()
            cg.fill(CGRect(x: 0, y: 0, width: side, height: side))

            // The modules, leaving out the corner squares (drawn whole
            // below) and the mark's tile.
            ink.setFill()
            for row in 0..<count {
                for column in 0..<count where modules.isDark(row: row, column: column) {
                    if modules.isFinder(row: row, column: column) { continue }
                    if tileRange.contains(row), tileRange.contains(column) { continue }
                    let rect = CGRect(
                        x: origin + CGFloat(column) * module,
                        y: origin + CGFloat(row) * module,
                        width: module,
                        height: module
                    ).insetBy(dx: module * 0.06, dy: module * 0.06)
                    UIBezierPath(roundedRect: rect, cornerRadius: module * 0.32).fill()
                }
            }

            // The three corner squares: a rounded ring and a rounded eye.
            for (row, column) in [(0, 0), (0, count - 7), (count - 7, 0)] {
                let outer = CGRect(x: origin + CGFloat(column) * module, y: origin + CGFloat(row) * module, width: module * 7, height: module * 7)
                let ring = UIBezierPath(roundedRect: outer, cornerRadius: module * 2)
                ring.append(UIBezierPath(roundedRect: outer.insetBy(dx: module, dy: module), cornerRadius: module * 1.3).reversing())
                ink.setFill()
                ring.fill()
                eye.setFill()
                UIBezierPath(roundedRect: outer.insetBy(dx: module * 2, dy: module * 2), cornerRadius: module).fill()
            }

            // The mark on its tile.
            let tile = CGRect(
                x: origin + CGFloat(tileStart) * module,
                y: origin + CGFloat(tileStart) * module,
                width: CGFloat(tileModules) * module,
                height: CGFloat(tileModules) * module
            ).insetBy(dx: module * 0.3, dy: module * 0.3)
            UIColor.white.setFill()
            UIBezierPath(roundedRect: tile, cornerRadius: tile.width * 0.24).fill()
            let mark = StarHashMarkShape().path(in: tile.insetBy(dx: tile.width * 0.13, dy: tile.width * 0.13)).cgPath
            cg.addPath(mark)
            cg.setFillColor(accent.cgColor)
            cg.fillPath()
        }
    }
}

/// What a code is shared as: the image, with the link in its message.
struct MyCodeShareButton: View {
    let recipient: Recipient

    var body: some View {
        if let image = QRCodeImage.image(for: PaymentQR.link(for: recipient, photoID: StarHashCloud.sharedPhotoID).absoluteString) {
            ShareLink(
                item: Image(uiImage: image),
                message: Text("Pay me with StarHash: \(recipient.formattedDestination)"),
                preview: SharePreview("My StarHash code", image: Image(uiImage: image))
            ) {
                Text("Share Code")
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
                QRTreeView(text: PaymentQR.link(for: recipient, photoID: StarHashCloud.sharedPhotoID).absoluteString)
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
    /// The other SIM's number, on Profile when the owner has two.
    var otherNumber: Binding<String>?

    @FocusState private var focus: Field?
    @State private var draftNumber = ""
    @State private var draftOther = ""
    @AppStorage(PreferenceKey.wallet) private var wallet: Recipient.Network = .mtn

    private enum Field { case name, number, other }

    /// What is wrong with the other SIM's number: it need only be a
    /// Rwandan mobile number, on either network.
    private var otherProblem: String? {
        guard draftOther.filter(\.isNumber).count >= 10, Recipient.ownNumber(draftOther) == nil else { return nil }
        return String(starhash: "Enter a Rwandan mobile number: 078, 079, 072 or 073.")
    }

    /// What is wrong with the number typed, once it is long enough to tell.
    private var problem: String? {
        let digits = draftNumber.filter(\.isNumber)
        guard digits.count >= 10 else { return nil }
        guard let recipient = Recipient.ownNumber(draftNumber) else {
            return String(starhash: "Enter a Rwandan mobile number: 078, 079, 072 or 073.")
        }
        if let network = recipient.network, network != wallet {
            return String(starhash: "That is an \(network.name) number; you pay with \(wallet.walletName).")
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
            .modifier(ProfileFieldBackground(onSheet: onSheet))
            }

            // With two SIMs, both numbers in one box, a line between them.
            if let otherNumber {
                VStack(spacing: 0) {
                    numberField
                    SheetDivider()
                        .padding(.horizontal, 18)
                    otherField(otherNumber)
                }
                .modifier(ProfileFieldBackground(onSheet: onSheet, grouped: true))
            } else {
                numberField
                    .modifier(ProfileFieldBackground(onSheet: onSheet))
            }

            if let problem {
                problemText(problem)
            }
            if let otherProblem {
                problemText(otherProblem)
            }
        }
        .animation(.smooth(duration: 0.2), value: problem)
        .animation(.smooth(duration: 0.2), value: otherProblem)
        .onAppear {
            if draftNumber.isEmpty, let saved = Recipient.ownNumber(number) { draftNumber = saved.formattedDestination }
            if draftOther.isEmpty, let saved = otherNumber.flatMap({ Recipient.ownNumber($0.wrappedValue) }) {
                draftOther = saved.formattedDestination
            }
        }
    }

    private var numberField: some View {
        field(
            "Your number",
            text: $draftNumber,
            prompt: "07X XXX XXXX",
            symbol: "phone.fill"
        )
        .focused($focus, equals: .number)
        .keyboardType(.phonePad)
        .textContentType(.telephoneNumber)
        .onChange(of: draftNumber) { old, typed in
            // Saved only once it is a number the code can carry.
            if let recipient = Recipient.ownNumber(typed) {
                number = recipient.destination
                // The whole number is in and it is right: the number
                // pad, which has no return key, goes by itself.
                if Recipient.ownNumber(old) == nil, problem == nil { dismissKeyboard() }
            } else if typed.filter(\.isNumber).isEmpty {
                number = ""
            }
        }
    }

    private func otherField(_ otherNumber: Binding<String>) -> some View {
        field(
            "Other SIM",
            text: $draftOther,
            prompt: "Other SIM",
            symbol: "simcard.fill"
        )
        .focused($focus, equals: .other)
        .keyboardType(.phonePad)
        .textContentType(.telephoneNumber)
        .onChange(of: draftOther) { old, typed in
            // Kept as Settings' Other SIM row keeps it, so the two show
            // the same number.
            if let recipient = Recipient.ownNumber(typed) {
                otherNumber.wrappedValue = recipient.formattedDestination
                if Recipient.ownNumber(old) == nil { dismissKeyboard() }
            } else if typed.filter(\.isNumber).isEmpty {
                otherNumber.wrappedValue = ""
            }
        }
    }

    private func problemText(_ problem: String) -> some View {
        Text(problem)
            .font(.starhash(.footnote))
            .foregroundStyle(Color.starhashDestructive)
            .padding(.horizontal, 6)
            .transition(.opacity)
    }

    /// Whichever field has the keyboard lets it go.
    private func dismissKeyboard() {
        focus = nil
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }

    private func field(_ label: String, text: Binding<String>, prompt: String, symbol: String) -> some View {
        HStack(spacing: 12) {
            if !centred {
                Image(symbol: symbol)
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
    }
}

/// A field's box: a sheet's card in a sheet, the cards' solid foreground
/// on the page; a capsule round one field, a card's rounded corners round
/// two.
private struct ProfileFieldBackground: ViewModifier {
    let onSheet: Bool
    var grouped = false

    func body(content: Content) -> some View {
        if onSheet {
            content.sheetCard(radius: grouped ? 22 : 29)
        } else if grouped {
            content.starhashContainer(.starhashCard, in: RoundedRectangle(cornerRadius: 26, style: .continuous))
        } else {
            content.starhashContainer(.starhashCard, in: Capsule())
        }
    }
}
