#!/usr/bin/env bash
# bundle-linux.sh — build a Linux AppImage for spectrum-viz.
#
# Usage (run from project root, on a Linux host or CI runner):
#   ARCH=amd64 ./scripts/bundle-linux.sh
#   ARCH=arm64 ./scripts/bundle-linux.sh
#
# Requires: go, curl, file (standard on Linux)
# The appimagetool binary is downloaded automatically if not in PATH.
# Output:   dist/spectrum-viz-linux-<arch>-<VERSION>.AppImage

set -euo pipefail

ARCH="${ARCH:-amd64}"
APP="spectrum-viz"
VERSION="${VERSION:-$(date +%Y%m%d)}"
DIST="dist"
APPDIR="${DIST}/_appdir-${ARCH}"

mkdir -p "$DIST"

echo "── Linux AppImage (${ARCH}) ──"

# ── 1. Map ARCH to Go / AppImage naming ───────────────────────────────────────
case "$ARCH" in
  amd64) GOARCH="amd64"; APPTOOL_ARCH="x86_64" ;;
  arm64) GOARCH="arm64"; APPTOOL_ARCH="aarch64" ;;
  *) echo "Unsupported ARCH: $ARCH (use amd64 or arm64)"; exit 1 ;;
esac

# ── 2. Compile the single binary ──────────────────────────────────────────────
echo "  → compiling linux/${GOARCH}"
mkdir -p "${APPDIR}/usr/bin"
CGO_ENABLED=0 GOOS=linux GOARCH="${GOARCH}" \
  go build -ldflags="-s -w" \
  -o "${APPDIR}/usr/bin/${APP}" .

# ── 3. AppDir structure ───────────────────────────────────────────────────────
# AppRun — launches the binary
cat > "${APPDIR}/AppRun" <<'APPRUN'
#!/bin/sh
SELF="$(readlink -f "$0")"
HERE="${SELF%/*}"
exec "${HERE}/usr/bin/spectrum-viz" "$@"
APPRUN
chmod +x "${APPDIR}/AppRun"

# .desktop entry
cat > "${APPDIR}/${APP}.desktop" <<DESKTOP
[Desktop Entry]
Name=Spectrum Viz
Exec=spectrum-viz
Icon=spectrum-viz
Type=Application
Categories=AudioVideo;Audio;
DESKTOP

# Icon: use a minimal 256×256 PNG placeholder if none present.
if [[ -f "assets/spectrum-viz.png" ]]; then
  cp "assets/spectrum-viz.png" "${APPDIR}/spectrum-viz.png"
else
  # Create a minimal valid 1×1 transparent PNG as a bare-minimum placeholder.
  # Encoded as base64 inline to keep the script self-contained.
  printf '%s' \
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAAC0lEQVQI12NgAAIABQ' \
    'AABjkB6QAAAABJRU5ErkJggg==' | base64 -d > "${APPDIR}/spectrum-viz.png"
fi

echo "  ✓ AppDir ready"

# ── 4. Download appimagetool if needed ────────────────────────────────────────
TOOL_BIN="${DIST}/appimagetool-${APPTOOL_ARCH}.AppImage"
if ! command -v appimagetool &>/dev/null; then
  if [[ ! -f "$TOOL_BIN" ]]; then
    echo "  → downloading appimagetool"
    TOOL_URL="https://github.com/AppImage/AppImageKit/releases/download/continuous/appimagetool-${APPTOOL_ARCH}.AppImage"
    curl -fsSL --retry 3 -o "$TOOL_BIN" "$TOOL_URL"
    chmod +x "$TOOL_BIN"
  fi
  APPIMAGETOOL="$TOOL_BIN"
else
  APPIMAGETOOL="appimagetool"
fi

# ── 5. Build AppImage ─────────────────────────────────────────────────────────
OUTPUT="${DIST}/${APP}-linux-${ARCH}-${VERSION}.AppImage"
echo "  → running appimagetool"
ARCH="${APPTOOL_ARCH}" "$APPIMAGETOOL" "${APPDIR}" "${OUTPUT}" 2>&1 | sed 's/^/    /'

rm -rf "${APPDIR}"

echo "  ✓ ${OUTPUT}"
ls -lh "${OUTPUT}"
