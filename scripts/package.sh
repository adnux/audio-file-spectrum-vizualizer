#!/usr/bin/env bash
# package.sh — cross-compile spectrum-viz and bundle ffmpeg for all platforms.
#
# Usage:
#   ./scripts/package.sh            # build all platforms
#   ./scripts/package.sh darwin     # build macOS only
#   ./scripts/package.sh windows    # build Windows only
#   ./scripts/package.sh linux      # build Linux only
#
# Requires: go, curl, unzip, tar (all standard on macOS/Linux)
# Output:   dist/spectrum-viz-<os>-<arch>.zip

set -euo pipefail

APP="spectrum-viz"
DIST="dist"
VERSION="${VERSION:-$(date +%Y%m%d)}"

# ── ffmpeg static build sources ──────────────────────────────────────────────
# BtbN builds: https://github.com/BtbN/FFmpeg-Builds
BTBN_BASE="https://github.com/BtbN/FFmpeg-Builds/releases/download/latest"
FFMPEG_LINUX_AMD64="${BTBN_BASE}/ffmpeg-master-latest-linux64-gpl.tar.xz"
FFMPEG_LINUX_ARM64="${BTBN_BASE}/ffmpeg-master-latest-linuxarm64-gpl.tar.xz"
FFMPEG_WIN64="${BTBN_BASE}/ffmpeg-master-latest-win64-gpl.zip"

# macOS static builds from evermeet.cx (arm64 & amd64 universal)
EVERMEET_BASE="https://evermeet.cx/ffmpeg"
FFMPEG_MAC_ZIP="${EVERMEET_BASE}/getrelease/ffmpeg/zip"
FFPROBE_MAC_ZIP="${EVERMEET_BASE}/getrelease/ffprobe/zip"

# ── helpers ──────────────────────────────────────────────────────────────────
need() { command -v "$1" &>/dev/null || { echo "ERROR: '$1' not found in PATH"; exit 1; }; }
need go; need curl; need unzip; need tar

mkdir -p "$DIST"

go_build() {
  local goos=$1 goarch=$2 out=$3
  echo "  → compiling ${goos}/${goarch}"
  CGO_ENABLED=0 GOOS="$goos" GOARCH="$goarch" go build -ldflags="-s -w" -o "$out" .
}

download() {
  local url=$1 dest=$2
  echo "  → downloading $(basename "$url")"
  curl -fsSL --retry 3 -o "$dest" "$url"
}

make_zip() {
  local zipfile=$1; shift
  # $@ = files/dirs to include (must be in same dir or absolute)
  local dir; dir=$(dirname "$1")
  local names=(); for f in "$@"; do names+=("$(basename "$f")"); done
  (cd "$dir" && zip -qr "$(pwd)/$zipfile" "${names[@]}")
  echo "  ✓ created $zipfile"
}

# ── macOS (arm64 — Apple Silicon) ────────────────────────────────────────────
build_darwin_arm64() {
  local pkg="${DIST}/${APP}-darwin-arm64"
  mkdir -p "$pkg"
  go_build darwin arm64 "${pkg}/${APP}"

  echo "  → downloading ffmpeg for macOS"
  download "$FFMPEG_MAC_ZIP"  "${pkg}/ffmpeg.zip"
  download "$FFPROBE_MAC_ZIP" "${pkg}/ffprobe.zip"
  (cd "$pkg" && unzip -qo ffmpeg.zip && unzip -qo ffprobe.zip)
  rm -f "${pkg}/ffmpeg.zip" "${pkg}/ffprobe.zip"
  chmod +x "${pkg}/ffmpeg" "${pkg}/ffprobe"

  cp README.md "${pkg}/" 2>/dev/null || true
  (cd "$DIST" && zip -qr "${APP}-darwin-arm64-${VERSION}.zip" "${APP}-darwin-arm64/")
  rm -rf "$pkg"
  echo "  ✓ dist/${APP}-darwin-arm64-${VERSION}.zip"
}

# ── macOS (amd64 — Intel) ─────────────────────────────────────────────────────
build_darwin_amd64() {
  local pkg="${DIST}/${APP}-darwin-amd64"
  mkdir -p "$pkg"
  go_build darwin amd64 "${pkg}/${APP}"

  echo "  → downloading ffmpeg for macOS"
  download "$FFMPEG_MAC_ZIP"  "${pkg}/ffmpeg.zip"
  download "$FFPROBE_MAC_ZIP" "${pkg}/ffprobe.zip"
  (cd "$pkg" && unzip -qo ffmpeg.zip && unzip -qo ffprobe.zip)
  rm -f "${pkg}/ffmpeg.zip" "${pkg}/ffprobe.zip"
  chmod +x "${pkg}/ffmpeg" "${pkg}/ffprobe"

  cp README.md "${pkg}/" 2>/dev/null || true
  (cd "$DIST" && zip -qr "${APP}-darwin-amd64-${VERSION}.zip" "${APP}-darwin-amd64/")
  rm -rf "$pkg"
  echo "  ✓ dist/${APP}-darwin-amd64-${VERSION}.zip"
}

