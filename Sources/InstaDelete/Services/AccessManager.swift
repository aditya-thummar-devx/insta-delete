import AppKit
import Foundation

/// Owns the user-granted root folders: NSOpenPanel + persisted security-scoped bookmarks.
/// Scoped access stays open for the app's lifetime once granted (until removed).
@MainActor
final class AccessManager {
    private let legacyKey = "rootFolderBookmark"
    private let defaultsKey = "rootFolderBookmarks"
    private let defaults: UserDefaults
    private(set) var roots: [URL] = []

    init(defaults: UserDefaults = .standard) { self.defaults = defaults }

    /// The real home directory. `NSHomeDirectory()` returns the container when sandboxed.
    nonisolated static var realHome: URL {
        if let pw = getpwuid(getuid()), let dir = pw.pointee.pw_dir {
            return URL(fileURLWithPath: String(cString: dir), isDirectory: true)
        }
        return URL(fileURLWithPath: NSHomeDirectory(), isDirectory: true)
    }

    /// True when `child` is `parent` or lives inside it. Compares whole path components,
    /// so `/a/Pics2` is not inside `/a/Pics`.
    nonisolated static func covers(_ parent: URL, _ child: URL) -> Bool {
        let p = parent.resolvingSymlinksInPath().path
        let c = child.resolvingSymlinksInPath().path
        return c == p || c.hasPrefix(p.hasSuffix("/") ? p : p + "/")
    }

    /// Resolve stored bookmarks and begin scoped access. Empty if none / all invalid.
    func restore() -> [URL] {
        var stored = defaults.array(forKey: defaultsKey) as? [Data] ?? []
        if stored.isEmpty, let old = defaults.data(forKey: legacyKey) { stored = [old] }  // pre-multi-folder install
        defaults.removeObject(forKey: legacyKey)

        var changed = false
        for data in stored {
            var stale = false
            guard let url = try? URL(resolvingBookmarkData: data, options: .withSecurityScope,
                                     relativeTo: nil, bookmarkDataIsStale: &stale),
                  url.startAccessingSecurityScopedResource() else { changed = true; continue }
            if stale { changed = true }
            roots.append(url)
        }
        if changed || defaults.array(forKey: defaultsKey) == nil { save() }
        return roots
    }

    /// First grant: show the open panel and make the pick the only root. `home == true` presets Home.
    func requestAccess(home: Bool) -> URL? {
        let panel = makePanel()
        if home {
            panel.directoryURL = Self.realHome
            panel.message = "Choose your Home folder so InstaDelete can find images and videos."
        } else {
            panel.message = "Choose a folder for InstaDelete to scan."
        }
        guard panel.runModal() == .OK, let url = panel.url,
              url.startAccessingSecurityScopedResource() else { return nil }
        roots.forEach { $0.stopAccessingSecurityScopedResource() }
        roots = [url]
        save()
        return url
    }

    enum AddResult {
        case cancelled
        /// Already covered by an existing root; nothing changed.
        case alreadyCovered(by: URL)
        /// Added. `replaced` are older roots the new one contains (their access was dropped).
        case added(URL, replaced: [URL])
    }

    func addRoot() -> AddResult {
        let panel = makePanel()
        panel.message = "Choose a folder to add to the scan."
        guard panel.runModal() == .OK, let url = panel.url else { return .cancelled }
        return add(url)
    }

    /// Panel-free half of `addRoot`, so tests can drive it.
    func add(_ url: URL) -> AddResult {
        if let parent = roots.first(where: { Self.covers($0, url) }) { return .alreadyCovered(by: parent) }
        _ = url.startAccessingSecurityScopedResource()  // always true for open-panel URLs; plain URLs (tests) just skip scoping
        let replaced = roots.filter { Self.covers(url, $0) }
        replaced.forEach { $0.stopAccessingSecurityScopedResource() }
        roots.removeAll { r in replaced.contains(r) }
        roots.append(url)
        save()
        return .added(url, replaced: replaced)
    }

    func removeRoot(_ url: URL) {
        guard let i = roots.firstIndex(of: url) else { return }
        roots[i].stopAccessingSecurityScopedResource()
        roots.remove(at: i)
        save()
    }

    private func makePanel() -> NSOpenPanel {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.prompt = "Grant Access"
        return panel
    }

    private func save() {
        let data = roots.compactMap {
            try? $0.bookmarkData(options: .withSecurityScope, includingResourceValuesForKeys: nil, relativeTo: nil)
        }
        defaults.set(data, forKey: defaultsKey)
    }
}
