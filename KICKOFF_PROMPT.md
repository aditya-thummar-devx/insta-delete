Paste this as your first message to Claude Code (from inside the project folder):

---

Build the macOS app described in this folder.

1. Read CLAUDE.md, SPEC.md, and design/Prototype.dc.html (the full interactive design — its
   markup is the layout/copy reference and its renderVals() is the state machine). Skim
   design/screens/ for the static stills.
2. Propose a plan: file/folder structure, main types, and how you'll handle sandbox access,
   scanning, thumbnails, video playback, LocalAuthentication and trashItem. Wait for my OK.
3. Then implement milestone by milestone as listed in SPEC.md. After each milestone run
   `xcodegen generate && xcodebuild -scheme InstaDelete -destination 'platform=macOS' build`,
   fix any errors, summarise what's done, and commit.

The safety rules in CLAUDE.md are non-negotiable: never permanently delete anything — only
`trashItem` after confirmation + device authentication.
