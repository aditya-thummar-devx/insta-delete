import XCTest
@testable import InstaDelete

@MainActor
final class MultiRootTests: XCTestCase {
    private func url(_ p: String) -> URL { URL(fileURLWithPath: p, isDirectory: true) }

    private func manager() -> AccessManager {
        let suite = "multiroot-\(UUID().uuidString)"
        let d = UserDefaults(suiteName: suite)!
        addTeardownBlock { d.removePersistentDomain(forName: suite) }
        return AccessManager(defaults: d)
    }

    func testCoversMatchesWholePathComponents() {
        XCTAssertTrue(AccessManager.covers(url("/a/Pics"), url("/a/Pics")))
        XCTAssertTrue(AccessManager.covers(url("/a/Pics"), url("/a/Pics/Trips/x.jpg")))
        XCTAssertFalse(AccessManager.covers(url("/a/Pics"), url("/a/Pics2")))
        XCTAssertFalse(AccessManager.covers(url("/a/Pics/Trips"), url("/a/Pics")))
    }

    func testAddAppendsSiblingRoots() {
        let m = manager()
        guard case .added(_, let r1) = m.add(url("/a/Pics")),
              case .added(_, let r2) = m.add(url("/a/Pics2")) else { return XCTFail("expected .added") }
        XCTAssertTrue(r1.isEmpty && r2.isEmpty)
        XCTAssertEqual(m.roots.map(\.path), ["/a/Pics", "/a/Pics2"])
    }

    func testAddInsideExistingRootIsRefused() {
        let m = manager()
        _ = m.add(url("/a/Pics"))
        guard case .alreadyCovered(let parent) = m.add(url("/a/Pics/Trips")) else { return XCTFail("expected .alreadyCovered") }
        XCTAssertEqual(parent.path, "/a/Pics")
        XCTAssertEqual(m.roots.count, 1)
    }

    func testAddingParentReplacesChildRoots() {
        let m = manager()
        _ = m.add(url("/a/Pics"))
        _ = m.add(url("/a/Movies"))
        guard case .added(_, let replaced) = m.add(url("/a")) else { return XCTFail("expected .added") }
        XCTAssertEqual(Set(replaced.map(\.path)), ["/a/Pics", "/a/Movies"])
        XCTAssertEqual(m.roots.map(\.path), ["/a"])
    }

    func testRemoveRoot() {
        let m = manager()
        _ = m.add(url("/a/Pics"))
        _ = m.add(url("/a/Movies"))
        m.removeRoot(url("/a/Pics"))
        XCTAssertEqual(m.roots.map(\.path), ["/a/Movies"])
    }

    func testRestoreConsumesLegacySingleBookmarkKey() {
        let suite = "multiroot-legacy-\(UUID().uuidString)"
        let d = UserDefaults(suiteName: suite)!
        defer { d.removePersistentDomain(forName: suite) }
        d.set(Data([1, 2, 3]), forKey: "rootFolderBookmark")  // not a real bookmark: must be dropped, not crash
        XCTAssertTrue(AccessManager(defaults: d).restore().isEmpty)
        XCTAssertNil(d.data(forKey: "rootFolderBookmark"))
    }
}
