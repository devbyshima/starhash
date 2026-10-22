import SwiftUI
import UIKit

/// The photo just picked, before it becomes the owner's: shown full screen
/// on black, as the scanner is, under a round frame the size Profile shows
/// it. Pinch to make it bigger, drag to choose what the circle holds, and
/// Choose keeps exactly that; a double tap puts it back as it came. The
/// photo always covers the circle, so the crop never has an empty edge.
struct PhotoCropView: View {
    let image: UIImage
    let onCancel: () -> Void
    let onChoose: (UIImage) -> Void

    /// How much bigger than just covering the circle (1 to 5).
    @State private var zoom: CGFloat = 1
    @State private var zoomAtStart: CGFloat?
    /// How far the photo's middle is from the circle's, in points.
    @State private var offset: CGSize = .zero
    @State private var offsetAtStart: CGSize?

    private static let maxZoom: CGFloat = 5
    /// The square a crop is drawn at, as `ProfilePhoto` keeps it.
    private static let outputSide: CGFloat = 600

    var body: some View {
        GeometryReader { proxy in
            let side = min(proxy.size.width - 48, 360)
            let shown = shownSize(circle: side)
            ZStack {
                Color.black.ignoresSafeArea()

                Image(uiImage: image)
                    .resizable()
                    .frame(width: shown.width, height: shown.height)
                    .offset(offset)
                    .frame(width: proxy.size.width, height: proxy.size.height)

                CropMask(side: side)
                    .allowsHitTesting(false)
            }
            // The photo and its dimming run under the status bar and the
            // home indicator too, all centred on the same point.
            .ignoresSafeArea()
            .contentShape(Rectangle())
            .gesture(
                MagnifyGesture()
                    .onChanged { value in
                        let start = zoomAtStart ?? zoom
                        zoomAtStart = start
                        zoom = min(max(start * value.magnification, 1), Self.maxZoom)
                        offset = clamped(offset, circle: side)
                    }
                    .onEnded { _ in zoomAtStart = nil }
                    .simultaneously(with: DragGesture()
                        .onChanged { value in
                            let start = offsetAtStart ?? offset
                            offsetAtStart = start
                            offset = clamped(
                                CGSize(width: start.width + value.translation.width, height: start.height + value.translation.height),
                                circle: side
                            )
                        }
                        .onEnded { _ in offsetAtStart = nil })
            )
            .onTapGesture(count: 2) {
                withAnimation(.smooth(duration: 0.3)) {
                    zoom = 1
                    offset = .zero
                }
            }
            .overlay(alignment: .top) { header }
            .overlay(alignment: .bottom) {
                Button("Choose") { onChoose(crop(circle: side)) }
                    .buttonStyle(.starhashPrimary)
                    .padding(.horizontal, StarHashMetrics.screenPadding)
                    .padding(.bottom, 12)
            }
        }
        .preferredColorScheme(.dark)
        .statusBarHidden()
    }

    private var header: some View {
        ZStack {
            Text("Move and Scale")
                .starhashFont(17, weight: .semibold, relativeTo: .headline)
                .foregroundStyle(.white)
                .accessibilityAddTraits(.isHeader)
            HStack {
                Button("Cancel", action: onCancel)
                    .starhashFont(17, relativeTo: .body)
                    .foregroundStyle(.white)
                    .buttonStyle(.hapticPlain)
                Spacer()
            }
        }
        .padding(.horizontal, StarHashMetrics.screenPadding)
        .padding(.top, 12)
    }

    /// The photo's size on screen: just covering the circle, times the zoom.
    private func shownSize(circle side: CGFloat) -> CGSize {
        let size = image.size
        guard size.width > 0, size.height > 0 else { return CGSize(width: side, height: side) }
        let cover = side / min(size.width, size.height)
        return CGSize(width: size.width * cover * zoom, height: size.height * cover * zoom)
    }

    /// `offset` kept so the photo still covers the circle.
    private func clamped(_ offset: CGSize, circle side: CGFloat) -> CGSize {
        let shown = shownSize(circle: side)
        let maxX = max(0, (shown.width - side) / 2)
        let maxY = max(0, (shown.height - side) / 2)
        return CGSize(width: min(max(offset.width, -maxX), maxX), height: min(max(offset.height, -maxY), maxY))
    }

    /// What the circle holds, as a square photo at `outputSide`.
    private func crop(circle side: CGFloat) -> UIImage {
        let k = Self.outputSide / side
        let shown = shownSize(circle: side)
        let drawn = CGSize(width: shown.width * k, height: shown.height * k)
        let origin = CGPoint(
            x: Self.outputSide / 2 + offset.width * k - drawn.width / 2,
            y: Self.outputSide / 2 + offset.height * k - drawn.height / 2
        )
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let canvas = CGSize(width: Self.outputSide, height: Self.outputSide)
        return UIGraphicsImageRenderer(size: canvas, format: format).image { _ in
            image.draw(in: CGRect(origin: origin, size: drawn))
        }
    }
}

/// Everything but the circle dimmed, and a thin ring round it.
private struct CropMask: View {
    let side: CGFloat

    var body: some View {
        ZStack {
            // The dimming with the circle cut out of it.
            Color.black.opacity(0.6)
                .mask {
                    Rectangle()
                        .overlay {
                            Circle()
                                .frame(width: side, height: side)
                                .blendMode(.destinationOut)
                        }
                        .compositingGroup()
                }
            Circle()
                .stroke(Color.white.opacity(0.85), lineWidth: 1.5)
                .frame(width: side, height: side)
        }
    }
}
