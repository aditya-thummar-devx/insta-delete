import XCTest
@testable import InstaDelete

private final class FakeTrasher: FileTrasher {
    var trashed: [URL] = []
    var moves: [(from: URL, to: URL)] = []
    var failOn: Set<String> = []

    func trash(at url: URL) throws -> URL? {
        if failOn.contains(url.lastPathComponent) { throw CocoaError(.fileWriteNoPermission) }
        trashed.append(url)
        return URL(fileURLWithPath: "/Trash/\(url.lastPathComponent)")
    }

    func move(from: URL, to: URL) throws { moves.append((from, to)) }
}

final class MoveFlowTests: XCTestCase {
    private var dir: URL!
    private var fake: FakeTrasher!

    override func setUpWithError() throws {
        dir = FileManager.default.temporaryDirectory.appendingPathComponent("move-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        fake = FakeTrasher()
    }

    override func tearDownWithError() throws {
        try FileManager.default.trashItem(at: dir, resultingItemURL: nil)
    }

    /// Writes a real file and returns the MediaItem the scanner would produce for it.
    private func makeItem(_ path: String) throws -> MediaItem {
        let url = dir.appendingPathComponent(path)
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Fixtures.png.write(to: url)
        return try XCTUnwrap(Scanner.classify(url, folder: .pictures, root: dir, home: dir, keys: Set(Scanner.resourceKeys)))
    }

    private func flow(auth: AuthOutcome) -> MoveFlow {
        MoveFlow(authenticate: { _ in auth }, trash: TrashService(trasher: fake))
    }

    func testCancelledAuthMovesNothing() async throws {
        let item = try makeItem("a.jpg")
        let outcome = await flow(auth: .cancelled).run([item])
        XCTAssertEqual(outcome, .cancelled)
        XCTAssertTrue(fake.trashed.isEmpty)
    }

    func testFailedAuthMovesNothing() async throws {
        let item = try makeItem("a.jpg")
        let outcome = await flow(auth: .failed("nope")).run([item])
        XCTAssertEqual(outcome, .authFailed("nope"))
        XCTAssertTrue(fake.trashed.isEmpty)
    }

    func testSuccessfulAuthTrashesAndRecordsResultingURL() async throws {
        let item = try makeItem("a.jpg")
        guard case .done(let result) = await flow(auth: .success).run([item]) else { return XCTFail("expected done") }
        XCTAssertEqual(result.trashed.map(\.original), [item.id])
        XCTAssertEqual(result.trashed.first?.resulting?.path, "/Trash/a.jpg")
        XCTAssertTrue(result.failed.isEmpty)
    }

    func testPerItemFailureLeavesOthersMoving() async throws {
        let ok = try makeItem("ok.jpg"), bad = try makeItem("bad.jpg")
        fake.failOn = ["bad.jpg"]
        guard case .done(let result) = await flow(auth: .success).run([bad, ok]) else { return XCTFail() }
        XCTAssertEqual(result.trashed.map(\.item.name), ["ok.jpg"])
        XCTAssertEqual(result.failed.map(\.item.name), ["bad.jpg"])
    }

    func testRefusesFilesInsidePackages() async throws {
        let item = try makeItem("Thing.app/Contents/inner.jpg")
        guard case .done(let result) = await flow(auth: .success).run([item]) else { return XCTFail() }
        XCTAssertTrue(fake.trashed.isEmpty)
        XCTAssertEqual(result.failed.count, 1)
    }

    func testRefusesFilesChangedSinceScan() async throws {
        let item = try makeItem("a.jpg")
        try (Fixtures.png + Data([0])).write(to: item.id)  // size differs from the scanned item
        guard case .done(let result) = await flow(auth: .success).run([item]) else { return XCTFail() }
        XCTAssertTrue(fake.trashed.isEmpty)
        XCTAssertEqual(result.failed.count, 1)
    }

    func testMissingFileIsReportedNotTrashed() async throws {
        let item = try makeItem("a.jpg")
        try FileManager.default.trashItem(at: item.id, resultingItemURL: nil)
        guard case .done(let result) = await flow(auth: .success).run([item]) else { return XCTFail() }
        XCTAssertTrue(fake.trashed.isEmpty)
        XCTAssertEqual(result.failed.count, 1)
    }

    func testUndoMovesBackFromResultingURL() throws {
        let item = try makeItem("a.jpg")
        let record = TrashedRecord(item: item, resulting: URL(fileURLWithPath: "/Trash/a.jpg"))
        try FileManager.default.trashItem(at: item.id, resultingItemURL: nil)  // simulate it being gone from the original spot
        let (restored, failed) = TrashService(trasher: fake).restore([record])
        XCTAssertEqual(restored.count, 1)
        XCTAssertTrue(failed.isEmpty)
        XCTAssertEqual(fake.moves.first?.from.path, "/Trash/a.jpg")
        XCTAssertEqual(fake.moves.first?.to, item.id)
    }

    func testUndoRefusesToOverwriteExistingFile() throws {
        let item = try makeItem("a.jpg")  // still exists at the original path
        let record = TrashedRecord(item: item, resulting: URL(fileURLWithPath: "/Trash/a.jpg"))
        let (restored, failed) = TrashService(trasher: fake).restore([record])
        XCTAssertTrue(restored.isEmpty)
        XCTAssertEqual(failed.count, 1)
        XCTAssertTrue(fake.moves.isEmpty)
    }
}
