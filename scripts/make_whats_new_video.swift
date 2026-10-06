// Frames a screen recording (or a screenshot) in an iPhone on white, as a
// What's New page shows it, and writes the square video the app plays:
//
//   swift scripts/make_whats_new_video.swift <recording.mov | screenshot.png> <Name> [--start 1.5] [--end 9] [--seconds 4] [--out file.mp4]
//
// The result is StarHash/Resources/WhatsNew/<Name>.mp4 (or --out), 1080 by 1080,
// H.264 with no sound track, which a release's `Release.Page(video:)` names
// as "<Name>". Record the simulator with
// `xcrun simctl io booted recordVideo --codec h264 feature.mov`, at 1x
// speed, in light mode, then trim with --start and --end. A screenshot
// becomes a still --seconds long. Run `xcodegen generate` after adding a
// new video so the app bundles it.
//
// The phone is measured from Cift's What's New: 94.5% of the frame's
// height, a thin titanium rim, a black bezel, the Dynamic Island, the side
// buttons and a soft shadow.

import AVFoundation
import CoreGraphics
import Foundation
import ImageIO
import VideoToolbox

let canvas = 1080
let frameRate: Int32 = 30

// MARK: Arguments

var positional: [String] = []
var options: [String: String] = [:]
var arguments = CommandLine.arguments.dropFirst().makeIterator()
while let argument = arguments.next() {
    if argument.hasPrefix("--"), let value = arguments.next() {
        options[String(argument.dropFirst(2))] = value
    } else {
        positional.append(argument)
    }
}
guard positional.count == 2 else {
    FileHandle.standardError.write(Data("usage: swift scripts/make_whats_new_video.swift <recording.mov | screenshot.png> <Name> [--start s] [--end s] [--seconds n] [--out file.mp4]\n".utf8))
    exit(2)
}
func seconds(_ key: String) -> Double? { options[key].flatMap(Double.init) }
let input = URL(fileURLWithPath: positional[0])
let name = positional[1]
let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
let output = options["out"].map { URL(fileURLWithPath: $0) } ?? root.appending(path: "StarHash/Resources/WhatsNew/\(name).mp4")
try? FileManager.default.createDirectory(at: output.deletingLastPathComponent(), withIntermediateDirectories: true)
try? FileManager.default.removeItem(at: output)

// MARK: The phone

let size = CGFloat(canvas)
let phoneHeight = size * 0.945
let phoneWidth = phoneHeight / 2.084
let phone = CGRect(x: (size - phoneWidth) / 2, y: size * 0.027, width: phoneWidth, height: phoneHeight)
let rim = phoneWidth * 0.0165
let bezel = phoneWidth * 0.019
let screen = phone.insetBy(dx: rim + bezel, dy: rim + bezel)
let screenRadius = screen.width * 0.137
let space = CGColorSpace(name: CGColorSpace.sRGB)!

func gray(_ white: CGFloat, _ alpha: CGFloat = 1) -> CGColor { CGColor(srgbRed: white, green: white, blue: white, alpha: alpha) }

/// Drawing in a top-left origin, as the measurements were taken.
func flipped(_ rect: CGRect) -> CGRect {
    CGRect(x: rect.minX, y: size - rect.maxY, width: rect.width, height: rect.height)
}

func rounded(_ rect: CGRect, _ radius: CGFloat) -> CGPath {
    CGPath(roundedRect: flipped(rect), cornerWidth: radius, cornerHeight: radius, transform: nil)
}

/// White, the shadow, the rim, the bezel and the buttons: everything but
/// the screen, drawn once.
func backdrop() -> CGImage {
    let context = CGContext(data: nil, width: canvas, height: canvas, bitsPerComponent: 8, bytesPerRow: 0, space: space, bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue)!
    context.setFillColor(gray(1))
    context.fill(CGRect(x: 0, y: 0, width: size, height: size))

    // Side buttons, under the body so only their edges show: the action
    // button and the volume buttons on the left, the side button on the right.
    context.setFillColor(gray(0.47))
    let buttons: [(x: CGFloat, from: CGFloat, to: CGFloat)] = [
        (phone.minX - 3, 0.209, 0.249), (phone.minX - 3, 0.289, 0.358), (phone.minX - 3, 0.381, 0.450),
        (phone.maxX - 3, 0.300, 0.420),
    ]
    for button in buttons {
        let rect = CGRect(x: button.x, y: phone.minY + phone.height * button.from, width: 6, height: phone.height * (button.to - button.from))
        context.addPath(rounded(rect, 2))
        context.fillPath()
    }

    // The body, casting a soft shadow down onto the white.
    let outerRadius = screenRadius + rim + bezel
    context.saveGState()
    context.setShadow(offset: CGSize(width: 0, height: -10), blur: 36, color: gray(0, 0.22))
    context.addPath(rounded(phone, outerRadius))
    context.setFillColor(gray(0.42))
    context.fillPath()
    context.restoreGState()

    // The titanium rim, lighter at its outer edge, then the bezel.
    context.addPath(rounded(phone, outerRadius))
    context.setFillColor(gray(0.52))
    context.fillPath()
    context.addPath(rounded(phone.insetBy(dx: rim * 0.45, dy: rim * 0.45), outerRadius - rim * 0.45))
    context.setFillColor(gray(0.30))
    context.fillPath()
    context.addPath(rounded(phone.insetBy(dx: rim, dy: rim), screenRadius + bezel))
    context.setFillColor(gray(0.03))
    context.fillPath()
    return context.makeImage()!
}

