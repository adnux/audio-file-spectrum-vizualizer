// Package assets manages the extraction of embedded ffmpeg/ffprobe binaries
// to a versioned cache directory so the app runs as a single file.
package assets

import (
	"crypto/sha256"
	"fmt"
	"os"
	"path/filepath"
	"runtime"
)

// Extract writes the embedded ffmpeg and ffprobe binaries to a versioned
// sub-directory of the OS cache dir and returns their paths.
//
// On subsequent calls with the same binary contents the files already exist
// and are returned immediately without re-writing.
func Extract() (ffmpegPath, ffprobePath string, err error) {
	dir, err := cacheDir()
	if err != nil {
		return "", "", fmt.Errorf("assets: cache dir: %w", err)
	}

	ext := ""
	if runtime.GOOS == "windows" {
		ext = ".exe"
	}

	ffmpegDst := filepath.Join(dir, "ffmpeg"+ext)
	ffprobeDst := filepath.Join(dir, "ffprobe"+ext)

	if err := writeIfMissing(ffmpegDst, FFmpegBin); err != nil {
		return "", "", fmt.Errorf("assets: extract ffmpeg: %w", err)
	}
	if err := writeIfMissing(ffprobeDst, FFprobeBin); err != nil {
		return "", "", fmt.Errorf("assets: extract ffprobe: %w", err)
	}

	return ffmpegDst, ffprobeDst, nil
}

// cacheDir returns (and creates) the versioned cache directory:
//
//	<os-cache>/spectrum-viz/<hash>/
//
// The hash is derived from the ffmpeg binary bytes, so a new app build with
// updated ffmpeg gets a fresh directory automatically.
func cacheDir() (string, error) {
	base, err := os.UserCacheDir()
	if err != nil {
		// Fallback: use temp dir (always available).
		base = os.TempDir()
	}

	hash := fmt.Sprintf("%x", sha256.Sum256(FFmpegBin))[:16]
	dir := filepath.Join(base, "spectrum-viz", hash)

	if err := os.MkdirAll(dir, 0o700); err != nil {
		return "", err
	}
	return dir, nil
}

// writeIfMissing writes data to dst only when the file does not already exist.
func writeIfMissing(dst string, data []byte) error {
	if _, err := os.Stat(dst); err == nil {
		return nil // already there
	}
	if err := os.WriteFile(dst, data, 0o755); err != nil {
		return err
	}
	return nil
}
