import XCTest
@testable import InstaDelete

final class MarkedStoreTests: XCTestCase {
    private func item(_ path: String, size: Int64 = 10, mtime: Double = 1000) -> MediaItem {
        MediaItem(id: URL(fileURLWithPath: path), name: (path as NSString).lastPathComponent, kind: .image,
                  typeDescription: "JPEG", size: size, modified: Date(timeIntervalSince1970: mtime),
                  folder: .pictures, displayFolder: "~/Pictures")
    }

    func testPersistsAcrossInstances() throws {
        let file = FileManager.default.temporaryDirectory.appendingPathComponent("marked-\(UUID().uuidString).json")
        defer { try? FileManager.default.trashItem(at: file, resultingItemURL: nil) }

        let a = MarkedStore(fileURL: file)
        a.add(item("/h/Pictures/a.jpg"))
        a.add(item("/h/Pictures/b.jpg"))
        a.remove(URL(fileURLWithPath: "/h/Pictures/b.jpg"))

        let b = MarkedStore(fileURL: file)
        XCTAssertTrue(b.contains(URL(fileURLWithPath: "/h/Pictures/a.jpg")))
        XCTAssertFalse(b.contains(URL(fileURLWithPath: "/h/Pictures/b.jpg")))
    }

    func testReconcileDropsMissingAndChangedFiles() {
        let s = MarkedStore(fileURL: nil)
        s.add(item("/h/keep.jpg"))
        s.add(item("/h/gone.jpg"))
        s.add(item("/h/edited.jpg", size: 10))
        s.reconcile(with: [item("/h/keep.jpg"), item("/h/edited.jpg", size: 99)])
        XCTAssertEqual(Set(s.entries.keys), ["/h/keep.jpg"])
    }

    func testRemoveAll() {
        let s = MarkedStore(fileURL: nil)
        s.add(item("/h/a.jpg"))
        s.removeAll()
        XCTAssertTrue(s.entries.isEmpty)
    }
}
