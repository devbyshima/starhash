import Contacts
import SwiftUI
import UIKit

/// Contact photos for the recipient picker, read one at a time as rows
/// come on screen and kept for the rest of the session. Reading every photo
/// up front would hold thousands of images for a list seen a screen at a
/// time.
@MainActor
@Observable
final class ContactPhotos {
    static let shared = ContactPhotos()

    private var images: [String: UIImage] = [:]
    /// Contacts whose photo is being read, or turned out to have none.
    @ObservationIgnored private var requested: Set<String> = []

    func image(for contactID: String) -> UIImage? {
        images[contactID]
    }

    /// Reads the contact's thumbnail once; later calls do nothing.
    func load(_ contactID: String) async {
        guard requested.insert(contactID).inserted else { return }
        if let image = await Self.thumbnail(for: contactID) {
            images[contactID] = image
        }
    }

    /// The thumbnail, decoded here rather than on the main actor when it is
    /// first drawn.
    @concurrent
    private nonisolated static func thumbnail(for contactID: String) async -> UIImage? {
        let keys = [CNContactThumbnailImageDataKey as any CNKeyDescriptor]
        guard let contact = try? CNContactStore().unifiedContact(withIdentifier: contactID, keysToFetch: keys),
              let data = contact.thumbnailImageData,
              let image = UIImage(data: data) else { return nil }
        return image.preparingForDisplay() ?? image
    }
}

/// A contact's photo in a recipient tile's shape (or a circle), with
/// `fallback` until it loads.
struct ContactPhotoTile<Fallback: View>: View {
    let contactID: String
    let size: CGFloat
    var isCircle = false
    @ViewBuilder var fallback: Fallback

    private var photos: ContactPhotos { .shared }

    var body: some View {
        Group {
            if let image = photos.image(for: contactID) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: size, height: size)
                    .clipShape(RoundedRectangle(cornerRadius: isCircle ? size / 2 : size * 0.3, style: .continuous))
                    .transition(.opacity)
            } else {
                fallback
            }
        }
        .animation(.easeOut(duration: 0.2), value: photos.image(for: contactID) != nil)
        .task(id: contactID) { await photos.load(contactID) }
    }
}
