import XCTest
@testable import InstaDelete

final class SortFilterTests: XCTestCase {
    private func item(_ name: String, _ kind: MediaItem.Kind = .image, size: Int64 = 1, days: Int = 0,
                      folder: Folder = .pictures, type: String = "JPEG") -> MediaItem {
        MediaItem(id: URL(fileURLWithPath: "/h/\(folder.rawValue)/\(name)"), name: name, kind: kind,
                  typeDescription: type, size: size, modified: Date(timeIntervalSince1970: Double(days) * 86400),
                  folder: folder, displayFolder: "~/\(folder.rawValue)")
    }

    private lazy var sample = [
        item("IMG_10.jpg", size: 5, days: 3),
        item("IMG_2.jpg", size: 9, days: 1),
        item("clip.mov", .video, size: 100, days: 2, folder: .movies, type: "QuickTime movie"),
        item("shot.png", size: 1, days: 4, folder: .desktop, type: "PNG image"),
    ]

    func testNameSortIsNumericAwareAndReversible() {
        let asc = MediaQuery.sort(sample, key: .name, ascending: true).map(\.name)
        XCTAssertEqual(asc, ["clip.mov", "IMG_2.jpg", "IMG_10.jpg", "shot.png"])
        XCTAssertEqual(MediaQuery.sort(sample, key: .name, ascending: false).map(\.name), asc.reversed())
    }

    func testSizeAndDate() {
        XCTAssertEqual(MediaQuery.sort(sample, key: .size, ascending: false).first?.name, "clip.mov")
        XCTAssertEqual(MediaQuery.sort(sample, key: .modified, ascending: false).first?.name, "shot.png")
    }

    func testTypeSortPutsImagesBeforeVideosWhenAscending() {
        XCTAssertEqual(MediaQuery.sort(sample, key: .type, ascending: true).last?.name, "clip.mov")
        XCTAssertEqual(MediaQuery.sort(sample, key: .type, ascending: false).first?.name, "clip.mov")
    }

    func testFolderAndTypeFilter() {
        XCTAssertEqual(MediaQuery.apply(sample, folder: .movies, filter: .all, key: .name, ascending: true).count, 1)
        XCTAssertEqual(MediaQuery.apply(sample, folder: .all, filter: .videos, key: .name, ascending: true).count, 1)
        XCTAssertEqual(MediaQuery.apply(sample, folder: .all, filter: .images, key: .name, ascending: true).count, 3)
        XCTAssertTrue(MediaQuery.apply(sample, folder: .documents, filter: .all, key: .name, ascending: true).isEmpty)
    }

    func testDefaultDirections() {
        XCTAssertTrue(SortKey.name.defaultAscending)
        XCTAssertFalse(SortKey.size.defaultAscending)
        XCTAssertFalse(SortKey.modified.defaultAscending)
        XCTAssertTrue(SortKey.type.defaultAscending)
    }
}
