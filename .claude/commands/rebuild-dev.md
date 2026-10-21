---
description: Step-by-step dev rebuild of InstaDelete - remove installed app, rebuild from the working tree, install to /Applications
allowed-tools: Bash, AskUserQuestion
---

Rebuild and reinstall InstaDelete for local dev. Run from the repo root. Ask each step with AskUserQuestion (Yes / No), in order, one at a time. Do not ask a later step before the earlier one is finished.

App facts: `/Applications/InstaDelete.app`, process name `InstaDelete`, bundle id `com.instadelete.app`, build output `build/DerivedData/Build/Products/<Debug|Release>/InstaDelete.app` (`build/` is gitignored). `InstaDelete.xcodeproj` is gitignored and generated from `project.yml`. The build is unsigned on purpose (`CODE_SIGNING_ALLOWED: NO`): never add DEVELOPMENT_TEAM, a signing identity or provisioning, and never pass signing overrides to xcodebuild. The app has no CFBundleShortVersionString / CFBundleVersion, so identify a build by its config and bundle mtime, not a version number.

App data is off limits: never touch `~/Library/Application Support/InstaDelete` or `~/Library/Containers/com.instadelete.app` (marked-items list, bookmarks). A reinstall must not reset them.

Quit helper (use in step 1 and 3 whenever the app is running, check with `pgrep -x InstaDelete`): `osascript -e 'quit app "InstaDelete"'`, wait up to 5s, re-check. Still running: ask the user before `pkill -x InstaDelete`. Never force-kill without asking.

Trash helper: `mv /Applications/InstaDelete.app ~/.Trash/InstaDelete-$(date +%Y%m%d-%H%M%S).app`. Never `rm -rf` the app (same never-permanently-delete rule as CLAUDE.md).

## Step 1 - Remove existing app?
Ask: "Remove the installed InstaDelete from /Applications?" Yes / No.
- No: skip to step 2.
- Yes: look only at `/Applications/InstaDelete.app`.
  - Not there: say so and continue to step 2.
  - There: show its install time (`stat -f '%Sm' /Applications/InstaDelete.app`), ask to confirm removal. Confirmed: quit it if running (quit helper), then move it to Trash (trash helper).

## Step 2 - Good to go with rebuild?
Ask: "Good to go with rebuild from the working tree as-is?" Yes / No.
- No: skip to step 3.
- Yes:
  1. Ask: "Build configuration?" Debug (recommended) / Release.
  2. Run `xcodegen generate`. Always: the xcodeproj is gitignored, so a fresh clone or a changed `project.yml` needs it.
  3. Build: `xcodebuild -project InstaDelete.xcodeproj -scheme InstaDelete -configuration <chosen> -destination 'platform=macOS' -derivedDataPath build/DerivedData build -quiet`.
  4. Build failed: quote the shortest decisive error line, stop here, skip step 3.

## Step 3 - Install now?
Ask: "Install the build now?" Yes / No.
- No: print "Install skipped. Latest build: <path>" (newest app, see below, or "none" if there is none) and stop.
- Yes:
  1. Pick the newest app: `ls -dt build/DerivedData/Build/Products/{Debug,Release}/InstaDelete.app 2>/dev/null | head -1`. This is the fresh build from step 2, or an older one if step 2 was skipped. None found: say "No build found, run rebuild first" and stop.
  2. If `/Applications/InstaDelete.app` still exists (step 1 was No or skipped): ask "Overwrite the installed app?" Yes / No. No: stop. Yes: quit it if running (quit helper), then trash it (trash helper).
  3. Install: `cp -R <picked app> /Applications/` then `open /Applications/InstaDelete.app`.
  4. Verify: print the config it was built from (Debug or Release, from the picked path) and the installed bundle mtime (`stat -f '%Sm' /Applications/InstaDelete.app`).

## Final message
Report what was removed, built (config) and installed (config, time). Then add one note:
- The build is unsigned, so no entitlements are embedded: this dev build runs unsandboxed, and the sandbox / security-scoped-bookmark path is not exercised by it.
