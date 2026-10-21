import XCTest
@testable import InstaDelete

final class ScannerTests: XCTestCase {
    private var root: URL!

    override func setUpWithError() throws {
        root = FileManager.default.temporaryDirectory.appendingPathComponent("scan-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        // Test cleanup of our own temp dir: move to Trash rather than hard-delete.
        try FileManager.default.trashItem(at: root, resultingItemURL: nil)
    }

    private func touch(_ path: String) throws {
        let url = root.appendingPathComponent(path)
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data([0]).write(to: url)
    }

    func testFindsMediaAndSkipsPackagesHiddenLibraryAndNonMedia() throws {
        try touch("Pictures/a.jpg")
        try touch("Pictures/Thing.app/Contents/b.jpg")   // inside package
        try touch("Library/c.jpg")                       // ~/Library
        try touch(".hidden/d.jpg")                       // hidden
        try touch("Movies/m.mov")
        try touch("Desktop/notes.txt")
        try touch("Music/song.mp3")                      // audio is not video
        try touch("loose.png")

        var items: [MediaItem] = []
        var started: [Folder] = []
        Scanner.scanSync(root: root, home: root, isCancelled: { false }) {
            switch $0 {
            case .found(let batch, _): items += batch
            case .folderStarted(let f): started.append(f)
            case .folderDone: break
            }
        }

        XCTAssertEqual(Set(items.map(\.name)), ["a.jpg", "m.mov", "loose.png"])
        XCTAssertEqual(items.first { $0.name == "a.jpg" }?.folder, .pictures)
        XCTAssertEqual(items.first { $0.name == "a.jpg" }?.displayFolder, "~/Pictures")
        XCTAssertEqual(items.first { $0.name == "m.mov" }?.kind, .video)
        XCTAssertEqual(items.first { $0.name == "loose.png" }?.folder, .other)
        XCTAssertEqual(started, Scanner.folderOrder)
    }

    func testCancellationStopsScan() throws {
        try touch("Pictures/a.jpg")
        var events = 0
        Scanner.scanSync(root: root, home: root, isCancelled: { true }) { _ in events += 1 }
        XCTAssertEqual(events, 0)
    }
}
