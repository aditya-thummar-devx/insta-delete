import XCTest
@testable import InstaDelete

@MainActor
final class ReviewSessionTests: XCTestCase {
    private func queue(_ n: Int) -> [MediaItem] {
        (0..<n).map { MediaItem(id: URL(fileURLWithPath: "/h/\($0).jpg"), name: "\($0).jpg", kind: .image, typeDescription: "JPEG",
                                size: 1, modified: .now, folder: .pictures, displayFolder: "~/Pictures") }
    }

    func testNavigationClampsAndAdvanceReportsEnd() {
        let s = ReviewSession(queue: queue(3), index: 99, scopeLabel: "")
        XCTAssertEqual(s.index, 2)
        XCTAssertTrue(s.isLast)
        XCTAssertFalse(s.advance())
        s.previous(); s.previous(); s.previous()
        XCTAssertEqual(s.index, 0)
        XCTAssertTrue(s.advance())
        XCTAssertEqual(s.index, 1)
    }

    func testEmptyQueueIsSafe() {
        let s = ReviewSession(queue: [], index: 0, scopeLabel: "")
        XCTAssertNil(s.current)
        s.go(to: 5)
        XCTAssertFalse(s.advance())
    }
}
