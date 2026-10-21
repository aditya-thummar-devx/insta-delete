import AppKit
import QuickLookThumbnailing

final class ThumbnailCache: @unchecked Sendable {
    static let shared = ThumbnailCache()
    private let cache: NSCache<NSURL, NSImage> = {
        let c = NSCache<NSURL, NSImage>()
        c.countLimit = 1500
        return c
    }()

    func cached(_ url: URL) -> NSImage? { cache.object(forKey: url as NSURL) }

    func thumbnail(for url: URL, points: CGFloat = 256, scale: CGFloat = 2) async -> NSImage? {
        if let hit = cached(url) { return hit }
        let request = QLThumbnailGenerator.Request(
            fileAt: url, size: CGSize(width: points, height: points), scale: scale, representationTypes: .thumbnail)
        guard let rep = try? await QLThumbnailGenerator.shared.generateBestRepresentation(for: request) else { return nil }
        let image = rep.nsImage
        cache.setObject(image, forKey: url as NSURL)
        return image
    }
}
