import Observation
import SwiftUI

enum AppPhase { case access, scanning, library, review, complete }
enum LibraryMode { case all, bin }
enum FolderScanState { case waiting, scanning, done }

@Observable
@MainActor
final class LibraryStore {
    var phase: AppPhase = .access
    var libraryView: LibraryMode = .all
    var selectedFolder: Folder = .all { didSet { recomputeScope() } }
    private(set) var items: [MediaItem] = []
    /// Items in the current folder (+ filter/sort from M4). Grid and review queue both read this.
    private(set) var scope: [MediaItem] = []
    private(set) var root: URL?

    // Scan state
    private(set) var isScanning = false
    private(set) var folderStatus: [Folder: FolderScanState] = [:]
    private(set) var currentPath = ""
    private(set) var imageCount = 0
    private(set) var videoCount = 0

    @ObservationIgnored private let access = AccessManager()
    @ObservationIgnored private var bootstrapped = false
    @ObservationIgnored private var scanTask: Task<Void, Never>?

    /// Called once at launch: skip the Access screen if the stored bookmark is still valid.
    func bootstrap() {
        guard !bootstrapped else { return }
        bootstrapped = true
        if let url = access.restore() { adopt(root: url) }
    }

    func grantAccess(home: Bool) {
        if let url = access.requestAccess(home: home) { adopt(root: url) }
    }

    private func adopt(root url: URL) {
        root = url
        selectedFolder = .all
        libraryView = .all
        startScan()
    }

    // MARK: Scanning

    /// 0...1: finished folders plus half of the active one.
    var scanFraction: Double {
        let order = Scanner.folderOrder
        let done = order.filter { folderStatus[$0] == .done }.count
        let active = order.contains { folderStatus[$0] == .scanning } ? 0.5 : 0
        return min(1, (Double(done) + active) / Double(order.count))
    }

    func startScan() {
        guard let root else { return }
        scanTask?.cancel()
        items = []
        scope = []
        imageCount = 0
        videoCount = 0
        currentPath = ""
        folderStatus = Dictionary(uniqueKeysWithValues: Scanner.folderOrder.map { ($0, FolderScanState.waiting) })
        isScanning = true
        phase = .scanning
        scanTask = Task { [weak self] in
            for await event in Scanner.stream(root: root) { self?.handle(event) }
            guard !Task.isCancelled else { return }
            self?.finishScan()
        }
    }

    /// Prototype behaviour: Stop Scan returns to the access screen.
    func stopScan() {
        scanTask?.cancel()
        isScanning = false
        items = []
        scope = []
        phase = .access
    }

    /// Open the library while the scan keeps running.
    func showFoundSoFar() { if phase == .scanning { phase = .library } }

    private func handle(_ event: ScanEvent) {
        switch event {
        case .folderStarted(let f): folderStatus[f] = .scanning
        case .folderDone(let f): folderStatus[f] = .done
        case .found(let batch, let path):
            items.append(contentsOf: batch)
            for i in batch { if i.isVideo { videoCount += 1 } else { imageCount += 1 } }
            if !path.isEmpty { currentPath = path }
            recomputeScope()
        }
    }

    private func finishScan() {
        isScanning = false
        currentPath = ""
        if phase == .scanning { phase = .library }
    }

    // MARK: Derived

    private func recomputeScope() {
        let inFolder = selectedFolder == .all ? items : items.filter { $0.folder == selectedFolder }
        scope = inFolder.sorted { $0.modified > $1.modified }
    }

    func count(in folder: Folder) -> Int {
        folder == .all ? items.count : items.filter { $0.folder == folder }.count
    }
}
