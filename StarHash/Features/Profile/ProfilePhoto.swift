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
        guard let picked = UIImage(data: data), let square = Self.square(picked, side: 600) else { return }
        set(square)
    }

    /// Keeps a photo already cropped to its square (`PhotoCropView`).
    func set(_ square: UIImage) {
        guard let jpeg = square.jpegData(compressionQuality: 0.85) else { return }
        save(jpeg)
        StarHashCloud.syncPhoto()
    }

    /// Keeps a photo from a backup as it is.
    func restore(_ data: Data) {
        guard UIImage(data: data) != nil else { return }
        save(data)
        StarHashCloud.syncPhoto()
    }

    func remove() {
        try? FileManager.default.removeItem(at: url)
        image = nil
        StarHashCloud.syncPhoto()
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

/// Profile's photo, with a small accent badge saying it can change: a tap
/// opens the photo's sheet (Take Photo, Upload Photo, View Photo), and
/// Remove Photo is in its menu once there is one. A photo taken or picked
/// opens on the crop screen first, to move and scale it in the circle.
struct ProfilePhotoPicker: View {
    var size: CGFloat = 120

    @State private var showsOptions = false
    /// What the sheet asked for, opened once the sheet has gone.
    @State private var chosen: ProfilePhotoAction?
    @State private var showsLibrary = false
    @State private var item: PhotosPickerItem?
    @State private var cover: Cover?

    /// What covers the screen: the camera, the crop screen on a photo, or
    /// the photo itself to look at. One at a time, so one presentation.
    enum Cover: Identifiable {
        case camera
        case crop(UIImage)
        case view(UIImage)

        var id: String {
            switch self {
            case .camera: "camera"
            case .crop(let image): "crop-\(ObjectIdentifier(image))"
            case .view: "view"
            }
        }
    }

    var body: some View {
        Button { showsOptions = true } label: {
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
        .accessibilityLabel(String(starhash: "Your photo"))
        .accessibilityHint(String(starhash: "Take, upload or view your photo"))
        .sheet(isPresented: $showsOptions, onDismiss: openChosen) {
            ProfilePhotoOptionsSheet(hasPhoto: ProfilePhoto.shared.image != nil) { action in
                chosen = action
                showsOptions = false
            }
        }
        .photosPicker(isPresented: $showsLibrary, selection: $item, matching: .images)
        .onChange(of: item) { _, item in
            guard let item else { return }
            Task {
                if let data = try? await item.loadTransferable(type: Data.self), let image = UIImage(data: data) {
                    cover = .crop(image)
                }
                self.item = nil
            }
        }
        .fullScreenCover(item: $cover) { cover in
            switch cover {
            case .camera:
                CameraPhotoPicker { image in
                    self.cover = image.map(Cover.crop)
                }
                .ignoresSafeArea()
            case .crop(let image):
                PhotoCropView(image: image) {
                    self.cover = nil
                } onChoose: { square in
                    self.cover = nil
                    withAnimation(.smooth) { ProfilePhoto.shared.set(square) }
                }
            case .view(let image):
                ProfilePhotoViewer(image: image) { self.cover = nil }
            }
        }
        #if DEBUG
        // -cropPhoto: the crop screen on a sample photo; -photoOptions: the
        // photo's sheet. For screenshots.
        .task {
            if DebugLaunch.arguments.contains("-cropPhoto"), cover == nil, let sample = UIImage(named: "DeveloperPhoto") {
                try? await Task.sleep(for: .milliseconds(500))
                cover = .crop(sample)
            }
            if DebugLaunch.arguments.contains("-photoOptions") {
                try? await Task.sleep(for: .milliseconds(500))
                showsOptions = true
            }
        }
        #endif
    }

    /// The sheet's choice, after it has gone: a second presentation can't
    /// start while the first is still leaving.
    private func openChosen() {
        guard let action = chosen else { return }
        chosen = nil
        switch action {
        case .camera: cover = .camera
        case .library: showsLibrary = true
        case .view:
            if let image = ProfilePhoto.shared.image { cover = .view(image) }
        }
    }
}
