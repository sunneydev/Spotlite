#!/usr/bin/env bash
# Renders the master icon and packs it into AppIcon.icns (repo root).
set -euo pipefail
cd "$(dirname "$0")/.."

MASTER="docs/icon.png"
swift tools/make_icon.swift "$MASTER"

SET="$(mktemp -d)/AppIcon.iconset"
mkdir -p "$SET"
for s in 16 32 128 256 512; do
    sips -z "$s"             "$MASTER" --out "$SET/icon_${s}x${s}.png"      >/dev/null
    sips -z "$((s*2))" "$((s*2))" "$MASTER" --out "$SET/icon_${s}x${s}@2x.png" >/dev/null
done
iconutil -c icns "$SET" -o AppIcon.icns
echo "→ wrote $(pwd)/AppIcon.icns"
