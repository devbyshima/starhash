import PhotosUI
import SwiftUI
import UIKit

/// The owner's photo, chosen from their library on Profile: kept as one
/// small JPEG in Application Support, beside the transactions, and never
/// sent anywhere. Export carries it in the backup's profile.
@MainActor @Observable
final class ProfilePhoto {
    static let shared = ProfilePhoto()

    /// The photo as it is shown, or nil before one is chosen.
    private(set) var image: UIImage?

    private let url = URL.applicationSupportDirectory.appending(path: "StarHash/profile-photo.jpg")

    private init() {
        image = (try? Data(contentsOf: url)).flatMap(UIImage.init(data:))
    }

    /// The photo as saved, for the backup.
    var data: Data? { try? Data(contentsOf: url) }

    /// Keeps a picked photo: cropped to its middle square and made small,
    /// since it never shows bigger than Profile's circle.
    func set(_ data: Data) {
        guard let picked = UIImage(data: data), let square = Self.square(picked, side: 600),
              let jpeg = square.jpegData(compressionQuality: 0.85) else { return }
        save(jpeg)
    }

    /// Keeps a photo from a backup as it is.
    func restore(_ data: Data) {
        guard UIImage(data: data) != nil else { return }
        save(data)
    }

    func remove() {
        try? FileManager.default.removeItem(at: url)
        image = nil
    }

    private func save(_ jpeg: Data) {
        try? FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        guard (try? jpeg.write(to: url, options: [.atomic, .completeFileProtection])) != nil else { return }
        image = UIImage(data: jpeg)
    }

    private static func square(_ image: UIImage, side: CGFloat) -> UIImage? {
        let size = image.size
        let shortest = min(size.width, size.height)
        guard shortest > 0 else { return nil }
        let scale = min(side, shortest) / shortest
        let drawn = CGSize(width: size.width * scale, height: size.height * scale)
        let canvas = CGSize(width: shortest * scale, height: shortest * scale)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        return UIGraphicsImageRenderer(size: canvas, format: format).image { _ in
            image.draw(in: CGRect(
                x: (canvas.width - drawn.width) / 2,
                y: (canvas.height - drawn.height) / 2,
                width: drawn.width,
                height: drawn.height
            ))
        }
    }
}

/// The owner's photo in a circle, or a person on the cards' grey before
/// there is one.
struct ProfilePhotoView: View {
    var size: CGFloat

    var body: some View {
        Group {
            if let image = ProfilePhoto.shared.image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                Image(symbol: "person.fill")
                    .font(.system(size: size * 0.42, weight: .medium))
                    .foregroundStyle(Color.profilePhotoGlyph)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.profilePhotoFill)
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
        .accessibilityHidden(true)
    }
}

/// Profile's photo: tap to choose one from the library, with a small
/// accent badge saying so, and Remove Photo in its menu once there is one.
struct ProfilePhotoPicker: View {
    var size: CGFloat = 120

    @State private var item: PhotosPickerItem?

    var body: some View {
        PhotosPicker(selection: $item, matching: .images) {
            ProfilePhotoView(size: size)
                .overlay(alignment: .bottomTrailing) {
                    Image(symbol: "camera.fill")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Color.starhashOnInk)
                        .frame(width: 36, height: 36)
                        .background(Color.starhashInk, in: Circle())
                        .overlay(Circle().stroke(Color.starhashBackground, lineWidth: 3))
                        .accessibilityHidden(true)
                }
        }
        .buttonStyle(PressScaleButtonStyle())
        .contextMenu {
            if ProfilePhoto.shared.image != nil {
                Button(role: .destructive) {
                    withAnimation(.smooth) { ProfilePhoto.shared.remove() }
                } label: {
                    DestructiveMenuLabel("Remove Photo")
                }
            }
        }
        .accessibilityLabel(String(localized: "Your photo"))
        .accessibilityHint(String(localized: "Chooses a photo from your library"))
        .onChange(of: item) { _, item in
            guard let item else { return }
            Task {
                if let data = try? await item.loadTransferable(type: Data.self) {
                    withAnimation(.smooth) { ProfilePhoto.shared.set(data) }
                }
                self.item = nil
            }
        }
    }
}
