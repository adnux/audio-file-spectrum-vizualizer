#!/usr/bin/env bash
# download-ffmpeg.sh — download static ffmpeg/ffprobe builds into internal/assets/bins/
#
# Usage (run from project root):
#   ./scripts/download-ffmpeg.sh           # download for all platforms
#   ./scripts/download-ffmpeg.sh darwin    # macOS arm64 + amd64
#   ./scripts/download-ffmpeg.sh windows   # Windows amd64
#   ./scripts/download-ffmpeg.sh linux     # Linux amd64 + arm64
#
# Requires: curl, unzip, tar

set -euo pipefail

BINS="internal/assets/bins"
mkdir -p "$BINS"

# ── sources (same as package.sh) ─────────────────────────────────────────────
BTBN_BASE="https://github.com/BtbN/FFmpeg-Builds/releases/download/latest"
FFMPEG_LINUX_AMD64="${BTBN_BASE}/ffmpeg-master-latest-linux64-gpl.tar.xz"
FFMPEG_LINUX_ARM64="${BTBN_BASE}/ffmpeg-master-latest-linuxarm64-gpl.tar.xz"
FFMPEG_WIN64="${BTBN_BASE}/ffmpeg-master-latest-win64-gpl.zip"

EVERMEET_BASE="https://evermeet.cx/ffmpeg"
FFMPEG_MAC_ZIP="${EVERMEET_BASE}/getrelease/ffmpeg/zip"
FFPROBE_MAC_ZIP="${EVERMEET_BASE}/getrelease/ffprobe/zip"

# ── helpers ───────────────────────────────────────────────────────────────────
need() { command -v "$1" &>/dev/null || { echo "ERROR: '$1' not found in PATH"; exit 1; }; }
need curl; need unzip; need tar

dl() { echo "  → $(basename "$2")"; curl -fsSL --retry 3 -o "$1" "$2"; }

# ── macOS ─────────────────────────────────────────────────────────────────────
download_darwin() {
  for arch in arm64 amd64; do
    if [[ -f "${BINS}/ffmpeg-darwin-${arch}" && -f "${BINS}/ffprobe-darwin-${arch}" ]]; then
      echo "  ✓ darwin-${arch} already present, skipping"
      continue
    fi
    echo "── macOS ${arch} ──"
    local tmp; tmp=$(mktemp -d)
    dl "${tmp}/ffmpeg.zip"  "$FFMPEG_MAC_ZIP"
    dl "${tmp}/ffprobe.zip" "$FFPROBE_MAC_ZIP"
    unzip -qo "${tmp}/ffmpeg.zip"  ffmpeg  -d "${tmp}/"
    unzip -qo "${tmp}/ffprobe.zip" ffprobe -d "${tmp}/"
    cp "${tmp}/ffmpeg"  "${BINS}/ffmpeg-darwin-${arch}"
    cp "${tmp}/ffprobe" "${BINS}/ffprobe-darwin-${arch}"
    chmod +x "${BINS}/ffmpeg-darwin-${arch}" "${BINS}/ffprobe-darwin-${arch}"
    rm -rf "${tmp}"
    echo "  ✓ darwin-${arch}"
  done
}

# ── Windows ───────────────────────────────────────────────────────────────────
download_windows() {
  if [[ -f "${BINS}/ffmpeg-windows-amd64.exe" && -f "${BINS}/ffprobe-windows-amd64.exe" ]]; then
    echo "  ✓ windows-amd64 already present, skipping"
    return
  fi
  echo "── Windows amd64 ──"
  local tmp; tmp=$(mktemp -d)
  dl "${tmp}/ffmpeg.zip" "$FFMPEG_WIN64"
  unzip -qo "${tmp}/ffmpeg.zip" "*/bin/ffmpeg.exe" "*/bin/ffprobe.exe" -d "${tmp}/ex/"
  find "${tmp}/ex" -name "ffmpeg.exe"  -exec cp {} "${BINS}/ffmpeg-windows-amd64.exe"  \;
  find "${tmp}/ex" -name "ffprobe.exe" -exec cp {} "${BINS}/ffprobe-windows-amd64.exe" \;
  rm -rf "${tmp}"
  echo "  ✓ windows-amd64"
}

# ── Linux ─────────────────────────────────────────────────────────────────────
download_linux_amd64() {
  if [[ -f "${BINS}/ffmpeg-linux-amd64" && -f "${BINS}/ffprobe-linux-amd64" ]]; then
    echo "  ✓ linux-amd64 already present, skipping"
    return
  fi
  echo "── Linux amd64 ──"
  local tmp; tmp=$(mktemp -d)
  dl "${tmp}/ff.tar.xz" "$FFMPEG_LINUX_AMD64"
  tar -xf "${tmp}/ff.tar.xz" -C "${tmp}/" --wildcards "*/ffmpeg" "*/ffprobe" 2>/dev/null || \
    tar -xf "${tmp}/ff.tar.xz" -C "${tmp}/"
  find "${tmp}" -maxdepth 4 -name "ffmpeg"  ! -type d -exec cp {} "${BINS}/ffmpeg-linux-amd64"  \;
  find "${tmp}" -maxdepth 4 -name "ffprobe" ! -type d -exec cp {} "${BINS}/ffprobe-linux-amd64" \;
  chmod +x "${BINS}/ffmpeg-linux-amd64" "${BINS}/ffprobe-linux-amd64"
  rm -rf "${tmp}"
  echo "  ✓ linux-amd64"
}

download_linux_arm64() {
  if [[ -f "${BINS}/ffmpeg-linux-arm64" && -f "${BINS}/ffprobe-linux-arm64" ]]; then
    echo "  ✓ linux-arm64 already present, skipping"
    return
  fi
  echo "── Linux arm64 ──"
  local tmp; tmp=$(mktemp -d)
  dl "${tmp}/ff.tar.xz" "$FFMPEG_LINUX_ARM64"
  tar -xf "${tmp}/ff.tar.xz" -C "${tmp}/"
  find "${tmp}" -maxdepth 4 -name "ffmpeg"  ! -type d -exec cp {} "${BINS}/ffmpeg-linux-arm64"  \;
  find "${tmp}" -maxdepth 4 -name "ffprobe" ! -type d -exec cp {} "${BINS}/ffprobe-linux-arm64" \;
  chmod +x "${BINS}/ffmpeg-linux-arm64" "${BINS}/ffprobe-linux-arm64"
  rm -rf "${tmp}"
  echo "  ✓ linux-arm64"
}

# ── main ──────────────────────────────────────────────────────────────────────
TARGET="${1:-all}"
case "$TARGET" in
  darwin)  download_darwin ;;
  windows) download_windows ;;
  linux)   download_linux_amd64; download_linux_arm64 ;;
  all)     download_darwin; download_windows; download_linux_amd64; download_linux_arm64 ;;
  *)       echo "Unknown target: $TARGET (use: darwin | windows | linux | all)"; exit 1 ;;
esac

echo ""
echo "Done — binaries in ./${BINS}/"
ls -lh "${BINS}/"
