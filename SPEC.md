# InstaDelete — product spec

Reference: `design/Prototype.dc.html` (all screens + behaviour in one file; see its
`renderVals()` for the exact state machine). Window size in the design: 1280 × 800.

## Flow

Access → Scanning → Library (gallery) → Slideshow review → Review complete →
To Be Binned list → Confirm dialog → Touch ID / password → Moved to Trash (toast with Undo).

## Screens

### 1. Grant access
- App icon, title "Find the photos and videos you don’t need anymore", 3 promise rows
  (read access / never deletes / you approve every move twice).
- Primary: **Grant Access to Home Folder…** → `NSOpenPanel` preset to Home.
- Secondary: **Choose a Specific Folder Instead** → same panel, any folder.
- Skip this screen on later launches if the stored bookmark is still valid.

### 2. Scanning
- Separate live counters: images / videos. Progress bar + current path (monospace).
- Per-folder rows: Pictures, Movies, Desktop, Downloads, Documents, Other folders — Done / Scanning… / Waiting.
- **Stop Scan**, **Show What’s Found So Far** (opens library while scan continues).

### 3. Library (home)
- Sidebar: All Media, Pictures, Movies, Desktop, Downloads, Documents (with counts);
  "Review › To Be Binned" with red count badge; safety note "InstaDelete never deletes…".
- Toolbar: title + summary ("24 images · 8 videos"), Rescan, **To Be Binned (n)**,
  **Start Slideshow Review** (primary).
- Filter segmented control: **All / Images / Videos** with counts.
- Sort menu: **Name, Size, Date Modified, Type** + order (A→Z/Z→A, Smallest/Largest first,
  Oldest/Newest first, Images/Videos first). Default: Date Modified, newest first.
- 6-column square grid. Video tiles: "VIDEO" tag + duration. Marked tiles: red 3px ring,
  white 50% veil, red trash badge top-right. Click a tile → review starting at that item.
- The review uses the current folder + filter + sort as its queue.

### 4. Slideshow review (dark)
- Top bar: Exit, scope chip (e.g. "Videos · Size ↓"), "12 of 32" + progress bar,
  "n to be binned" button (opens list).
- Centre: 16:9 viewer with ‹ › buttons. Videos: big play button, control bar
  (play/pause, current time, scrubber, duration, mute).
- Right panel (300px): name, folder, Kind, Size, Modified, Dimensions/Resolution, Duration (video);
  **Mark to Bin ⌫** (toggles to solid red **Unmark**), **Keep & Next →**
  (becomes **Finish Review** on last item), **← Previous**.
- Marked state: red 4px ring, dark-red overlay, trash icon, "Marked to be binned".
- Filmstrip of ±5 neighbours, same marked/video badges.
- Keys: ← / → navigate, Delete/Backspace toggles mark, Space play/pause video,
  Esc exits. Moving to another item stops the video.

### 5. Review complete
- "You’ve reviewed all N items", To be binned (count + size) vs Kept.
- **Back to Gallery**, **Check To Be Binned (n)**.

### 6. To Be Binned list
- Same grid style, only marked items; each has **Unmark**; caption name + "~/folder · size".
- Info banner: "InstaDelete never deletes files. These will move to the Bin in Finder…".
- **Review Again**, **Unmark All**, **Move All to Bin…** (red; disabled when empty).

### 7. Confirm dialog
- "Move 3 images · 2 videos to the Bin?" + total size + reassurance copy.
- **Cancel** / **Move to Bin**.

### 8. Authentication
- Call `LAContext().evaluatePolicy(.deviceOwnerAuthentication,
  localizedReason: "move N items to the Bin")`. The system shows Touch ID or password.
  (The prototype's fake dialog is only a stand-in for the system prompt — do not build a custom one.)
- Failure/cancel → return to the list, nothing moved.

### 9. Moved
- For each item: `trashItem(at:resultingItemURL:)`; record the resulting URL.
- Toast: "3 images · 2 videos moved to the Bin", size, **Undo** (moves each back from its
  resulting Trash URL to the original path), dismiss.
- Items that fail (permission, missing file) stay marked; show a short error summary.

## Data model

```swift
struct MediaItem: Identifiable, Hashable {
  let id: URL            // file URL
  let name: String
  let kind: Kind         // .image / .video
  let typeDescription: String   // "HEIC", "QuickTime Movie"…
  let size: Int64
  let modified: Date
  var duration: Double?  // videos, loaded lazily via AVURLAsset
  var pixelSize: CGSize? // loaded lazily
}
```
Marked set: `Set<URL>` persisted. Library store exposes filtered + sorted arrays.

## Design tokens (from the prototype)

| Token | Value |
|---|---|
| Accent / primary button | #0062CC (white text) |
| Destructive | #C4161C (buttons), #D70015 (marked ring/badge), #FF453A (ring on dark) |
| Text / secondary | #1D1D1F / #6E6E73 |
| Sidebar bg / border | #F2F2F4 / #E2E2E6 |
| Selected sidebar row | #DCDCE2 |
| Review bg / panel / filmstrip | #111113 / #18181B / #0B0B0D |
| Success | #4ADE80 on #13351E |
| Font | System (SF Pro) |
| Radii | buttons 7–10px, tiles 6px, dialogs 14px |

Prefer native SwiftUI controls (`NavigationSplitView`, `Picker(.segmented)`, `Menu`,
`.alert`/`.confirmationDialog`) styled to match, rather than pixel-copying the HTML.

## Milestones

1. XcodeGen project, sandbox entitlements, app shell with sidebar + empty states.
2. Access screen + NSOpenPanel + bookmark persistence.
3. Async scanner with progress screen; library grid with thumbnails.
4. Filter + sort + folder sidebar.
5. Slideshow review (images), marking, keyboard, filmstrip, persistence of marks.
6. Video support in review (AVKit player, durations).
7. To Be Binned list, confirm, LocalAuthentication, trashItem, toast + Undo.
8. Polish: review-complete screen, errors, accessibility labels, tests (incl. no-`removeItem` test).
