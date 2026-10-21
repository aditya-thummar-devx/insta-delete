#!/usr/bin/env bash
# Build Release and package build/InstaDelete-<version>.dmg: app + Applications shortcut, app icon on the mounted volume.
#
#   scripts/make-dmg.sh                         # version from project.yml
#   VERSION=0.1.1 BUILD=57 scripts/make-dmg.sh  # what release.sh passes
#
# Unsigned on purpose (CLAUDE.md), so the first launch on another Mac needs "Open Anyway" in System Settings > Privacy & Security.
# Nothing is deleted: staging lives in a mktemp directory and the DMG is overwritten in place.
set -euo pipefail
cd "$(dirname "$0")/.."

# The xcodeproj is gitignored, so always generate it from project.yml.
xcodegen generate -q
xcodebuild -project InstaDelete.xcodeproj -scheme InstaDelete -configuration Release -destination 'platform=macOS' \
  -derivedDataPath build/DerivedData build -quiet \
  ${VERSION:+MARKETING_VERSION=$VERSION} ${BUILD:+CURRENT_PROJECT_VERSION=$BUILD}
APP=build/DerivedData/Build/Products/Release/InstaDelete.app
VER=$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" "$APP/Contents/Info.plist")
DMG=build/InstaDelete-$VER.dmg
TMP=$(mktemp -d)
SRC=$TMP/src
RW=$TMP/rw.dmg
ICONSET=$TMP/AppIcon.iconset

mkdir -p "$SRC" "$ICONSET"
# The catalog PNGs already use iconset names, so the volume icon is built from them (no separate .icns to keep).
cp Resources/Assets.xcassets/AppIcon.appiconset/*.png "$ICONSET"
iconutil -c icns "$ICONSET" -o "$SRC/.VolumeIcon.icns"
cp -R "$APP" "$SRC/"
ln -s /Applications "$SRC/Applications"

hdiutil create -quiet -volname InstaDelete -srcfolder "$SRC" -format UDRW "$RW"
MNT=$(hdiutil attach "$RW" -nobrowse | awk -F'\t' '/\/Volumes\// {print $NF}')
SetFile -a C "$MNT"   # custom-icon flag: Finder uses .VolumeIcon.icns
hdiutil detach -quiet "$MNT"
hdiutil convert -quiet "$RW" -format UDZO -ov -o "$DMG"
echo "$DMG"
