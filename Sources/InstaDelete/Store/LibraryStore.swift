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
    var typeFilter: TypeFilter = .all { didSet { recomputeScope() } }
    private(set) var sortKey: SortKey = .modified
    var sortAscending = SortKey.modified.defaultAscending { didSet { recomputeScope() } }
    private(set) var items: [MediaItem] = []
    /// Items in the current folder (+ filter/sort from M4). Grid and review queue both read this.
    private(set) var scope: [MediaItem] = []
    private(set) var root: URL?
    /// Items per sidebar folder, and per type within the selected folder (for the segmented control).
    private(set) var folderCounts: [Folder: Int] = [:]
    private(set) var typeCounts: [TypeFilter: Int] = [:]

    // Marks ("To Be Binned")
    private(set) var markedIDs: Set<URL> = []
    /// Marked items that exist in the current scan, in scope order of `items`.
    private(set) var markedItems: [MediaItem] = []
    var markedBytes: Int64 { markedItems.reduce(0) { $0 + $1.size } }

    // Review
    private(set) var review: ReviewSession?

    // Scan state
    private(set) var isScanning = false
    private(set) var folderStatus: [Folder: FolderScanState] = [:]
    private(set) var currentPath = ""
    private(set) var imageCount = 0
    private(set) var videoCount = 0

    @ObservationIgnored private let access = AccessManager()
    @ObservationIgnored private let marks: MarkedStore
    @ObservationIgnored private var bootstrapped = false
    @ObservationIgnored private var scanTask: Task<Void, Never>?
    @ObservationIgnored private var lastRecompute = Date.distantPast

    init(marks: MarkedStore = MarkedStore()) {
        self.marks = marks
    }

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
        recomputeScope()
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
        recomputeScope()
        phase = .access
    }

    /// Open the library while the scan keeps running.
    func showFoundSoFar() { if phase == .scanning { phase = .library } }

    private func handle(_ event: ScanEvent) {
        switch event {
        case .folderStarted(let f): folderStatus[f] = .scanning
        case .folderDone(let f): folderStatus[f] = .done; recomputeScope()
        case .found(let batch, let path):
            items.append(contentsOf: batch)
            for i in batch { if i.isVideo { videoCount += 1 } else { imageCount += 1 } }
            if !path.isEmpty { currentPath = path }
            // Throttle: re-sorting a large library per batch is wasteful while scanning.
            if Date().timeIntervalSince(lastRecompute) > 0.4 { recomputeScope() }
        }
    }

    private func finishScan() {
        isScanning = false
        currentPath = ""
        marks.reconcile(with: items)
        recomputeScope()
        if phase == .scanning { phase = .library }
    }

    // MARK: Marks

    func isMarked(_ item: MediaItem) -> Bool { markedIDs.contains(item.id) }

    func toggleMark(_ item: MediaItem) {
        if isMarked(item) { marks.remove(item.id) } else { marks.add(item) }
        refreshMarked()
    }

    func unmark(_ item: MediaItem) {
        marks.remove(item.id)
        refreshMarked()
    }

    func unmarkAll() {
        marks.removeAll()
        refreshMarked()
    }

    private func refreshMarked() {
        markedItems = items.filter { marks.contains($0.id) }
        markedIDs = Set(markedItems.map(\.id))
    }

    // MARK: Review

    var scopeLabel: String {
        let typeWord = switch typeFilter { case .all: "All media"; case .images: "Images"; case .videos: "Videos" }
        let place = selectedFolder == .all ? "" : " in \(selectedFolder.rawValue)"
        return "\(typeWord)\(place) · \(sortKey.rawValue) \(sortAscending ? "↑" : "↓")"
    }

    func startReview(at index: Int = 0) {
        guard !scope.isEmpty else { return }
        review = ReviewSession(queue: scope, index: index, scopeLabel: scopeLabel)
        phase = .review
    }

    func exitReview() {
        review = nil
        libraryView = .all
        phase = .library
    }

    func finishReview() { phase = .complete }

    func openBin() {
        libraryView = .bin
        review = nil
        phase = .library
    }

    // MARK: Sort / filter

    /// Picking a new key resets direction to that key's default (as in the prototype).
    func setSort(_ key: SortKey) {
        sortKey = key
        sortAscending = key.defaultAscending  // didSet recomputes
    }

    // MARK: Derived

    private func recomputeScope() {
        lastRecompute = Date()
        var counts: [Folder: Int] = [.all: items.count]
        for i in items { counts[i.folder, default: 0] += 1 }
        folderCounts = counts

        let inFolder = selectedFolder == .all ? items : items.filter { $0.folder == selectedFolder }
        let videos = inFolder.reduce(0) { $0 + ($1.isVideo ? 1 : 0) }
        typeCounts = [.all: inFolder.count, .images: inFolder.count - videos, .videos: videos]

        scope = MediaQuery.sort(inFolder.filter(typeFilter.matches), key: sortKey, ascending: sortAscending)
        refreshMarked()
    }

    func count(in folder: Folder) -> Int { folderCounts[folder] ?? 0 }
}