let background = backdrop()

/// One frame: the backdrop, the screen's picture filling the screen, and
/// the Dynamic Island over it.
func draw(_ picture: CGImage, into context: CGContext) {
    context.draw(background, in: CGRect(x: 0, y: 0, width: size, height: size))
    context.saveGState()
    context.addPath(rounded(screen, screenRadius))
    context.clip()
    let scale = max(screen.width / CGFloat(picture.width), screen.height / CGFloat(picture.height))
    let drawn = CGSize(width: CGFloat(picture.width) * scale, height: CGFloat(picture.height) * scale)
    let target = CGRect(x: screen.midX - drawn.width / 2, y: screen.midY - drawn.height / 2, width: drawn.width, height: drawn.height)
    context.interpolationQuality = .high
    context.draw(picture, in: flipped(target))
    context.restoreGState()

    let island = CGRect(x: screen.midX - screen.width * 0.311 / 2, y: screen.minY + screen.width * 0.027, width: screen.width * 0.311, height: screen.width * 0.092)
    context.addPath(rounded(island, island.height / 2))
    context.setFillColor(gray(0))
    context.fillPath()
}

// MARK: Writing

let writer = try AVAssetWriter(outputURL: output, fileType: .mp4)
let videoInput = AVAssetWriterInput(mediaType: .video, outputSettings: [
    AVVideoCodecKey: AVVideoCodecType.h264,
    AVVideoWidthKey: canvas,
    AVVideoHeightKey: canvas,
    AVVideoCompressionPropertiesKey: [
        AVVideoAverageBitRateKey: 5_000_000,
        AVVideoProfileLevelKey: AVVideoProfileLevelH264HighAutoLevel,
        AVVideoExpectedSourceFrameRateKey: frameRate,
    ],
])
videoInput.expectsMediaDataInRealTime = false
let adaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: videoInput, sourcePixelBufferAttributes: [
    kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
    kCVPixelBufferWidthKey as String: canvas,
    kCVPixelBufferHeightKey as String: canvas,
])
writer.add(videoInput)
guard writer.startWriting() else { fatalError("can't write \(output.path): \(writer.error.map(String.init(describing:)) ?? "")") }
writer.startSession(atSourceTime: .zero)

func append(_ picture: CGImage, at time: CMTime) {
    while !videoInput.isReadyForMoreMediaData { Thread.sleep(forTimeInterval: 0.005) }
    guard let pool = adaptor.pixelBufferPool else { fatalError("no pixel buffer pool") }
    var buffer: CVPixelBuffer?
    CVPixelBufferPoolCreatePixelBuffer(nil, pool, &buffer)
    guard let buffer else { fatalError("no pixel buffer") }
    CVPixelBufferLockBaseAddress(buffer, [])
    let context = CGContext(
        data: CVPixelBufferGetBaseAddress(buffer), width: canvas, height: canvas, bitsPerComponent: 8,
        bytesPerRow: CVPixelBufferGetBytesPerRow(buffer), space: space,
        bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue
    )!
    draw(picture, into: context)
    CVPixelBufferUnlockBaseAddress(buffer, [])
    adaptor.append(buffer, withPresentationTime: time)
}

var frames = 0
if ["png", "jpg", "jpeg", "heic"].contains(input.pathExtension.lowercased()) {
    guard let source = CGImageSourceCreateWithURL(input as CFURL, nil),
          let still = CGImageSourceCreateImageAtIndex(source, 0, nil)
    else { fatalError("can't read \(input.path)") }
    let count = Int((seconds("seconds") ?? 4) * Double(frameRate))
    for index in 0..<count {
        append(still, at: CMTime(value: CMTimeValue(index), timescale: frameRate))
        frames += 1
    }
} else {
    let asset = AVURLAsset(url: input)
    guard let track = try await asset.loadTracks(withMediaType: .video).first else { fatalError("\(input.path) has no picture") }
    let reader = try AVAssetReader(asset: asset)
    let start = CMTime(seconds: seconds("start") ?? 0, preferredTimescale: 600)
    let end = seconds("end").map { CMTime(seconds: $0, preferredTimescale: 600) } ?? .positiveInfinity
    reader.timeRange = CMTimeRange(start: start, end: end)
    let trackOutput = AVAssetReaderTrackOutput(track: track, outputSettings: [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA])
    reader.add(trackOutput)
    reader.startReading()
    var lastTime = CMTime.negativeInfinity
    let step = CMTime(value: 1, timescale: frameRate)
    while let sample = trackOutput.copyNextSampleBuffer() {
        guard let pixels = CMSampleBufferGetImageBuffer(sample) else { continue }
        let time = CMSampleBufferGetPresentationTimeStamp(sample) - start
        // At most the frame rate: a 60fps recording keeps every other frame.
        guard lastTime == .negativeInfinity || time - lastTime >= step - CMTime(value: 1, timescale: 600) else { continue }
        var picture: CGImage?
        VTCreateCGImageFromCVPixelBuffer(pixels, options: nil, imageOut: &picture)
        guard let picture else { continue }
        append(picture, at: time)
        lastTime = time
        frames += 1
    }
}

videoInput.markAsFinished()
await writer.finishWriting()
guard writer.status == .completed else { fatalError("writing failed: \(writer.error.map(String.init(describing:)) ?? "")") }
print("\(output.path): \(frames) frames, \(canvas)x\(canvas)")
