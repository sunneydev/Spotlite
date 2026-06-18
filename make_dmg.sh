#!/usr/bin/env bash
# Builds Spotlite.app and packages it into a drag-to-Applications DMG.
set -euo pipefail
cd "$(dirname "$0")"

APP="Spotlite.app"
DMG="Spotlite.dmg"
VOL="Spotlite"
BG="docs/dmg_bg.png"

echo "→ Building app…"
swift build -c release
BIN="$(swift build -c release --show-bin-path)/Spotlite"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN" "$APP/Contents/MacOS/Spotlite"
echo "→ Building icon…"
bash tools/make_icns.sh
cp AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"
cat > "$APP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key><string>Spotlite</string>
    <key>CFBundleDisplayName</key><string>Spotlite</string>
    <key>CFBundleIdentifier</key><string>local.spotlightlite</string>
    <key>CFBundleVersion</key><string>1.2</string>
    <key>CFBundleShortVersionString</key><string>1.2</string>
    <key>CFBundleExecutable</key><string>Spotlite</string>
    <key>CFBundleIconFile</key><string>AppIcon</string>
    <key>CFBundlePackageType</key><string>APPL</string>
    <key>LSMinimumSystemVersion</key><string>13.0</string>
    <key>LSUIElement</key><true/>
    <key>NSHighResolutionCapable</key><true/>
    <key>NSSupportsAutomaticTermination</key><false/>
    <key>NSSupportsSuddenTermination</key><false/>
</dict>
</plist>
PLIST

# Ad-hoc sign so macOS doesn't reject the unsigned arm64 bundle as "damaged".
echo "→ Code signing (ad-hoc)…"
codesign --force --deep --sign - "$APP"

echo "→ Rendering DMG background…"
swift tools/make_dmg_bg.swift "$BG"

echo "→ Staging DMG contents…"
STAGE="$(mktemp -d)"
cp -R "$APP" "$STAGE/"
ln -s /Applications "$STAGE/Applications"
mkdir -p "$STAGE/.background"
cp "$BG" "$STAGE/.background/bg.png"

echo "→ Creating writable DMG…"
rm -f "$DMG" rw.dmg
hdiutil create -srcfolder "$STAGE" -volname "$VOL" -fs HFS+ \
    -format UDRW -ov rw.dmg >/dev/null
DEV="$(hdiutil attach -readwrite -noverify -noautoopen rw.dmg | egrep '^/dev/' | head -1 | awk '{print $1}')"
sleep 1

echo "→ Arranging Finder window…"
osascript <<APPLESCRIPT
tell application "Finder"
    tell disk "$VOL"
        open
        set current view of container window to icon view
        set toolbar visible of container window to false
        set statusbar visible of container window to false
        set the bounds of container window to {200, 120, 800, 520}
        set vopts to the icon view options of container window
        set arrangement of vopts to not arranged
        set icon size of vopts to 96
        set background picture of vopts to file ".background:bg.png"
        set position of item "$APP" of container window to {150, 200}
        set position of item "Applications" of container window to {450, 200}
        update without registering applications
        delay 1
        close
    end tell
end tell
APPLESCRIPT

sync
hdiutil detach "$DEV" >/dev/null
echo "→ Converting to compressed DMG…"
hdiutil convert rw.dmg -format UDZO -imagekey zlib-level=9 -o "$DMG" >/dev/null
rm -f rw.dmg
rm -rf "$STAGE"
echo "→ Done: $(pwd)/$DMG"
