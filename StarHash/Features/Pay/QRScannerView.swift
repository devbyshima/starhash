import AVFoundation
import PhotosUI
import StarHashKit
import SwiftUI
import UIKit

/// Pay's QR scanner, over the whole screen: the camera, a square to aim
/// with, and along the foot a photo of a code instead, the torch, and the
/// owner's own code for someone else to scan. A merchant's sticker or a
/// friend's StarHash code (`PaymentQR`) brings Pay back with them chosen,
/// and the amount typed when the code asks for one, so Pay dials them
/// without the recipient screen. A code that is not a payment code says so
/// and scanning goes on.
struct QRScannerView: View {
    /// Who the code says to pay; the caller closes the scanner.
    let onScan: (PaymentRequest) -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var camera = QRCamera()
    @State private var notAPaymentCode = false
    @State private var photoItem: PhotosPickerItem?
    @State private var showsMyCode = false
    @State private var found = 0
    @State private var refused = 0

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            switch camera.access {
            case .authorized:
                if camera.isAvailable {
                    QRCameraPreview(session: camera.session)
                        .ignoresSafeArea()
                        .accessibilityHidden(true)
                } else {
                    unavailable(
                        title: "No camera here",
                        message: "Choose a photo of the code instead."
                    )
                }
            case .denied:
                unavailable(
                    title: "Camera is off",
                    message: "Allow StarHash the camera in the Settings app to scan a code, or choose a photo of one.",
                    showsSettings: true
                )
            case .notDetermined:
                EmptyView()
            }
            viewfinder
                .opacity(camera.access == .authorized && camera.isAvailable ? 1 : 0)
        }
        .overlay(alignment: .top) { header }
        .overlay(alignment: .bottom) { footer }
        .environment(\.colorScheme, .dark)
        .statusBarHidden()
        .task {
            #if DEBUG
            // -scanCode reads its code without the camera.
            if DebugLaunch.value(after: "-scanCode") != nil { return }
            #endif
            await camera.start(onCode: read)
        }
        .onDisappear { camera.stop() }
        .onChange(of: photoItem) { _, item in
            guard let item else { return }
            Task { await readPhoto(item) }
        }
        .sensoryFeedback(.success, trigger: found)
        .sensoryFeedback(.error, trigger: refused)
        .sheet(isPresented: $showsMyCode) { MyCodeSheet() }
        #if DEBUG
        .task {
            // -scanCode <text>: as if the camera had seen this code.
            if let text = DebugLaunch.value(after: "-scanCode") {
                try? await Task.sleep(for: .seconds(1.5))
                read(text)
            }
        }
        #endif
    }

    // MARK: Pieces

    private var header: some View {
        HStack {
            Button { dismiss() } label: {
                StarHashCircleGlyph(symbol: "xmark")
            }
            .buttonStyle(.hapticPlain)
            .accessibilityLabel("Close")
            Spacer()
            if camera.hasTorch {
                Button { camera.toggleTorch() } label: {
                    StarHashCircleGlyph(symbol: camera.torchOn ? "flashlight.on.fill" : "flashlight.off.fill")
                }
                .buttonStyle(.hapticPlain)
                .accessibilityLabel(camera.torchOn ? "Turn off the torch" : "Turn on the torch")
            }
        }
        .padding(.horizontal, StarHashMetrics.screenPadding)
        .padding(.top, 8)
    }

    /// The square to aim with, its corners drawn bright, and the words
    /// under it.
    private var viewfinder: some View {
        GeometryReader { proxy in
            let side = max(min(proxy.size.width - 96, 300), 1)
            let frame = CGRect(
                x: (proxy.size.width - side) / 2,
                y: (proxy.size.height - side) / 2 - 40,
                width: side, height: side
            )
            ZStack {
                // The camera dimmed outside the square.
                Color.black.opacity(0.45)
                    .mask {
                        Rectangle()
                            .overlay {
                                RoundedRectangle(cornerRadius: 32, style: .continuous)
                                    .frame(width: side, height: side)
                                    .position(x: frame.midX, y: frame.midY)
                                    .blendMode(.destinationOut)
                            }
                            .compositingGroup()
                    }
                ViewfinderCorners()
                    .stroke(.white, style: StrokeStyle(lineWidth: 5, lineCap: .round, lineJoin: .round))
                    .frame(width: side, height: side)
                    .position(x: frame.midX, y: frame.midY)
                    .scaleEffect(found > 0 && !reduceMotion ? 0.94 : 1)
                    .animation(.spring(response: 0.3, dampingFraction: 0.6), value: found)
                VStack(spacing: 6) {
                    Text(notAPaymentCode ? "Not a payment code" : "Scan to pay")
                        .starhashFont(20, weight: .bold, relativeTo: .title3)
                        .contentTransition(.opacity)
                    Text(notAPaymentCode
                         ? "This code holds no number or merchant code."
                         : "A merchant's MoMo code, or a friend's StarHash code.")
                        .font(.starhash(.subheadline))
                        .foregroundStyle(.white.opacity(0.8))
                        .multilineTextAlignment(.center)
                        .contentTransition(.opacity)
                }
                .foregroundStyle(.white)
                .frame(width: max(side, 260))
                .position(x: frame.midX, y: frame.maxY + 56)
                .animation(.smooth(duration: 0.25), value: notAPaymentCode)
            }
        }
        .ignoresSafeArea()
    }

    private var footer: some View {
        HStack(spacing: 12) {
            PhotosPicker(selection: $photoItem, matching: .images) {
                Label("Photos", systemImage: "photo.on.rectangle")
                    .modifier(ScannerCapsule())
            }
            .buttonStyle(PressScaleButtonStyle())
            Button { showsMyCode = true } label: {
                Label("My Code", systemImage: "qrcode")
                    .modifier(ScannerCapsule())
            }
            .buttonStyle(PressScaleButtonStyle())
        }
        .padding(.horizontal, StarHashMetrics.screenPadding)
        .padding(.bottom, 12)
    }

    private func unavailable(title: String, message: String, showsSettings: Bool = false) -> some View {
        VStack(spacing: 10) {
            Image(systemName: "camera.fill")
                .font(.system(size: 34, weight: .semibold))
                .padding(.bottom, 6)
            Text(catalog: title)
                .starhashFont(20, weight: .bold, relativeTo: .title3)
            Text(catalog: message)
                .font(.starhash(.callout))
                .foregroundStyle(.white.opacity(0.8))
                .multilineTextAlignment(.center)
            if showsSettings {
                Button("Open Settings") { SettingsAppLink.open() }
                    .buttonStyle(.starhashPrimary)
                    .padding(.top, 14)
                    .frame(maxWidth: 260)
            }
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 40)
    }

    // MARK: Reading

    /// A code seen by the camera or found in a photo: pays when it is a
    /// payment code, says it is not one otherwise.
    private func read(_ text: String) {
        if let request = PaymentQR.parse(text) {
            camera.stop()
            found += 1
            Task {
                // The square's squeeze, before the scanner goes.
                try? await Task.sleep(for: .milliseconds(reduceMotion ? 50 : 250))
                onScan(request)
            }
        } else if !notAPaymentCode {
            refused += 1
            notAPaymentCode = true
            Task {
                try? await Task.sleep(for: .seconds(2.5))
                notAPaymentCode = false
            }
        }
    }

    private func readPhoto(_ item: PhotosPickerItem) async {
        defer { photoItem = nil }
        guard let data = try? await item.loadTransferable(type: Data.self),
              let image = CIImage(data: data) else { return }
        let detector = CIDetector(ofType: CIDetectorTypeQRCode, context: nil, options: [CIDetectorAccuracy: CIDetectorAccuracyHigh])
        let codes = (detector?.features(in: image) ?? []).compactMap { ($0 as? CIQRCodeFeature)?.messageString }
        if let payable = codes.first(where: { PaymentQR.parse($0) != nil }) {
            read(payable)
        } else {
            read(codes.first ?? "")
        }
    }
}

