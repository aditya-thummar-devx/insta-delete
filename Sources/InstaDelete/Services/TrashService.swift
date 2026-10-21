import Foundation

/// The only code in the app that mutates user files. It can move to the Trash and move back (Undo);
/// it never deletes anything permanently.
protocol FileTrasher {
    /// Moves to the Trash; returns where it landed.
    func trash(at url: URL) throws -> URL?
    /// Undo: moves a trashed file back to its original location.
    func move(from: URL, to: URL) throws
}

struct SystemFileTrasher: FileTrasher {
    func trash(at url: URL) throws -> URL? {
        var resulting: NSURL?
        try FileManager.default.trashItem(at: url, resultingItemURL: &resulting)
        return resulting as URL?
    }

    func move(from: URL, to: URL) throws {
        try FileManager.default.moveItem(at: from, to: to)
    }
}

struct TrashedRecord: Equatable {
    let item: MediaItem
    /// Where the file landed in the Trash. Nil if the system didn't report it (then Undo is unavailable).
    let resulting: URL?
    var original: URL { item.id }
}

struct TrashFailure: Equatable {
    let item: MediaItem
    let message: String
}

struct TrashResult: Equatable {
    var trashed: [TrashedRecord] = []
    var failed: [TrashFailure] = []
}

enum TrashError: LocalizedError {
    case missing, insidePackage, changedSinceScan, nothingToRestore, destinationExists

    var errorDescription: String? {
        switch self {
        case .missing: "The file no longer exists."
        case .insidePackage: "It’s inside an app or library bundle, which InstaDelete never touches."
        case .changedSinceScan: "It changed after it was scanned. Rescan and review it again."
        case .nothingToRestore: "macOS didn’t report where it went. Use Put Back in Finder."
        case .destinationExists: "Something else now exists at the original location."
        }
    }
}

struct TrashService {
    var trasher: FileTrasher = SystemFileTrasher()

    /// Callers must have already obtained confirmation + device authentication (see `MoveFlow`).
    func trash(_ items: [MediaItem]) -> TrashResult {
        var result = TrashResult()
        for item in items {
            do {
                try precheck(item)
                let landed = try trasher.trash(at: item.id)
                result.trashed.append(TrashedRecord(item: item, resulting: landed))
            } catch {
                result.failed.append(TrashFailure(item: item, message: error.localizedDescription))
            }
        }
        return result
    }

    /// Undo: put each file back at its original path.
    func restore(_ records: [TrashedRecord]) -> (restored: [TrashedRecord], failed: [TrashFailure]) {
        var restored: [TrashedRecord] = []
        var failed: [TrashFailure] = []
        for r in records {
            do {
                guard let from = r.resulting else { throw TrashError.nothingToRestore }
                guard !FileManager.default.fileExists(atPath: r.original.path) else { throw TrashError.destinationExists }
                try trasher.move(from: from, to: r.original)
                restored.append(r)
            } catch {
                failed.append(TrashFailure(item: r.item, message: error.localizedDescription))
            }
        }
        return (restored, failed)
    }

    /// Safety checks right before touching a file: still there, unchanged since the scan, not inside a package.
    private func precheck(_ item: MediaItem) throws {
        // Fresh URL on purpose: the scanner's URL instance caches size/mtime from scan time,
        // which would make this check compare the scan against itself.
        let fresh = URL(fileURLWithPath: item.id.path)
        let keys: Set<URLResourceKey> = [.fileSizeKey, .contentModificationDateKey]
        guard let v = try? fresh.resourceValues(forKeys: keys), let size = v.fileSize else { throw TrashError.missing }
        if Self.isInsidePackage(item.id) { throw TrashError.insidePackage }
        let mtime = v.contentModificationDate ?? .distantPast
        if Int64(size) != item.size || abs(mtime.timeIntervalSince(item.modified)) >= 1 { throw TrashError.changedSinceScan }
    }

    static func isInsidePackage(_ url: URL) -> Bool {
        var dir = url.deletingLastPathComponent()
        while dir.pathComponents.count > 1 {
            if (try? dir.resourceValues(forKeys: [.isPackageKey]))?.isPackage == true { return true }
            dir = dir.deletingLastPathComponent()
        }
        return false
    }
}

enum MoveOutcome: Equatable {
    case cancelled
    case authFailed(String)
    case done(TrashResult)
}

/// Enforces the order: (caller already showed the confirmation) → device authentication → trash.
/// `trash` is never reached unless authentication succeeded.
struct MoveFlow {
    var authenticate: (String) async -> AuthOutcome = { await AuthService().authenticate(reason: $0) }
    var trash = TrashService()

    func run(_ items: [MediaItem]) async -> MoveOutcome {
        guard !items.isEmpty else { return .cancelled }
        switch await authenticate("move \(Format.plural(items.count, "item")) to the Bin") {
        case .success: return .done(trash.trash(items))
        case .cancelled: return .cancelled
        case .failed(let message): return .authFailed(message)
        }
    }
}
