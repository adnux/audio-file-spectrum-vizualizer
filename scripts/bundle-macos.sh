#!/usr/bin/env bash
# bundle-macos.sh — build a macOS .app and DMG for spectrum-viz.
#
# Usage (run from project root):
#   ./scripts/bundle-macos.sh arm64    # Apple Silicon
#   ./scripts/bundle-macos.sh amd64    # Intel
#
# Requires: go, hdiutil (built into macOS)
# Output:   dist/spectrum-viz-darwin-<arch>-<VERSION>.dmg

set -euo pipefail

ARCH="${1:?Usage: bundle-macos.sh <arm64|amd64>}"
APP="spectrum-viz"
BUNDLE_NAME="${APP}.app"
VERSION="${VERSION:-$(date +%Y%m%d)}"
DIST="dist"
STAGING="${DIST}/_macos-staging-${ARCH}"

mkdir -p "$DIST"

echo "── macOS .app  (${ARCH}) ──"

# ── 1. Compile the single binary (ffmpeg embedded) ───────────────────────────
echo "  → compiling darwin/${ARCH}"
mkdir -p "${STAGING}/${BUNDLE_NAME}/Contents/MacOS"
CGO_ENABLED=0 GOOS=darwin GOARCH="${ARCH}" \
  go build -ldflags="-s -w" \
  -o "${STAGING}/${BUNDLE_NAME}/Contents/MacOS/${APP}" .

# ── 2. Info.plist ─────────────────────────────────────────────────────────────
cat > "${STAGING}/${BUNDLE_NAME}/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN"
  "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleExecutable</key>       <string>${APP}</string>
  <key>CFBundleIdentifier</key>       <string>com.spectrumviz.app</string>
  <key>CFBundleName</key>             <string>Spectrum Viz</string>
  <key>CFBundleDisplayName</key>      <string>Spectrum Viz</string>
  <key>CFBundleVersion</key>          <string>${VERSION}</string>
  <key>CFBundleShortVersionString</key><string>${VERSION}</string>
  <key>CFBundlePackageType</key>      <string>APPL</string>
  <key>CFBundleSignature</key>        <string>????</string>
  <key>LSMinimumSystemVersion</key>   <string>10.15</string>
  <key>NSHighResolutionCapable</key>  <true/>
  <key>LSUIElement</key>              <false/>
</dict>
</plist>
PLIST

# ── 3. Optional icon ──────────────────────────────────────────────────────────
if [[ -f "assets/AppIcon.icns" ]]; then
  mkdir -p "${STAGING}/${BUNDLE_NAME}/Contents/Resources"
  cp "assets/AppIcon.icns" "${STAGING}/${BUNDLE_NAME}/Contents/Resources/"
  # Add icon key to plist
  /usr/libexec/PlistBuddy -c \
    "Add :CFBundleIconFile string AppIcon" \
    "${STAGING}/${BUNDLE_NAME}/Contents/Info.plist" 2>/dev/null || true
fi

# ── 4. PkgInfo helper ─────────────────────────────────────────────────────────
printf "APPL????" > "${STAGING}/${BUNDLE_NAME}/Contents/PkgInfo"

echo "  ✓ .app bundle created"

# ── 5. DMG via hdiutil ────────────────────────────────────────────────────────
DMG="${DIST}/${APP}-darwin-${ARCH}-${VERSION}.dmg"

echo "  → creating DMG"
# Use a writable temp image first, then convert to compressed read-only DMG.
TMP_DMG="${DIST}/_tmp-${ARCH}.dmg"

hdiutil create \
  -volname "Spectrum Viz" \
  -srcfolder "${STAGING}" \
  -ov -format UDRW \
  "${TMP_DMG}" >/dev/null

hdiutil convert "${TMP_DMG}" -format UDZO -imagekey zlib-level=9 -o "${DMG}" >/dev/null
rm -f "${TMP_DMG}"

rm -rf "${STAGING}"

echo "  ✓ ${DMG}"
ls -lh "${DMG}"
