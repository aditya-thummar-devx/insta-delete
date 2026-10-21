import XCTest

/// CLAUDE.md hard rule 4: nothing in Sources/ may permanently delete files.
final class SafetyTests: XCTestCase {
    func testSourcesContainNoPermanentDeleteAPIs() throws {
        let sources = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()  // InstaDeleteTests
            .deletingLastPathComponent()  // Tests
            .deletingLastPathComponent()  // repo root
            .appendingPathComponent("Sources")
        let enumerator = try XCTUnwrap(FileManager.default.enumerator(at: sources, includingPropertiesForKeys: nil))
        let banned = ["removeItem", "unlink(", "rmdir("]
        var scanned = 0
        for case let url as URL in enumerator where url.pathExtension == "swift" {
            scanned += 1
            let text = try String(contentsOf: url, encoding: .utf8)
            for word in banned {
                XCTAssertFalse(text.contains(word), "\(url.lastPathComponent) contains banned API \(word)")
            }
        }
        XCTAssertGreaterThan(scanned, 0, "no sources found — test path is wrong")
    }
}
