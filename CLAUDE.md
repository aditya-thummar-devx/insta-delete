# InstaDelete (insta-delete) — project rules for Claude Code

Native macOS app (SwiftUI) that scans the user's Home folder for images and videos,
lets them review each one in a slideshow, mark items, and move approved items to the Trash.

Read `SPEC.md` before writing code. `design/Prototype.dc.html` is the source of truth
for layout, copy, colours and flow (it is HTML markup + a JS state machine — read it as a
reference; it does not run on its own). `design/screens/*.dc.html` are static stills of each screen.

## Hard safety rules (never break these)

1. **Never delete files.** Do not call `FileManager.removeItem`, `unlink`, `rm`, or any API that
   permanently deletes. The ONLY file mutation allowed is `FileManager.default.trashItem(at:resultingItemURL:)`.
2. Trashing happens only after BOTH: (a) the confirmation dialog, and (b) a successful
   `LAContext.evaluatePolicy(.deviceOwnerAuthentication, …)` (Touch ID or password).
3. Never trash anything inside a package/bundle (e.g. `Photos Library.photoslibrary`, `.app`).
   The scanner must skip package descendants.
4. A grep for `removeItem` in `Sources/` must return nothing. Add a unit test that asserts this.

## Tech choices

- Swift 5.10+, SwiftUI, macOS 14+ deployment target (needed for `.onKeyPress`).
- Project generated with **XcodeGen** (`project.yml`) so it builds from the CLI:
  `xcodegen generate && xcodebuild -scheme InstaDelete -destination 'platform=macOS' build`.
- App Sandbox ON with entitlements:
  `com.apple.security.files.user-selected.read-write` and
  `com.apple.security.files.bookmarks.app-scope`.
  Access is granted via `NSOpenPanel` (directory = Home, canChooseDirectories) and persisted
  as a security-scoped bookmark.
- Scanning: `FileManager.enumerator(at:includingPropertiesForKeys:options:)` with
  `[.skipsHiddenFiles, .skipsPackageDescendants]`, resource keys `contentTypeKey, fileSizeKey,
  contentModificationDateKey, isPackageKey`. Classify with `UTType` (`.image` / `.movie`, `.audiovisualContent`).
  Skip `~/Library`. Run off the main actor, publish progress incrementally.
- Thumbnails: `QLThumbnailGenerator` with an in-memory cache.
- Full image: `CGImageSource` downsampled to the viewer size (HEIC, JPEG, PNG…).
- Video: AVKit (`AVPlayerView` via `NSViewRepresentable`, or `VideoPlayer`).
- Auth: `LocalAuthentication` — `.deviceOwnerAuthentication` (Touch ID with password fallback).
- Persistence: marked items saved as JSON in Application Support (path + size + mtime) so the
  "To Be Binned" list survives relaunch.

## Working style

- Build in the milestones listed in `SPEC.md`; run `xcodebuild build` (and tests) after each one.
- Keep views small; state in an `@Observable` `LibraryStore` and `ReviewSession`.
- Match the prototype's copy and colours exactly unless SPEC.md says otherwise.

## App icon

A ready-made macOS icon set is at `Resources/Assets.xcassets/AppIcon.appiconset`
(16–512 pt at @1x/@2x, plus `Contents.json`). Add `Resources/Assets.xcassets` to the app
target in `project.yml` and set `ASSETCATALOG_COMPILER_APPICON_NAME: AppIcon`. Do not redraw it.
Source artwork: `design/AppIcon/AppIcon.svg` (1024 × 1024, macOS grid: 824 px body, 100 px margin).