/// The scanner's foot buttons: white glass capsules on the camera.
private struct ScannerCapsule: ViewModifier {
    func body(content: Content) -> some View {
        content
            .starhashFont(16, weight: .semibold, relativeTo: .body)
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity, minHeight: 52)
            .contentShape(Capsule())
            .starhashGlass(interactive: true, tint: .white.opacity(0.08))
    }
}

/// The four corners of the viewfinder, each a rounded L.
private struct ViewfinderCorners: Shape {
    func path(in rect: CGRect) -> Path {
        let length = rect.width * 0.18
        let radius: CGFloat = 32
        var path = Path()
        for corner in 0..<4 {
            let flipX = corner == 1 || corner == 2
            let flipY = corner >= 2
            var piece = Path()
            piece.move(to: CGPoint(x: 0, y: length))
            piece.addLine(to: CGPoint(x: 0, y: radius))
            piece.addQuadCurve(to: CGPoint(x: radius, y: 0), control: .zero)
            piece.addLine(to: CGPoint(x: length, y: 0))
            let transform = CGAffineTransform(translationX: flipX ? rect.maxX : rect.minX, y: flipY ? rect.maxY : rect.minY)
                .scaledBy(x: flipX ? -1 : 1, y: flipY ? -1 : 1)
            path.addPath(piece, transform: transform)
        }
        return path
    }
}

