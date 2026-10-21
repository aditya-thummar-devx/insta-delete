import AVFoundation
import Observation

/// One AVPlayer reused for the whole review; loading another item always stops the previous one.
@Observable
@MainActor
final class VideoController {
    @ObservationIgnored let player = AVPlayer()
    private(set) var isPlaying = false
    private(set) var time: Double = 0
    private(set) var duration: Double = 0
    /// Mute choice survives navigation within a review.
    var isMuted = false { didSet { player.isMuted = isMuted } }

    @ObservationIgnored private var timeObserver: Any?
    @ObservationIgnored private var endObserver: NSObjectProtocol?
    @ObservationIgnored private var loadedID: URL?

    init() {
        timeObserver = player.addPeriodicTimeObserver(forInterval: CMTime(seconds: 0.25, preferredTimescale: 600),
                                                      queue: .main) { [weak self] t in
            MainActor.assumeIsolated {
                guard let self, t.seconds.isFinite else { return }
                self.time = t.seconds
            }
        }
        endObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.isPlaying = false }
        }
    }

    deinit {
        if let timeObserver { player.removeTimeObserver(timeObserver) }
        if let endObserver { NotificationCenter.default.removeObserver(endObserver) }
    }

    /// Points the player at `item` (paused at 0:00), or clears it for images / nil.
    func load(_ item: MediaItem?) {
        player.pause()
        isPlaying = false
        time = 0
        duration = 0
        guard let item, item.isVideo else {
            loadedID = nil
            player.replaceCurrentItem(with: nil)
            return
        }
        loadedID = item.id
        player.replaceCurrentItem(with: AVPlayerItem(url: item.id))
        player.isMuted = isMuted
        Task {
            let d = await MetadataLoader.shared.metadata(for: item).duration
            if loadedID == item.id { duration = d ?? 0 }
        }
    }

    func toggle() {
        guard loadedID != nil else { return }
        if isPlaying {
            player.pause()
            isPlaying = false
        } else {
            if duration > 0, time >= duration - 0.05 { seek(toFraction: 0) }
            player.play()
            isPlaying = true
        }
    }

    func seek(toFraction f: Double) {
        guard duration > 0 else { return }
        let target = min(max(0, f), 1) * duration
        time = target
        player.seek(to: CMTime(seconds: target, preferredTimescale: 600), toleranceBefore: .zero, toleranceAfter: .zero)
    }

    func stop() {
        player.pause()
        isPlaying = false
    }
}
