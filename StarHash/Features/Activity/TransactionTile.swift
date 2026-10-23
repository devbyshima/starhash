import StarHashKit
import SwiftUI

/// The square beside a transaction, drawn as the recipient list draws its
/// own (`RecipientTile`), so one person looks the same wherever they show:
/// their photo from Contacts, else their initials, a shop for a merchant,
/// a phone for a bare number or the StarHash mark for a name with no
/// letters, on a tint of the text colour. A purchase shows what was bought
/// instead: the carrier's logo for airtime and bundles, the category's
/// symbol for anything else.
struct TransactionTile: View {
    let transaction: StarHashKit.Transaction
    var size: CGFloat = 44

    @AppStorage(PreferenceKey.enableContacts) private var enableContacts = true

    var body: some View {
        Group {
            if transaction.isPurchase, let category = transaction.knownCategory {
                if category.isFromCarrier, let wallet = transaction.wallet {
                    // Airtime and bundles come from the carrier itself.
                    WalletLogo(wallet: wallet, height: size * 0.32)
                        .frame(width: size, height: size)
                        .background(Color.starhashPrimaryText.opacity(0.1), in: RoundedRectangle(cornerRadius: size * 0.25, style: .continuous))
                } else {
                    RecipientTile(tile: .symbol(category.symbol), size: size)
                }
            } else if transaction.isOwnTransfer, let category = transaction.knownCategory {
                // Moved between the owner's own accounts: the move itself.
                RecipientTile(tile: .symbol(category.symbol), size: size)
            } else {
                let counterparty = transaction.counterparty
                let photo = enableContacts ? PayContacts.shared.photoContactID(for: counterparty) : nil
                RecipientTile(tile: .for(counterparty, photoContactID: photo), size: size)
            }
        }
        .accessibilityHidden(true)
    }
}

extension TransactionCategory {
    /// Bought from the carrier itself, so its logo stands for it.
    var isFromCarrier: Bool {
        self == .airtime || self == .bundles
    }
}