// MARK: - Camera

/// The camera, reading QR codes. The session runs on a queue of its own
/// (starting it blocks); codes come back on the main actor.
@MainActor
@Observable
final class QRCamera {
    enum Access { case notDetermined, authorized, denied }

    private(set) var access: Access = QRCamera.currentAccess()
    private(set) var isAvailable = true
    private(set) var hasTorch = false
    private(set) var torchOn = false

    @ObservationIgnored let session = AVCaptureSession()
    @ObservationIgnored private let reader = QRMetadataReader()
    @ObservationIgnored private var device: AVCaptureDevice?
    @ObservationIgnored private var configured = false

    /// Asks for the camera the first time (iOS's own prompt, with nothing of
    /// StarHash's before it), then starts reading codes.
    func start(onCode: @escaping @MainActor (String) -> Void) async {
        if access == .notDetermined {
            _ = await AVCaptureDevice.requestAccess(for: .video)
            access = Self.currentAccess()
        }
        guard access == .authorized else { return }
        if !configured {
            configured = true
            guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
                  let input = try? AVCaptureDeviceInput(device: device),
                  session.canAddInput(input) else {
                isAvailable = false
                return
            }
            self.device = device
            hasTorch = device.hasTorch
            session.beginConfiguration()
            session.addInput(input)
            let output = AVCaptureMetadataOutput()
            if session.canAddOutput(output) {
                session.addOutput(output)
                output.setMetadataObjectsDelegate(reader, queue: .main)
                if output.availableMetadataObjectTypes.contains(.qr) { output.metadataObjectTypes = [.qr] }
            }
            session.commitConfiguration()
        }
        reader.onCode = onCode
        let box = SessionBox(session: session)
        await Task.detached { box.session.startRunning() }.value
    }

    func stop() {
        reader.onCode = nil
        if torchOn { toggleTorch() }
        let box = SessionBox(session: session)
        Task.detached { box.session.stopRunning() }
    }

    func toggleTorch() {
        guard let device, device.hasTorch, (try? device.lockForConfiguration()) != nil else { return }
        device.torchMode = torchOn ? .off : .on
        device.unlockForConfiguration()
        torchOn.toggle()
    }

    private static func currentAccess() -> Access {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized: .authorized
        case .notDetermined: .notDetermined
        default: .denied
        }
    }
}

/// The session, carried to the queue that starts and stops it: Apple asks
/// for that off the main thread, and the session is safe to use from any.
private struct SessionBox: @unchecked Sendable {
    let session: AVCaptureSession
}

/// Hears the codes the camera reads, on the main queue, and passes each
/// new one on once.
private final class QRMetadataReader: NSObject, AVCaptureMetadataOutputObjectsDelegate, @unchecked Sendable {
    /// Set and read on the main queue only.
    var onCode: (@MainActor (String) -> Void)?
    private var last: String?

    func metadataOutput(_ output: AVCaptureMetadataOutput, didOutput metadataObjects: [AVMetadataObject], from connection: AVCaptureConnection) {
        guard let code = metadataObjects.compactMap({ ($0 as? AVMetadataMachineReadableCodeObject)?.stringValue }).first,
              code != last else { return }
        last = code
        MainActor.assumeIsolated { onCode?(code) }
    }
}

/// The camera's picture, filling its frame.
private struct QRCameraPreview: UIViewRepresentable {
    let session: AVCaptureSession

    func makeUIView(context: Context) -> PreviewView {
        let view = PreviewView()
        view.previewLayer.session = session
        view.previewLayer.videoGravity = .resizeAspectFill
        return view
    }

    func updateUIView(_ uiView: PreviewView, context: Context) {}

    final class PreviewView: UIView {
        override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }
        var previewLayer: AVCaptureVideoPreviewLayer { layer as! AVCaptureVideoPreviewLayer }
    }
}
