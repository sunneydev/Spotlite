#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")"

echo "→ Building release binary…"
swift build -c release

APP="Spotlite.app"
BIN="$(swift build -c release --show-bin-path)/Spotlite"

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS"
mkdir -p "$APP/Contents/Resources"

cp "$BIN" "$APP/Contents/MacOS/Spotlite"

cat > "$APP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key><string>Spotlite</string>
    <key>CFBundleDisplayName</key><string>Spotlite</string>
    <key>CFBundleIdentifier</key><string>local.spotlightlite</string>
    <key>CFBundleVersion</key><string>1.0</string>
    <key>CFBundleShortVersionString</key><string>1.0</string>
    <key>CFBundleExecutable</key><string>Spotlite</string>
    <key>CFBundlePackageType</key><string>APPL</string>
    <key>LSMinimumSystemVersion</key><string>13.0</string>
    <key>LSUIElement</key><true/>
    <key>NSHighResolutionCapable</key><true/>
    <key>NSSupportsAutomaticTermination</key><false/>
    <key>NSSupportsSuddenTermination</key><false/>
</dict>
</plist>
PLIST

echo "→ Bundle ready: $(pwd)/$APP"
echo "→ Launching…"
open "$APP"
