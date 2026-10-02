import StarHashKit
import SwiftUI

/// Who a transaction was with: their photo from Contacts, when the number
/// or code (or, for money received, the name) is saved there with one;
/// otherwise a person or shop symbol on a tile.
struct TransactionAvatar: View {
    let counterparty: Recipient
    var size: CGFloat = 42
    var isCircle = false

    @AppStorage(PreferenceKey.enableContacts) private var enableContacts = true
    private var contacts: PayContacts { .shared }

    var body: some View {
        Group {
            if enableContacts, let contactID = contacts.photoContactID(for: counterparty) {
                ContactPhotoTile(contactID: contactID, size: size, isCircle: isCircle) { symbolTile }
            } else {
                symbolTile
            }
        }
        .accessibilityHidden(true)
    }

    private var symbolTile: some View {
        SymbolTile(symbol: counterparty.kind == .phone ? "person.fill" : "storefront.fill", size: size)
            .clipShape(RoundedRectangle(cornerRadius: isCircle ? size / 2 : size * 0.3, style: .continuous))
    }
}
