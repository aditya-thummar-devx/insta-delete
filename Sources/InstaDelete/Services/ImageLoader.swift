import AppKit
import ImageIO

/// Full-size viewer images, downsampled with ImageIO so a 6000×4000 HEIC never decodes at full size.
final class ImageLoader: @unchecked Sendable {
    static let shared = ImageLoader()
    private let cache: NSCache<NSURL, NSImage> = {
        let c = NSCache<NSURL, NSImage>()
        c.countLimit = 12
        return c
    }()

    func cached(_ url: URL) -> NSImage? { cache.object(forKey: url as NSURL) }

    func image(for url: URL, maxPixel: CGFloat = 2000) async -> NSImage? {
        if let hit = cached(url) { return hit }
        let image = await Task.detached(priority: .userInitiated) { Self.downsample(url, maxPixel: maxPixel) }.value
        if let image { cache.setObject(image, forKey: url as NSURL) }
        return image
    }

    static func downsample(_ url: URL, maxPixel: CGFloat) -> NSImage? {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, [kCGImageSourceShouldCache: false] as CFDictionary) else { return nil }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixel,
        ]
        guard let cg = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else { return nil }
        return NSImage(cgImage: cg, size: NSSize(width: cg.width, height: cg.height))
    }
}
