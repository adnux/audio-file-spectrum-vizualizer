# Audio Spectrum Visualizer

Visualize the frequency spectrum of audio files in your browser.  
Powered by Go + FFmpeg + Plotly.js.

## Running

### macOS / Linux
```bash
./spectrum-viz
```
The app opens automatically in your default browser at `http://localhost:8080`.

### Windows
Double-click `spectrum-viz.exe`, or run it from a terminal.

> **Note:** `ffmpeg` and `ffprobe` must be in the same folder as the executable (included in the release ZIP).

## Usage
1. Drag and drop audio files onto the drop zone, or click **Browse Files**
2. Click **Analyze**
3. Explore the interactive frequency spectrum chart

Supports MP3, FLAC, WAV, OGG, AAC, M4A, OPUS, and any other format ffmpeg can decode.

## Building from source

Requirements: Go 1.21+, ffmpeg in PATH

```bash
git clone <repo>
cd audio-file-spectrum-vizualizer
make run
```

### Creating release packages
```bash
make dist            # all platforms
make dist-darwin     # macOS only
make dist-windows    # Windows only
make dist-linux      # Linux only
```

Packages are written to `dist/`.
