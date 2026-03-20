# Audio Spectrum Visualizer

Drop in an audio file, get an interactive frequency spectrum chart instantly.  
No installation, no dependencies — just a single file that runs everywhere.

## Download

Grab the latest release for your platform from the [Releases](../../releases/latest) page:

| Platform | File |
|----------|------|
| macOS (Apple Silicon) | `spectrum-viz-darwin-arm64-*.dmg` |
| macOS (Intel) | `spectrum-viz-darwin-amd64-*.dmg` |
| Windows | `spectrum-viz-windows-amd64-*.zip` → run `spectrum-viz.exe` |
| Linux (x64) | `spectrum-viz-linux-amd64-*.AppImage` |
| Linux (ARM64) | `spectrum-viz-linux-arm64-*.AppImage` |

## Getting started

### macOS
1. Open the `.dmg`, drag **Spectrum Viz** to your Applications folder
2. Double-click the app — your browser opens automatically
3. If macOS shows *"developer cannot be verified"*, right-click the app → **Open** to bypass Gatekeeper on first launch

### Windows
1. Unzip the downloaded archive
2. Double-click `spectrum-viz.exe`
3. If Windows SmartScreen warns you, click **More info → Run anyway**

### Linux
1. Make the AppImage executable and run it:
   ```bash
   chmod +x spectrum-viz-linux-*.AppImage
   ./spectrum-viz-linux-*.AppImage
   ```
2. Your browser opens automatically at `http://localhost:8080`

> All editions are **self-contained** — ffmpeg is bundled inside the binary. No extra software needed.

## Usage

1. Drag and drop one or more audio files onto the drop zone, or click **Browse Files**
2. Click **Analyze**
3. Explore the interactive frequency spectrum chart — zoom, pan, hover for exact values

Supports MP3, FLAC, WAV, OGG, AAC, M4A, OPUS, and any other format ffmpeg can decode.

---

## Building from source

Requirements: Go 1.22+

```bash
git clone <repo>
cd audio-file-spectrum-vizualizer

# Download ffmpeg binaries for your platform (one-time setup)
make prepare

# Build and run
make run
```

### Creating release packages

```bash
# Single binaries (cross-compiled ZIPs for all platforms)
make dist

# Native packages
make bundle-darwin      # .app + DMG  (run on macOS)
make bundle-linux       # AppImage    (run on Linux)
```

All output goes to `dist/`. A GitHub Actions workflow ([.github/workflows/release.yml](.github/workflows/release.yml)) builds and publishes all packages automatically when a `v*` tag is pushed:

```bash
git tag v1.0.0
git push origin v1.0.0
```
