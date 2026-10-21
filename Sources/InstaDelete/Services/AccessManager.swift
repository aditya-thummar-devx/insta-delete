import AppKit
import Foundation

/// Owns the user-granted root folder: NSOpenPanel + persisted security-scoped bookmark.
/// Scoped access stays open for the app's lifetime once granted (until replaced/forgotten).
@MainActor
final class AccessManager {
    private let defaultsKey = "rootFolderBookmark"
    private let defaults: UserDefaults
    private(set) var root: URL?

    init(defaults: UserDefaults = .standard) { self.defaults = defaults }

    /// The real home directory. `NSHomeDirectory()` returns the container when sandboxed.
    nonisolated static var realHome: URL {
        if let pw = getpwuid(getuid()), let dir = pw.pointee.pw_dir {
            return URL(fileURLWithPath: String(cString: dir), isDirectory: true)
        }
        return URL(fileURLWithPath: NSHomeDirectory(), isDirectory: true)
    }

    /// Resolve the stored bookmark and begin scoped access. Nil if none / invalid.
    func restore() -> URL? {
        guard let data = defaults.data(forKey: defaultsKey) else { return nil }
        var stale = false
        guard let url = try? URL(resolvingBookmarkData: data, options: .withSecurityScope,
                                 relativeTo: nil, bookmarkDataIsStale: &stale),
              url.startAccessingSecurityScopedResource() else {
            defaults.removeObject(forKey: defaultsKey)
            return nil
        }
        if stale { save(url) }
        adopt(url)
        return url
    }

    /// Show the open panel. `home == true` presets it to the Home folder.
    func requestAccess(home: Bool) -> URL? {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.prompt = "Grant Access"
        if home {
            panel.directoryURL = Self.realHome
            panel.message = "Choose your Home folder so InstaDelete can find images and videos."
        } else {
            panel.message = "Choose a folder for InstaDelete to scan."
        }
        guard panel.runModal() == .OK, let url = panel.url,
              url.startAccessingSecurityScopedResource() else { return nil }
        save(url)
        adopt(url)
        return url
    }

    func forget() {
        root?.stopAccessingSecurityScopedResource()
        defaults.removeObject(forKey: defaultsKey)
        root = nil
    }

    /// `url` must already have had `startAccessingSecurityScopedResource()` called once.
    private func adopt(_ url: URL) {
        if let old = root, old != url { old.stopAccessingSecurityScopedResource() }
        root = url
    }

    private func save(_ url: URL) {
        if let data = try? url.bookmarkData(options: .withSecurityScope, includingResourceValuesForKeys: nil, relativeTo: nil) {
            defaults.set(data, forKey: defaultsKey)
        }
    }
}