# ── Windows (amd64) ───────────────────────────────────────────────────────────
build_windows_amd64() {
  local pkg="${DIST}/${APP}-windows-amd64"
  local tmp="${DIST}/_ffmpeg_win64.zip"
  mkdir -p "$pkg"
  go_build windows amd64 "${pkg}/${APP}.exe"

  download "$FFMPEG_WIN64" "$tmp"
  echo "  → extracting ffmpeg.exe + ffprobe.exe"
  # BtbN zip contains a single top-level folder; extract ffmpeg.exe & ffprobe.exe
  unzip -qo "$tmp" "*/bin/ffmpeg.exe" "*/bin/ffprobe.exe" -d "${DIST}/_ffwin_extract/"
  find "${DIST}/_ffwin_extract" -name "ffmpeg.exe"  -exec cp {} "${pkg}/ffmpeg.exe"  \;
  find "${DIST}/_ffwin_extract" -name "ffprobe.exe" -exec cp {} "${pkg}/ffprobe.exe" \;
  rm -rf "$tmp" "${DIST}/_ffwin_extract"

  cp README.md "${pkg}/" 2>/dev/null || true
  (cd "$DIST" && zip -qr "${APP}-windows-amd64-${VERSION}.zip" "${APP}-windows-amd64/")
  rm -rf "$pkg"
  echo "  ✓ dist/${APP}-windows-amd64-${VERSION}.zip"
}

# ── Linux (amd64) ─────────────────────────────────────────────────────────────
build_linux_amd64() {
  local pkg="${DIST}/${APP}-linux-amd64"
  local tmp="${DIST}/_ffmpeg_linux64.tar.xz"
  mkdir -p "$pkg"
  go_build linux amd64 "${pkg}/${APP}"

  download "$FFMPEG_LINUX_AMD64" "$tmp"
  echo "  → extracting ffmpeg + ffprobe"
  tar -xf "$tmp" -C "${DIST}/" --wildcards "*/ffmpeg" "*/ffprobe" 2>/dev/null || \
    tar -xf "$tmp" -C "${DIST}/"
  find "${DIST}" -maxdepth 3 -name "ffmpeg"  ! -path "*/${APP}-linux-amd64/*" -exec mv {} "${pkg}/ffmpeg"  \;
  find "${DIST}" -maxdepth 3 -name "ffprobe" ! -path "*/${APP}-linux-amd64/*" -exec mv {} "${pkg}/ffprobe" \;
  rm -f "$tmp"
  # Clean up any leftover extracted folder
  find "${DIST}" -maxdepth 1 -type d -name "ffmpeg-*" -exec rm -rf {} + 2>/dev/null || true
  chmod +x "${pkg}/ffmpeg" "${pkg}/ffprobe"

  cp README.md "${pkg}/" 2>/dev/null || true
  (cd "$DIST" && zip -qr "${APP}-linux-amd64-${VERSION}.zip" "${APP}-linux-amd64/")
  rm -rf "$pkg"
  echo "  ✓ dist/${APP}-linux-amd64-${VERSION}.zip"
}

# ── Linux (arm64) ─────────────────────────────────────────────────────────────
build_linux_arm64() {
  local pkg="${DIST}/${APP}-linux-arm64"
  local tmp="${DIST}/_ffmpeg_linuxarm64.tar.xz"
  mkdir -p "$pkg"
  go_build linux arm64 "${pkg}/${APP}"

  download "$FFMPEG_LINUX_ARM64" "$tmp"
  echo "  → extracting ffmpeg + ffprobe"
  tar -xf "$tmp" -C "${DIST}/"
  find "${DIST}" -maxdepth 3 -name "ffmpeg"  ! -path "*/${APP}-linux-arm64/*" -exec mv {} "${pkg}/ffmpeg"  \;
  find "${DIST}" -maxdepth 3 -name "ffprobe" ! -path "*/${APP}-linux-arm64/*" -exec mv {} "${pkg}/ffprobe" \;
  rm -f "$tmp"
  find "${DIST}" -maxdepth 1 -type d -name "ffmpeg-*" -exec rm -rf {} + 2>/dev/null || true
  chmod +x "${pkg}/ffmpeg" "${pkg}/ffprobe"

  cp README.md "${pkg}/" 2>/dev/null || true
  (cd "$DIST" && zip -qr "${APP}-linux-arm64-${VERSION}.zip" "${APP}-linux-arm64/")
  rm -rf "$pkg"
  echo "  ✓ dist/${APP}-linux-arm64-${VERSION}.zip"
}

# ── main ─────────────────────────────────────────────────────────────────────
TARGET="${1:-all}"

echo "Building Audio Spectrum Visualizer — version ${VERSION}"

case "$TARGET" in
  darwin)
    echo "── macOS ──"
    build_darwin_arm64
    build_darwin_amd64
    ;;
  windows)
    echo "── Windows ──"
    build_windows_amd64
    ;;
  linux)
    echo "── Linux ──"
    build_linux_amd64
    build_linux_arm64
    ;;
  all)
    echo "── macOS ──";   build_darwin_arm64; build_darwin_amd64
    echo "── Windows ──"; build_windows_amd64
    echo "── Linux ──";   build_linux_amd64; build_linux_arm64
    ;;
  *)
    echo "Unknown target: $TARGET (use: darwin | windows | linux | all)"
    exit 1
    ;;
esac

echo ""
echo "Done! Packages in ./${DIST}/"
ls -lh "${DIST}/"*.zip 2>/dev/null || true
