import Foundation
import ImageIO
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
        // The extension only nominates a candidate; the bytes must agree (e.g. `.ts` is both
        // MPEG-TS video and TypeScript, and any file can be misnamed).
        let kind: MediaItem.Kind
        if type.conforms(to: .image), ContentSniffer.isImage(url) { kind = .image }
        else if type.conforms(to: .movie), ContentSniffer.isVideo(url) { kind = .video }  // .movie excludes audio-only
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

/// Checks a file's actual contents, not its name.
enum ContentSniffer {
    /// ImageIO must recognise the header and report a pixel size (rejects text, truncated and vector-only files).
    static func isImage(_ url: URL) -> Bool {
        guard let src = CGImageSourceCreateWithURL(url as CFURL, [kCGImageSourceShouldCache: false] as CFDictionary),
              CGImageSourceGetType(src) != nil, CGImageSourceGetCount(src) > 0,
              let props = CGImageSourceCopyPropertiesAtIndex(src, 0, nil) as? [CFString: Any] else { return false }
        return props[kCGImagePropertyPixelWidth] != nil
    }

    /// Magic-number check for the container formats macOS treats as movies.
    static func isVideo(_ url: URL) -> Bool {
        guard let handle = try? FileHandle(forReadingFrom: url) else { return false }
        defer { try? handle.close() }
        guard let data = try? handle.read(upToCount: 512) else { return false }
        return isVideoHeader([UInt8](data))
    }

    static func isVideoHeader(_ b: [UInt8]) -> Bool {
        guard b.count >= 12 else { return false }
        func has(_ bytes: [UInt8], at i: Int) -> Bool { b.count >= i + bytes.count && Array(b[i..<i + bytes.count]) == bytes }
        func has(_ s: String, at i: Int) -> Bool { has(Array(s.utf8), at: i) }
        /// Transport stream: 0x47 sync byte repeating every packet, checked across 3 packets so text can't pass by chance.
        func syncs(offset: Int, packet: Int) -> Bool {
            b.count > offset + 2 * packet && (0..<3).allSatisfy { b[offset + $0 * packet] == 0x47 }
        }

        return ["ftyp", "moov", "mdat", "wide", "free", "skip", "pnot"].contains { has($0, at: 4) }  // MP4 / MOV / M4V / 3GP
            || syncs(offset: 0, packet: 188)                       // MPEG-TS (.ts)
            || syncs(offset: 4, packet: 192)                       // BDAV / AVCHD (.m2ts, .mts)
            || has([0x00, 0x00, 0x01, 0xBA], at: 0)                // MPEG program stream (.mpg, .vob)
            || has([0x00, 0x00, 0x01, 0xB3], at: 0)                // MPEG-1/2 elementary video
            || (has("RIFF", at: 0) && has("AVI ", at: 8))          // AVI
            || has([0x1A, 0x45, 0xDF, 0xA3], at: 0)                // Matroska / WebM
            || has("FLV", at: 0)                                   // Flash video
            || has([0x30, 0x26, 0xB2, 0x75, 0x8E, 0x66, 0xCF, 0x11], at: 0)  // ASF / WMV
            || has("OggS", at: 0)                                  // Ogg (.ogv)
    }
}
