import Foundation

/// The persisted "To Be Binned" set. Stores path + size + mtime so a file that was
/// replaced or edited since marking is dropped rather than trashed by surprise.
final class MarkedStore {
    struct Entry: Codable, Equatable {
        let path: String
        let size: Int64
        let mtime: TimeInterval
    }

    private(set) var entries: [String: Entry] = [:]
    private let fileURL: URL?

    /// `fileURL == nil` keeps everything in memory (tests / previews).
    init(fileURL: URL? = MarkedStore.defaultFileURL) {
        self.fileURL = fileURL
        load()
    }

    static var defaultFileURL: URL? {
        guard let dir = try? FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask,
                                                     appropriateFor: nil, create: true) else { return nil }
        let app = dir.appendingPathComponent("InstaDelete", isDirectory: true)
        try? FileManager.default.createDirectory(at: app, withIntermediateDirectories: true)
        return app.appendingPathComponent("marked.json")
    }

    var ids: Set<URL> { Set(entries.values.map { URL(fileURLWithPath: $0.path) }) }

    func contains(_ url: URL) -> Bool { entries[url.path] != nil }

    func add(_ item: MediaItem) {
        entries[item.id.path] = Entry(path: item.id.path, size: item.size, mtime: item.modified.timeIntervalSince1970)
        save()
    }

    func remove(_ url: URL) {
        entries[url.path] = nil
        save()
    }

    func removeAll() {
        entries = [:]
        save()
    }

    /// Drop entries whose file is no longer in `items` or whose size/mtime changed. Call after a full scan.
    func reconcile(with items: [MediaItem]) {
        let live = Dictionary(items.map { ($0.id.path, $0) }, uniquingKeysWith: { a, _ in a })
        let before = entries.count
        entries = entries.filter { path, entry in
            guard let item = live[path] else { return false }
            return item.size == entry.size && abs(item.modified.timeIntervalSince1970 - entry.mtime) < 1
        }
        if entries.count != before { save() }
    }

    private func load() {
        guard let fileURL, let data = try? Data(contentsOf: fileURL),
              let list = try? JSONDecoder().decode([Entry].self, from: data) else { return }
        entries = Dictionary(list.map { ($0.path, $0) }, uniquingKeysWith: { a, _ in a })
    }

    private func save() {
        guard let fileURL, let data = try? JSONEncoder().encode(Array(entries.values)) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }
}
