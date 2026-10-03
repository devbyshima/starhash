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
                // The sheet's question, so larger than a section label: the
                // size and weight of the recipient page's section labels.
                Text("Choose a number".uppercased())
                    .font(.sheet(15, .bold, relativeTo: .subheadline))
                    .tracking(1)
                    .foregroundStyle(Color.sheetBrandText)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 4)
                    .accessibilityAddTraits(.isHeader)
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
                    .foregroundStyle(Color.sheetBrandText)
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
        RecipientNumberRow(recipient: recipient) { onPick(recipient) }
    }

    /// "MTN", "Airtel" or "Merchant code": which code StarHash will dial.
    static func network(of recipient: Recipient) -> String {
        recipient.network?.name ?? "Merchant code"
    }
}

/// One of a contact's numbers on a sheet card: the carrier's logo in a soft
/// circle (a storefront for a merchant code), the number, its network and a
/// chevron. Tapping it pays that number.
struct RecipientNumberRow: View {
    let recipient: Recipient
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                leading
                Text(recipient.formattedDestination)
                    .font(.sheet(16, .medium))
                    .foregroundStyle(Color.starhashPrimaryText)
                    .monospacedDigit()
                Spacer(minLength: 8)
                Text(ChooseNumberSheet.network(of: recipient))
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
        .buttonStyle(.hapticPlain)
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private var leading: some View {
        if let network = recipient.network {
            Image(network.logoAsset)
                .resizable()
                .scaledToFit()
                .frame(width: 26, height: 22)
                .frame(width: 38, height: 38)
                .background(Circle().fill(Color.sheetChip))
                .accessibilityHidden(true)
        } else {
            SheetIconCircle(symbol: "storefront")
        }
    }
}
