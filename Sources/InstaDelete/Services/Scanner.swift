import Foundation
import UniformTypeIdentifiers

enum ScanEvent: Sendable {
    case folderStarted(Folder)
    case folderDone(Folder)
    case found([MediaItem], path: String)
}

/// Read-only filesystem walk. Never mutates anything.
enum Scanner {
    static let resourceKeys: [URLResourceKey] = [
        .contentTypeKey, .fileSizeKey, .contentModificationDateKey, .isPackageKey, .isDirectoryKey,
    ]
    /// Order the per-folder rows are shown/scanned in.
    static let folderOrder: [Folder] = Folder.named + [.other]

    static func stream(root: URL, home: URL = AccessManager.realHome) -> AsyncStream<ScanEvent> {
        AsyncStream { continuation in
            let task = Task.detached(priority: .userInitiated) {
                scanSync(root: root, home: home, isCancelled: { Task.isCancelled }) { continuation.yield($0) }
                continuation.finish()
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    static func scanSync(root: URL, home: URL, isCancelled: () -> Bool, emit: @escaping (ScanEvent) -> Void) {
        let fm = FileManager.default
        let keys: Set<URLResourceKey> = Set(resourceKeys)
        let top = (try? fm.contentsOfDirectory(at: root, includingPropertiesForKeys: resourceKeys,
                                               options: [.skipsHiddenFiles])) ?? []

        var namedDirs: [Folder: URL] = [:]
        var others: [URL] = []
        for url in top {
            let name = url.lastPathComponent
            if name == "Library" { continue }  // never descend into ~/Library
            let v = try? url.resourceValues(forKeys: keys)
            if v?.isPackage == true { continue }
            if v?.isDirectory == true, case let f = Folder.bucket(forTopLevelName: name), f != .other {
                namedDirs[f] = url
            } else {
                others.append(url)
            }
        }

        let batcher = Batcher(emit: emit)
        for folder in folderOrder {
            if isCancelled() { return }
            emit(.folderStarted(folder))
            let urls = folder == .other ? others : namedDirs[folder].map { [$0] } ?? []
            for url in urls {
                walk(url, folder: folder, root: root, home: home, keys: keys, batcher: batcher, isCancelled: isCancelled)
                if isCancelled() { return }
            }
            batcher.flush()
            emit(.folderDone(folder))
        }
    }

    private static func walk(_ url: URL, folder: Folder, root: URL, home: URL, keys: Set<URLResourceKey>,
                             batcher: Batcher, isCancelled: () -> Bool) {
        if let item = classify(url, folder: folder, root: root, home: home, keys: keys) {
            batcher.add(item)
            return
        }
        guard let en = FileManager.default.enumerator(
            at: url, includingPropertiesForKeys: resourceKeys,
            options: [.skipsHiddenFiles, .skipsPackageDescendants],
            errorHandler: { _, _ in true }) else { return }
        while let child = en.nextObject() as? URL {
            if isCancelled() { return }
            if let item = classify(child, folder: folder, root: root, home: home, keys: keys) {
                batcher.add(item)
            }
        }
    }

    static func classify(_ url: URL, folder: Folder, root: URL, home: URL, keys: Set<URLResourceKey>) -> MediaItem? {
        guard let v = try? url.resourceValues(forKeys: keys),
              v.isPackage != true, v.isDirectory != true,
              let type = v.contentType else { return nil }
        let kind: MediaItem.Kind
        if type.conforms(to: .image) { kind = .image }
        else if type.conforms(to: .movie) { kind = .video }  // .movie excludes audio-only files
        else { return nil }
        return MediaItem(
            id: url, name: url.lastPathComponent, kind: kind,
            typeDescription: type.localizedDescription ?? type.preferredFilenameExtension?.uppercased() ?? "File",
            size: Int64(v.fileSize ?? 0), modified: v.contentModificationDate ?? .distantPast,
            folder: folder, displayFolder: displayFolder(for: url, root: root, home: home))
    }

    /// "~/Pictures/Trips" when root is Home, otherwise "<rootName>/sub".
    static func displayFolder(for url: URL, root: URL, home: URL) -> String {
        let dir = url.deletingLastPathComponent().resolvingSymlinksInPath().path
        let rootPath = root.resolvingSymlinksInPath().path
        let prefix = rootPath == home.resolvingSymlinksInPath().path ? "~" : root.lastPathComponent
        guard dir.hasPrefix(rootPath) else { return dir }
        return prefix + dir.dropFirst(rootPath.count)
    }

    /// Coalesces found items so the UI gets a few hundred per update, not one.
    private final class Batcher {
        private var items: [MediaItem] = []
        private var last = Date()
        private let emit: (ScanEvent) -> Void
        init(emit: @escaping (ScanEvent) -> Void) { self.emit = emit }

        func add(_ item: MediaItem) {
            items.append(item)
            if items.count >= 250 || Date().timeIntervalSince(last) > 0.1 { flush(path: item.id.path) }
        }

        func flush(path: String = "") {
            guard !items.isEmpty else { return }
            emit(.found(items, path: path))
            items.removeAll(keepingCapacity: true)
            last = Date()
        }
    }
}
