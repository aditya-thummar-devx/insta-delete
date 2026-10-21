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

    /// Writes real media bytes matching the extension, so the content sniffer accepts it.
    private func touch(_ path: String, _ data: Data? = nil) throws {
        let url = root.appendingPathComponent(path)
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        let ext = url.pathExtension.lowercased()
        let bytes = data ?? (["mov", "mp4"].contains(ext) ? Fixtures.mov : ["jpg", "png"].contains(ext) ? Fixtures.png : Data([0]))
        try bytes.write(to: url)
    }

    private func scan() -> [MediaItem] {
        var items: [MediaItem] = []
        Scanner.scanSync(root: root, home: root, isCancelled: { false }) {
            if case .found(let batch, _) = $0 { items += batch }
        }
        return items
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

    func testContentMustMatchExtension() throws {
        try touch("Documents/app/index.d.ts", Fixtures.typeScript)  // TypeScript, not MPEG-TS
        try touch("Documents/app/types.ts", Data("G".utf8 + Array(repeating: 0x20, count: 600)))  // starts with 0x47 once
        try touch("Movies/broadcast.ts", Fixtures.mpegTS)            // real transport stream
        try touch("Pictures/renamed.jpg", Data("not an image".utf8))
        try touch("Pictures/empty.png", Data())
        try touch("Movies/fake.mov", Data("hello world, plain text".utf8))
        try touch("Pictures/real.png")
        try touch("Movies/real.mp4")

        XCTAssertEqual(Set(scan().map(\.name)), ["broadcast.ts", "real.png", "real.mp4"])
        XCTAssertEqual(scan().first { $0.name == "broadcast.ts" }?.kind, .video)
    }

    func testVideoHeaderSignatures() {
        func bytes(_ head: [UInt8]) -> [UInt8] { head + Array(repeating: 0, count: 600) }
        XCTAssertTrue(ContentSniffer.isVideoHeader([UInt8](Fixtures.mov)))
        XCTAssertTrue(ContentSniffer.isVideoHeader([UInt8](Fixtures.mpegTS)))
        XCTAssertTrue(ContentSniffer.isVideoHeader(bytes([0x1A, 0x45, 0xDF, 0xA3])))                     // mkv/webm
        XCTAssertTrue(ContentSniffer.isVideoHeader(bytes(Array("RIFF\0\0\0\0AVI ".utf8))))              // avi
        XCTAssertTrue(ContentSniffer.isVideoHeader(bytes([0x00, 0x00, 0x01, 0xBA])))                     // mpg
        XCTAssertFalse(ContentSniffer.isVideoHeader([UInt8](Fixtures.typeScript)))
        XCTAssertFalse(ContentSniffer.isVideoHeader(bytes(Array("RIFF\0\0\0\0WAVE".utf8))))             // audio, not video
        XCTAssertFalse(ContentSniffer.isVideoHeader([0x47, 0x47, 0x47]))                                 // too short
    }

    func testCancellationStopsScan() throws {
        try touch("Pictures/a.jpg")
        var events = 0
        Scanner.scanSync(root: root, home: root, isCancelled: { true }) { _ in events += 1 }
        XCTAssertEqual(events, 0)
    }
}
