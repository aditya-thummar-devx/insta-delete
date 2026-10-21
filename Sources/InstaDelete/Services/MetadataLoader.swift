import AVFoundation
import CoreGraphics
import ImageIO

struct MediaMetadata: Sendable {
    var pixelSize: CGSize?
    var duration: Double?
}

/// Lazy dimensions/duration, loaded on demand and cached (kept out of MediaItem so scanning stays cheap).
actor MetadataLoader {
    static let shared = MetadataLoader()
    private var cache: [URL: MediaMetadata] = [:]

    func metadata(for item: MediaItem) async -> MediaMetadata {
        if let hit = cache[item.id] { return hit }
        let result = item.isVideo ? await Self.videoMetadata(item.id) : Self.imageMetadata(item.id)
        cache[item.id] = result
        return result
    }

    private static func imageMetadata(_ url: URL) -> MediaMetadata {
        guard let src = CGImageSourceCreateWithURL(url as CFURL, nil),
              let props = CGImageSourceCopyPropertiesAtIndex(src, 0, nil) as? [CFString: Any],
              var w = props[kCGImagePropertyPixelWidth] as? Double,
              var h = props[kCGImagePropertyPixelHeight] as? Double else { return MediaMetadata() }
        // EXIF orientations 5–8 are rotated 90°, so the displayed width/height swap.
        if let o = props[kCGImagePropertyOrientation] as? Int, (5...8).contains(o) { swap(&w, &h) }
        return MediaMetadata(pixelSize: CGSize(width: w, height: h))
    }

    private static func videoMetadata(_ url: URL) async -> MediaMetadata {
        let asset = AVURLAsset(url: url)
        var meta = MediaMetadata()
        if let d = try? await asset.load(.duration), d.isNumeric, d.seconds.isFinite { meta.duration = d.seconds }
        if let track = try? await asset.loadTracks(withMediaType: .video).first,
           let size = try? await track.load(.naturalSize),
           let transform = try? await track.load(.preferredTransform) {
            let r = CGRect(origin: .zero, size: size).applying(transform)
            meta.pixelSize = CGSize(width: abs(r.width), height: abs(r.height))
        }
        return meta
    }
}
