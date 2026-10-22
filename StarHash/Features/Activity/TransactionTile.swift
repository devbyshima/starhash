import StarHashKit
import SwiftUI

/// The square beside a transaction, after the owner's reference: a rounded
/// square, white in either appearance with a hairline on the pale page,
/// holding what stands for who it was with. Their photo from Contacts
/// fills it; a purchase from the wallet's carrier shows the carrier's logo,
/// and another purchase what was bought; anyone else is their initial on a
/// pale wash of the green, and a number with no name the StarHash mark.
struct TransactionTile: View {
    let transaction: StarHashKit.Transaction
    var size: CGFloat = 44

    @AppStorage(PreferenceKey.enableContacts) private var enableContacts = true

    var body: some View {
        content
            .frame(width: size, height: size)
            .clipShape(shape)
            .overlay(shape.strokeBorder(Color.tileBorder, lineWidth: 1))
            .accessibilityHidden(true)
    }

    private var shape: RoundedRectangle {
        RoundedRectangle(cornerRadius: size * 0.24, style: .continuous)
    }

    @ViewBuilder
    private var content: some View {
        let counterparty = transaction.counterparty
        if enableContacts, let contactID = PayContacts.shared.photoContactID(for: counterparty) {
            ContactPhotoTile(contactID: contactID, size: size) { fallback }
        } else {
            fallback
        }
    }

    @ViewBuilder
    private var fallback: some View {
        if transaction.isPurchase, let category = transaction.knownCategory {
            if category.isFromCarrier, let wallet = transaction.wallet {
                // Airtime and bundles come from the carrier itself.
                WalletLogo(wallet: wallet, height: size * 0.36)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.tileSurface)
            } else {
                Image(symbol: category.symbol)
                    .font(.system(size: size * 0.42, weight: .semibold))
                    .foregroundStyle(Color.tilePlaceholderGlyph)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.tileSurface)
            }
        } else {
            PlaceholderTile(name: transaction.counterparty.shownName, size: size)
        }
    }
}

/// A tile with nothing to show: the name's initial in the deep green on its
/// pale wash, or the StarHash mark for a number with no name, where an
/// initial would be a "#".
struct PlaceholderTile: View {
    let name: String
    var size: CGFloat

    var body: some View {
        Group {
            if let initial = name.first(where: \.isLetter) {
                Text(String(initial).uppercased())
                    .font(.starhashFixed(size * 0.42, weight: .semibold))
                    .foregroundStyle(Color.tilePlaceholderGlyph)
            } else {
                StarHashMarkShape()
                    .fill(Color.tilePlaceholderGlyph)
                    .frame(width: size * 0.5, height: size * 0.5)
            }
        }
        .frame(width: size, height: size)
        .background(Color.tilePlaceholder)
    }
}

extension TransactionCategory {
    /// Bought from the carrier itself, so its logo stands for it.
    var isFromCarrier: Bool {
        self == .airtime || self == .bundles
    }
}
