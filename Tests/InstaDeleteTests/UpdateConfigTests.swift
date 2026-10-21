import XCTest
@testable import InstaDelete

/// A wrong key or feed URL can't be fixed over the air: installed copies would reject every later update.
final class UpdateConfigTests: XCTestCase {
    func testSparkleKeysAreConfigured() throws {
        let info = try XCTUnwrap(Bundle(for: LibraryStore.self).infoDictionary)
        let feed = try XCTUnwrap(info["SUFeedURL"] as? String)
        XCTAssertTrue(feed.hasPrefix("https://github.com/aditya-thummar-devx/insta-delete/releases/"), feed)
        let key = try XCTUnwrap(info["SUPublicEDKey"] as? String)
        XCTAssertEqual(Data(base64Encoded: key)?.count, 32, "SUPublicEDKey must be a base64 Ed25519 public key")
        let build = try XCTUnwrap(info["CFBundleVersion"] as? String)
        XCTAssertNotNil(Int(build), "Sparkle compares CFBundleVersion, it must be a plain number")
    }
}
