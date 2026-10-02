import StarHashKit
import SwiftUI

/// For a contact with more than one number: the contact's name as the
/// title and a card of their numbers, each with its carrier's logo and
/// network, in Beam's sheet language and sized to its content. Tapping a
/// number pays it; swiping the sheet away cancels.
struct ChooseNumberSheet: View {
    let contact: PayContact
    let onPick: (Recipient) -> Void

    @State private var height: CGFloat = 360

    var body: some View {
        VStack(spacing: 0) {
            SheetHeader(contact.name)

            VStack(spacing: 8) {
                SheetSectionLabel("Choose a number")
                VStack(spacing: 0) {
                    ForEach(Array(contact.recipients.enumerated()), id: \.element.destination) { index, recipient in
                        if index > 0 { SheetDivider().padding(.leading, 52) }
                        row(recipient)
                    }
                }
                .padding(.horizontal, 16)
                .sheetCard()
                Text("The money goes to the number you pick.")
                    .font(.sheetCaption)
                    .foregroundStyle(Color.sheetSecondaryText)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 4)
                    .padding(.top, 2)
            }
            .padding(.horizontal, 18)
            .padding(.top, 4)
            .padding(.bottom, 16)
        }
        .sheetHeight($height)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .sheetGlass(detents: [.height(height + 8)])
    }

    private func row(_ recipient: Recipient) -> some View {
        Button {
            onPick(recipient)
        } label: {
            HStack(spacing: 14) {
                leading(recipient)
                Text(recipient.formattedDestination)
                    .font(.sheet(16, .medium))
                    .foregroundStyle(Color.starhashPrimaryText)
                    .monospacedDigit()
                Spacer(minLength: 8)
                Text(Self.network(of: recipient))
                    .font(.sheetBody)
                    .foregroundStyle(Color.sheetSecondaryText)
                Image(systemName: "chevron.right")
                    .font(.sheet(12, .semibold, relativeTo: .footnote))
                    .foregroundStyle(Color.sheetSecondaryText)
            }
            .lineLimit(1)
            .padding(.vertical, 11)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
    }

    /// The carrier's logo in a soft circle; a storefront for a code.
    @ViewBuilder
    private func leading(_ recipient: Recipient) -> some View {
        if let network = recipient.network {
            Image(network.logoAsset)
                .resizable()
                .scaledToFit()
                .frame(width: 26, height: 22)
                .frame(width: 38, height: 38)
                .background(Circle().fill(Color.starhashPrimaryText.opacity(0.08)))
                .accessibilityHidden(true)
        } else {
            SheetIconCircle(symbol: "storefront")
        }
    }

    /// "MTN", "Airtel" or "Merchant code": which code StarHash will dial.
    static func network(of recipient: Recipient) -> String {
        recipient.network?.name ?? "Merchant code"
    }
}
