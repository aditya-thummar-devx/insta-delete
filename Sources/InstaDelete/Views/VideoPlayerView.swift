import AVKit
import SwiftUI

/// AVPlayerView with its own controls hidden and no event handling, so keys/clicks reach SwiftUI.
private final class PassivePlayerView: AVPlayerView {
    override var acceptsFirstResponder: Bool { false }
    override func hitTest(_ point: NSPoint) -> NSView? { nil }
}

private struct PlayerSurface: NSViewRepresentable {
    let player: AVPlayer

    func makeNSView(context: Context) -> AVPlayerView {
        let v = PassivePlayerView()
        v.controlsStyle = .none
        v.videoGravity = .resizeAspect
        v.showsFullScreenToggleButton = false
        v.player = player
        return v
    }

    func updateNSView(_ v: AVPlayerView, context: Context) { v.player = player }
}

/// Video surface + the design's custom control bar (play/pause, time, scrubber, duration, mute).
struct VideoPlayerView: View {
    let video: VideoController

    var body: some View {
        ZStack {
            PlayerSurface(player: video.player)

            if !video.isPlaying {
                Button { video.toggle() } label: {
                    Image(systemName: "play.fill")
                        .font(.system(size: 30))
                        .padding(.leading, 4)
                        .frame(width: 76, height: 76)
                        .background(.black.opacity(0.55), in: Circle())
                        .foregroundStyle(.white)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Play video")
            }

            VStack {
                Spacer()
                ControlBar(video: video)
            }
        }
    }
}

private struct ControlBar: View {
    let video: VideoController

    var body: some View {
        HStack(spacing: 12) {
            Button { video.toggle() } label: {
                Image(systemName: video.isPlaying ? "pause.fill" : "play.fill")
                    .font(.system(size: 16))
                    .frame(width: 32, height: 32)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(video.isPlaying ? "Pause" : "Play")

            Text(Format.duration(video.time))
                .font(.system(size: 12).monospacedDigit())
                .frame(width: 44, alignment: .leading)

            Scrubber(fraction: video.duration > 0 ? video.time / video.duration : 0) { video.seek(toFraction: $0) }

            Text(Format.duration(video.duration))
                .font(.system(size: 12).monospacedDigit())
                .frame(width: 44, alignment: .trailing)

            Button { video.isMuted.toggle() } label: {
                Image(systemName: video.isMuted ? "speaker.slash.fill" : "speaker.wave.2.fill")
                    .font(.system(size: 15))
                    .frame(width: 32, height: 32)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(video.isMuted ? "Unmute" : "Mute")
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 14)
        .padding(.top, 26)
        .padding(.bottom, 12)
        .background(LinearGradient(colors: [.clear, .black.opacity(0.65)], startPoint: .top, endPoint: .bottom))
    }
}

private struct Scrubber: View {
    let fraction: Double
    let onSeek: (Double) -> Void

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(.white.opacity(0.3))
                Capsule().fill(.white).frame(width: geo.size.width * min(max(fraction, 0), 1))
            }
            .frame(height: 4)
            .frame(maxHeight: .infinity)
            .contentShape(Rectangle())
            .gesture(DragGesture(minimumDistance: 0).onChanged { onSeek($0.location.x / max(1, geo.size.width)) })
        }
        .frame(height: 20)
        .accessibilityElement()
        .accessibilityLabel("Playback position")
        .accessibilityValue("\(Int(fraction * 100)) percent")
        .accessibilityAdjustableAction { dir in
            onSeek(fraction + (dir == .increment ? 0.1 : -0.1))
        }
    }
}
