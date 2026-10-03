import StarHashKit
import SwiftUI

/// What a long press on a contact in the recipient picker shows, in Beam's
/// sheet language, headed by the contact rather than a title: their photo
/// or initials and name, a card of their
/// numbers with their carriers' logos, what this year has sent them, and Pay.
///
/// Only Pay pays. Tapping a number of a contact with several only chooses it,
/// and Pay stays off until one is chosen, so nothing here dials by accident.
/// Each fact is said once: the number is in the card and nowhere else, the
/// amount is on the button and nowhere else.
struct ContactDetailSheet: View {
    let contact: PayContact
    /// The amount on Pay's keypad, which Pay pays.
    let amount: Int
    /// Called with the number to pay. The caller closes the sheet and pays.
    let onPay: (Recipient) -> Void

    @Environment(StarHashStore.self) private var store
    @AppStorage(PreferenceKey.enableContacts) private var enableContacts = true
    /// The number Pay pays: the only one, or the one chosen.
    @State private var chosen: Recipient?
    /// The content's height, so the sheet opens exactly as tall as what it
    /// shows, the Pay button included.
    @State private var contentHeight: CGFloat = 520

    private var hasChoice: Bool { contact.recipients.count > 1 }
    private var payee: Recipient? { hasChoice ? chosen : contact.recipients.first }

    var body: some View {
        // No title: the contact's own photo and name head the sheet.
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 20) {
                    hero
                    numbers
                    thisYear
                    payButton
                        .padding(.top, 6)
                }
                .padding(.horizontal, 18)
                // Clear of the grabber.
                .padding(.top, 28)
                .padding(.bottom, 16)
                .sheetHeight($contentHeight)
            }
            .scrollIndicators(.hidden)
            // Scrolls only when it cannot fit, at the largest text sizes.
            .scrollBounceBehavior(.basedOnSize)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .sheetGlass(detents: [.height(contentHeight + 8)])
        .sensoryFeedback(.selection, trigger: chosen)
    }

    // MARK: Pieces

    private var hero: some View {
        VStack(spacing: 10) {
            RecipientTile(
                tile: enableContacts && contact.hasPhoto
                    ? .photo(contactID: contact.id, fallback: .monogram(contact.initials))
                    : .monogram(contact.initials),
                size: 80,
                fill: .sheetTile
            )
            // Black in light mode, so its initials take a card's white.
            .starhashSurface(.card)
            Text(contact.name)
                .font(.sheet(21, .bold, relativeTo: .title2))
                .foregroundStyle(Color.starhashPrimaryText)
                .multilineTextAlignment(.center)
                .accessibilityAddTraits(.isHeader)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 4)
    }

    private var numbers: some View {
        VStack(spacing: 8) {
            SheetSectionLabel(sectionTitle)
            VStack(spacing: 0) {
                ForEach(Array(contact.recipients.enumerated()), id: \.element.destination) { index, recipient in
                    if index > 0 { SheetDivider().padding(.leading, 52) }
                    if hasChoice {
                        Button {
                            withAnimation(.snappy(duration: 0.2)) { chosen = recipient }
                        } label: {
                            numberRow(recipient, isChosen: chosen == recipient)
                        }
                        .buttonStyle(.plain)
                        .accessibilityAddTraits(chosen == recipient ? .isSelected : [])
                        .accessibilityHint("Chooses this number for Pay")
                    } else {
                        numberRow(recipient, isChosen: nil)
                    }
                }
            }
            .padding(.horizontal, 16)
            .sheetCard()
        }
    }

    /// The carrier's logo, the number, and its network when the section
    /// label does not already say what it is. A choice shows a ring that
    /// fills when chosen; a single number shows nothing at the end.
    private func numberRow(_ recipient: Recipient, isChosen: Bool?) -> some View {
        HStack(spacing: 14) {
            leading(recipient)
            Text(recipient.formattedDestination)
                .font(.sheet(16, .medium))
                .foregroundStyle(Color.starhashPrimaryText)
                .monospacedDigit()
            Spacer(minLength: 8)
            if let detail = detail(for: recipient) {
                Text(detail)
                    .font(.sheetBody)
                    .foregroundStyle(Color.sheetSecondaryText)
            }
            if let isChosen {
                Image(systemName: isChosen ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 20, weight: .medium))
                    .foregroundStyle(isChosen ? Color.starhashPrimaryText : Color.starhashTertiaryText)
                    .contentTransition(.symbolEffect(.replace))
                    .accessibilityHidden(true)
            }
        }
        .lineLimit(1)
        .padding(.vertical, 11)
        .contentShape(Rectangle())
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
                .background(Circle().fill(Color.sheetChip))
                .accessibilityHidden(true)
        } else {
            SheetIconCircle(symbol: "storefront")
        }
    }

    private var payButton: some View {
        Button(payee == nil ? "Choose a number" : "Pay \(Money.formatWithCurrency(amount))") {
            if let payee { onPay(payee) }
        }
        .buttonStyle(.sheetPrimary)
        .disabled(payee == nil)
        .animation(.smooth(duration: 0.2), value: payee == nil)
    }

    /// Everything this year has sent to any of the contact's numbers, as
    /// Beam's big-number stats.
    private var thisYear: some View {
        let totals = contact.recipients.reduce(into: (amount: 0, count: 0)) { sum, recipient in
            let ytd = store.yearToDate(for: recipient)
            sum.amount += ytd.amount
            sum.count += ytd.count
        }
        return VStack(spacing: 8) {
            SheetSectionLabel("This year")
            HStack(alignment: .top, spacing: 16) {
                stat(value: Money.format(totals.amount), label: "\(Money.currency) sent")
                stat(value: String(totals.count), label: totals.count == 1 ? "Payment" : "Payments")
            }
            .padding(16)
            .sheetCard()
        }
    }

    private func stat(value: String, label: String) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(value)
                .font(.sheet(30, .bold, relativeTo: .title))
                .foregroundStyle(Color.starhashPrimaryText)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            Text(label.uppercased())
                .font(.sheetCaption2)
                .tracking(0.6)
                .foregroundStyle(Color.sheetSecondaryText)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }

    // MARK: Wording

    private var allMerchant: Bool { contact.recipients.allSatisfy { $0.kind == .merchant } }
    private var allPhone: Bool { contact.recipients.allSatisfy { $0.kind == .phone } }

    /// What the card holds, said once: "Number", "Numbers", "Merchant code",
    /// "Merchant codes", or "Numbers" for a mix.
    private var sectionTitle: String {
        let plural = hasChoice ? "s" : ""
        if allMerchant { return "Merchant code" + plural }
        return "Number" + (allPhone ? plural : "s")
    }

    /// A phone number's network ("MTN", "Airtel"), which the label does not
    /// say; a merchant code needs a word only among phone numbers.
    private func detail(for recipient: Recipient) -> String? {
        if let network = recipient.network { return network.name }
        return allMerchant ? nil : "Merchant code"
    }
}
