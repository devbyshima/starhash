import AVFoundation
import SwiftUI

/// A feature's video on the What's New sheet: silent, looping, filling its
/// card. It plays only while its page shows, from the start each time it
/// comes back, and only its picture is ever loaded, so music playing on
/// the iPhone carries on.
struct WhatsNewVideo: UIViewRepresentable {
    let url: URL
    let isPlaying: Bool

    func makeUIView(context: Context) -> PlayerView {
        PlayerView(url: url)
    }

    func updateUIView(_ view: PlayerView, context: Context) {
        view.setPlaying(isPlaying)
    }

    static func dismantleUIView(_ view: PlayerView, coordinator: ()) {
        view.stop()
    }

    final class PlayerView: UIView {
        override static var layerClass: AnyClass { AVPlayerLayer.self }

        private let player = AVQueuePlayer()
        private var looper: AVPlayerLooper?
        private var loading: Task<Void, Never>?
        private var wantsPlaying = false

        init(url: URL) {
            super.init(frame: .zero)
            player.isMuted = true
            player.preventsDisplaySleepDuringVideoPlayback = false
            let playerLayer = layer as? AVPlayerLayer
            playerLayer?.player = player
            playerLayer?.videoGravity = .resizeAspectFill
            backgroundColor = .white
            loading = Task { [weak self] in await self?.load(url) }
        }

        @available(*, unavailable)
        required init?(coder: NSCoder) { fatalError("init(coder:) is not used") }

        /// The video track alone, in a composition of its own: a sound
        /// track, even muted, would take the audio session and stop the
        /// music.
        private func load(_ url: URL) async {
            let asset = AVURLAsset(url: url)
            guard let source = try? await asset.loadTracks(withMediaType: .video).first,
                  let duration = try? await asset.load(.duration),
                  let transform = try? await source.load(.preferredTransform),
                  !Task.isCancelled
            else { return }
            let composition = AVMutableComposition()
            guard let track = composition.addMutableTrack(withMediaType: .video, preferredTrackID: kCMPersistentTrackID_Invalid),
                  (try? track.insertTimeRange(CMTimeRange(start: .zero, duration: duration), of: source, at: .zero)) != nil
            else { return }
            track.preferredTransform = transform
            looper = AVPlayerLooper(player: player, templateItem: AVPlayerItem(asset: composition))
            if wantsPlaying { player.play() }
        }

        func setPlaying(_ playing: Bool) {
            guard playing != wantsPlaying else { return }
            wantsPlaying = playing
            if playing {
                player.seek(to: .zero)
                player.play()
            } else {
                player.pause()
            }
        }

        func stop() {
            loading?.cancel()
            player.pause()
            looper?.disableLooping()
            looper = nil
        }
    }
}
