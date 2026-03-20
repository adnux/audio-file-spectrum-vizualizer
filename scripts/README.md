# package.sh

Cross-compiles `spectrum-viz` for all supported platforms and bundles a static FFmpeg build into each release ZIP. The result is a self-contained package that users can download, unzip, and run with no additional dependencies.

## Requirements

| Tool | Purpose |
|------|---------|
| `go` | Cross-compiling the Go binary |
| `curl` | Downloading static FFmpeg builds |
| `unzip` | Extracting `.zip` archives (macOS/Windows FFmpeg) |
| `tar` | Extracting `.tar.xz` archives (Linux FFmpeg) |

All of these are available by default on macOS and most Linux distros.

## Usage

Run from the **project root** (not from inside `scripts/`):

```bash
./scripts/package.sh           # build all platforms
./scripts/package.sh darwin    # macOS only (arm64 + amd64)
./scripts/package.sh windows   # Windows only (amd64)
./scripts/package.sh linux     # Linux only (amd64 + arm64)
```

You can also use the Makefile shortcuts:

```bash
make dist            # all platforms
make dist-darwin
make dist-windows
make dist-linux
```

### Versioning

The version string is embedded in each ZIP filename as `YYYYMMDD` by default. Override it with the `VERSION` environment variable:

```bash
VERSION=1.0.0 ./scripts/package.sh
```

## Output

All packages are written to `dist/`:

```
dist/
  spectrum-viz-darwin-arm64-YYYYMMDD.zip
  spectrum-viz-darwin-amd64-YYYYMMDD.zip
  spectrum-viz-windows-amd64-YYYYMMDD.zip
  spectrum-viz-linux-amd64-YYYYMMDD.zip
  spectrum-viz-linux-arm64-YYYYMMDD.zip
```

Each ZIP contains:

```
spectrum-viz-<os>-<arch>/
  spectrum-viz          # (or spectrum-viz.exe on Windows)
  ffmpeg                # (or ffmpeg.exe on Windows)
  ffprobe               # (or ffprobe.exe on Windows)
  README.md
```

## What it does, step by step

### 1. Dependency check
Verifies that `go`, `curl`, `unzip`, and `tar` are all present in `PATH` before doing any work. Exits immediately with a clear error if any are missing.

### 2. Go cross-compilation
For each target, compiles the Go binary with:
- `CGO_ENABLED=0` — fully static binary, no C runtime dependency
- `-ldflags="-s -w"` — strips debug symbols to reduce binary size
- `GOOS` / `GOARCH` — set to the target platform/architecture

### 3. FFmpeg download
Static (no-install) FFmpeg builds are fetched from two trusted sources:

| Platform | Source |
|----------|--------|
| macOS (arm64 & amd64) | [evermeet.cx](https://evermeet.cx/ffmpeg) — universal macOS builds |
| Windows amd64 | [BtbN/FFmpeg-Builds](https://github.com/BtbN/FFmpeg-Builds) — GPL static Win64 |
| Linux amd64 | [BtbN/FFmpeg-Builds](https://github.com/BtbN/FFmpeg-Builds) — GPL static linux64 |
| Linux arm64 | [BtbN/FFmpeg-Builds](https://github.com/BtbN/FFmpeg-Builds) — GPL static linuxarm64 |

Both `ffmpeg` and `ffprobe` are downloaded. `ffmpeg` decodes audio to raw PCM; `ffprobe` extracts file metadata (duration, sample rate, codec, channels).

### 4. Extraction
- **macOS**: each binary comes as its own `.zip` — unzipped directly into the package folder.
- **Windows**: the BtbN ZIP contains a nested `bin/` directory — `ffmpeg.exe` and `ffprobe.exe` are located with `find` and copied out; the rest of the archive is discarded.
- **Linux**: the BtbN tarball (`.tar.xz`) is extracted; the `ffmpeg` and `ffprobe` binaries are located with `find`, moved to the package folder, and the leftover extracted directory is cleaned up.

### 5. ZIP assembly
The package folder (`dist/<app>-<os>-<arch>/`) is zipped into `dist/<app>-<os>-<arch>-<version>.zip`, then the staging folder is removed.

### 6. Runtime binary lookup
At runtime the application looks for `ffmpeg` and `ffprobe` **next to its own executable first**, before falling back to `PATH`. This means users only need to keep all three files in the same folder — no system-wide FFmpeg installation required.
