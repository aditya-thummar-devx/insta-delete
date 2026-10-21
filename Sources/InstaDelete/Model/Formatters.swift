import Foundation

enum Format {
    static func size(_ bytes: Int64) -> String {
        ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
    }

    /// "1:05", or "1:02:03" for an hour or more.
    static func duration(_ seconds: Double) -> String {
        let s = max(0, Int(seconds))
        let (h, m, sec) = (s / 3600, (s % 3600) / 60, s % 60)
        return h > 0 ? String(format: "%d:%02d:%02d", h, m, sec) : String(format: "%d:%02d", m, sec)
    }

    static func plural(_ n: Int, _ word: String) -> String { "\(n) \(word)\(n == 1 ? "" : "s")" }

    /// "3 images · 2 videos", "4 images", "1 video", "0 items".
    static func mix(_ items: [MediaItem]) -> String {
        let v = items.filter(\.isVideo).count
        let i = items.count - v
        if items.isEmpty { return "0 items" }
        if v == 0 { return plural(i, "image") }
        if i == 0 { return plural(v, "video") }
        return "\(plural(i, "image")) · \(plural(v, "video"))"
    }

    static func date(_ d: Date) -> String { d.formatted(date: .abbreviated, time: .shortened) }

    static func dimensions(_ s: CGSize) -> String { "\(Int(s.width)) × \(Int(s.height))" }
}
