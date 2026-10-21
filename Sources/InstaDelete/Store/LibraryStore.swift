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

    // Move to Bin
    var confirmingMove = false
    private(set) var isMoving = false
    /// Records of the most recent move, kept so the toast's Undo can reverse it.
    private(set) var lastMove: [TrashedRecord] = []
    var moveError: String?

    var toastTitle: String { "\(Format.mix(lastMove.map(\.item))) moved to the Bin" }
    var toastSubtitle: String {
        "\(Format.size(lastMove.reduce(0) { $0 + $1.item.size })) · Put them back any time from the Bin in Finder"
    }

    // Scan state
    private(set) var isScanning = false
    private(set) var folderStatus: [Folder: FolderScanState] = [:]
    private(set) var currentPath = ""
    private(set) var imageCount = 0
    private(set) var videoCount = 0

    @ObservationIgnored private let access = AccessManager()
    @ObservationIgnored private let marks: MarkedStore
    @ObservationIgnored private let moveFlow: MoveFlow
    @ObservationIgnored private var bootstrapped = false
    @ObservationIgnored private var scanTask: Task<Void, Never>?
    @ObservationIgnored private var lastRecompute = Date.distantPast

    init(marks: MarkedStore = MarkedStore(), moveFlow: MoveFlow = MoveFlow()) {
        self.marks = marks
        self.moveFlow = moveFlow
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
        lastMove = []
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

    // MARK: Move to Bin

    /// Step 1: show the confirmation sheet.
    func requestMove() {
        guard !markedItems.isEmpty, !isMoving else { return }
        confirmingMove = true
    }

    /// Step 2 (user pressed "Move to Bin"): device authentication, then trash. Nothing moves unless auth succeeds.
    func performMove() async {
        confirmingMove = false
        guard !isMoving else { return }
        isMoving = true
        defer { isMoving = false }
        switch await moveFlow.run(markedItems) {
        case .cancelled:
            break
        case .authFailed(let message):
            moveError = "Couldn’t verify it’s you (\(message)). Nothing was moved."
        case .done(let result):
            apply(result)
        }
    }

    private func apply(_ result: TrashResult) {
        let gone = Set(result.trashed.map(\.original))
        for url in gone { marks.remove(url) }
        items.removeAll { gone.contains($0.id) }
        recomputeScope()
        lastMove = result.trashed
        if !result.failed.isEmpty {
            moveError = failureSummary(result.failed, verb: "move") + " They’re still marked."
        }
        if result.failed.isEmpty && !result.trashed.isEmpty {
            selectedFolder = .all
            libraryView = .all
        }
    }

    func undoMove() {
        let records = lastMove
        lastMove = []
        let (restored, failed) = moveFlow.trash.restore(records)
        for r in restored {
            items.append(r.item)
            marks.add(r.item)
        }
        recomputeScope()
        if !failed.isEmpty { moveError = failureSummary(failed, verb: "put back") }
        libraryView = .bin
    }

    func dismissToast() { lastMove = [] }

    private func failureSummary(_ failures: [TrashFailure], verb: String) -> String {
        let first = failures[0]
        let head = "\(Format.plural(failures.count, "item")) couldn’t be \(verb == "move" ? "moved" : "put back")"
        return "\(head). \(first.item.name): \(first.message)"
    }

    // MARK: Review

    var scopeLabel: String {
        let typeWord = switch typeFilter { case .all: "All media"; case .images: "Images"; case .videos: "Videos" }
        let place = selectedFolder == .all ? "" : " in \(selectedFolder.rawValue)"
        return "\(typeWord)\(place) · \(sortKey.rawValue) \(sortAscending ? "↑" : "↓")"
    }

    func startReview(at index: Int = 0) {
        guard !scope.isEmpty else { return }
        lastMove = []
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
        lastMove = []
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
