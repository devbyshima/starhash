import StarHashKit
import SwiftUI

/// "Choose a number for …", for a contact with more than one number: a
/// bottom sheet sized to its rows, as Faranga does it, in StarHash's look.
/// Each row is the number with its network (so an Airtel number is easy
/// to tell from an MTN one); tapping it pays that number. Cancel closes.
struct ChooseNumberSheet: View {
    let contact: PayContact
    let onPick: (Recipient) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var height: CGFloat = 420

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 10) {
                Text("Choose a number for \(contact.name)")
                    .starhashFont(26, weight: .bold, relativeTo: .title)
                    .foregroundStyle(Color.starhashPrimaryText)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityAddTraits(.isHeader)
                Text("The money goes to the number you pick.")
                    .font(.subheadline)
                    .foregroundStyle(Color.starhashSecondaryText)
            }
            .padding(.horizontal, 8)
            .padding(.top, 24)

            StarHashCard {
                ForEach(Array(contact.recipients.enumerated()), id: \.element.destination) { index, recipient in
                    if index > 0 { StarHashRowSeparator(leading: 72) }
                    RecipientRow(
                        tile: .symbol(recipient.kind == .merchant ? "storefront" : "phone"),
                        title: recipient.formattedDestination,
                        subtitle: Self.network(of: recipient)
                    ) {
                        onPick(recipient)
                    }
                }
            }
            .padding(.top, 20)

            Button("Cancel") { dismiss() }
                .buttonStyle(.starhashSecondary)
                .padding(.top, 16)
        }
        .padding(.horizontal, StarHashMetrics.screenPadding)
        .padding(.bottom, StarHashMetrics.screenPadding)
        // The sheet is exactly as tall as its content: the title sits just
        // under the drag handle, and the last button as far from the
        // sheet's bottom edge as from its sides.
        .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { height = $0 }
        .ignoresSafeArea(.container, edges: .vertical)
        .presentationDetents([.height(height)])
        .presentationDragIndicator(.visible)
        .starhashSheetChrome()
    }

    /// "MTN MoMo", "Airtel Money" or "Merchant code": which code StarHash
    /// will dial for it.
    static func network(of recipient: Recipient) -> String {
        switch recipient.network {
        case .mtn: "MTN MoMo"
        case .airtel: "Airtel Money"
        case nil: "Merchant code"
        }
    }
}
