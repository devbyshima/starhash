import SwiftUI
import UIKit

/// What a tap on the owner's photo offers, as a sheet sized to its rows:
/// take one with the camera, choose one from the library, or look at the
/// one they have. A choice the iPhone can't make (no camera, no photo yet)
/// is shown dimmed rather than missing, so the three always sit in place.
struct ProfilePhotoOptionsSheet: View {
    let hasPhoto: Bool
    let onChoose: (ProfilePhotoAction) -> Void

    @State private var height: CGFloat = 320

    private var hasCamera: Bool { UIImagePickerController.isSourceTypeAvailable(.camera) }

    var body: some View {
        VStack(spacing: 0) {
            SheetHeader("Your photo")

            VStack(spacing: 0) {
                row("Take Photo", symbol: "camera.fill", action: .camera, enabled: hasCamera)
                SheetDivider().padding(.leading, 52)
                row("Upload Photo", symbol: "square.and.arrow.up.fill", action: .library, enabled: true)
                SheetDivider().padding(.leading, 52)
                row("View Photo", symbol: "eye.fill", action: .view, enabled: hasPhoto)
            }
            .padding(.horizontal, 16)
            .sheetCard()
            .padding(.horizontal, 18)
            .padding(.bottom, 24)
        }
        .sheetHeight($height)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .ignoresSafeArea(.container, edges: .bottom)
        .sheetGlass(detents: [.height(height - 4)])
    }

    private func row(_ title: String, symbol: String, action: ProfilePhotoAction, enabled: Bool) -> some View {
        Button { onChoose(action) } label: {
            HStack(spacing: 14) {
                SheetIconCircle(symbol: symbol)
                Text(catalog: title)
                    .font(.sheetBody)
                    .foregroundStyle(Color.starhashPrimaryText)
                Spacer(minLength: 0)
            }
            .padding(.vertical, 8)
            .contentShape(Rectangle())
        }
        .buttonStyle(.hapticPlain)
        .disabled(!enabled)
        .opacity(enabled ? 1 : 0.4)
    }
}

enum ProfilePhotoAction {
    case camera, library, view
}

/// The camera, full screen, for a profile photo: the picture taken goes on
/// to the crop screen; nil when the owner cancels.
struct CameraPhotoPicker: UIViewControllerRepresentable {
    let onFinish: (UIImage?) -> Void

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.cameraDevice = .front
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ picker: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(onFinish: onFinish) }

    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let onFinish: (UIImage?) -> Void

        init(onFinish: @escaping (UIImage?) -> Void) {
            self.onFinish = onFinish
        }

        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            onFinish(info[.originalImage] as? UIImage)
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            onFinish(nil)
        }
    }
}

/// The owner's photo large on black, as Photos shows one, with a close
/// button.
struct ProfilePhotoViewer: View {
    let image: UIImage
    let onClose: () -> Void

    var body: some View {
        ZStack(alignment: .topLeading) {
            Color.black.ignoresSafeArea()
            Image(uiImage: image)
                .resizable()
                .scaledToFit()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .accessibilityLabel(Text("Your photo"))
            Button(action: onClose) {
                StarHashCircleGlyph(symbol: "xmark")
            }
            .buttonStyle(.hapticPlain)
            .accessibilityLabel("Close")
            .padding(.horizontal, StarHashMetrics.screenPadding)
            .padding(.top, 8)
        }
        .preferredColorScheme(.dark)
    }
}
