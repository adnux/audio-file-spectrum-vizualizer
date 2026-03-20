// Package audio provides FFmpeg-based audio decoding utilities.
package audio

import (
	"encoding/binary"
	"fmt"
	"math"
	"os"
	"os/exec"
	"path/filepath"
	"runtime"
	"strconv"
	"strings"
	"sync"
)

var (
	ffmpegPath  string
	ffprobePath string
	ffOnce      sync.Once
)

// findBinary returns the path to a named binary, checking next to the
// current executable first, then falling back to PATH.
func findBinary(name string) string {
	if runtime.GOOS == "windows" {
		name += ".exe"
	}
	if exe, err := os.Executable(); err == nil {
		candidate := filepath.Join(filepath.Dir(exe), name)
		if _, err := os.Stat(candidate); err == nil {
			return candidate
		}
	}
	if path, err := exec.LookPath(name); err == nil {
		return path
	}
	return name // will produce a clear error when executed
}

func resolvePaths() {
	ffOnce.Do(func() {
		ffmpegPath = findBinary("ffmpeg")
		ffprobePath = findBinary("ffprobe")
	})
}

// Info holds metadata about an audio file.
type Info struct {
	Duration   float64
	SampleRate int
	Channels   int
	Codec      string
}

// GetInfo uses ffprobe to extract metadata from an audio file.
func GetInfo(path string) (*Info, error) {
	resolvePaths()
	out, err := exec.Command(ffprobePath,
		"-v", "error",
		"-select_streams", "a:0",
		"-show_entries", "stream=codec_name,sample_rate,channels,duration",
		"-of", "default=noprint_wrappers=1",
		path,
	).Output()
	if err != nil {
		return nil, fmt.Errorf("ffprobe: %w", err)
	}

	info := &Info{}
	for _, line := range strings.Split(string(out), "\n") {
		parts := strings.SplitN(line, "=", 2)
		if len(parts) != 2 {
			continue
		}
		key, val := strings.TrimSpace(parts[0]), strings.TrimSpace(parts[1])
		switch key {
		case "codec_name":
			info.Codec = val
		case "sample_rate":
			info.SampleRate, _ = strconv.Atoi(val)
		case "channels":
			info.Channels, _ = strconv.Atoi(val)
		case "duration":
			info.Duration, _ = strconv.ParseFloat(val, 64)
		}
	}
	return info, nil
}

// DecodePCM decodes an audio file to mono f32le PCM samples at the given sample rate.
// It decodes up to maxDuration seconds (0 = full file).
func DecodePCM(path string, sampleRate int, maxDuration float64) ([]float64, error) {
	args := []string{
		"-v", "error",
		"-i", path,
		"-ac", "1", // mix to mono
		"-ar", strconv.Itoa(sampleRate),
		"-f", "f32le", // 32-bit float little-endian raw PCM
		"-",
	}
	if maxDuration > 0 {
		args = append([]string{"-t", fmt.Sprintf("%.3f", maxDuration)}, args...)
	}
	args = append([]string{"-v", "error"}, args...)

	cmd := exec.Command(ffmpegPath, args...)
	raw, err := cmd.Output()
	if err != nil {
		return nil, fmt.Errorf("ffmpeg decode: %w", err)
	}

	numSamples := len(raw) / 4
	samples := make([]float64, numSamples)
	for i := range samples {
		bits := binary.LittleEndian.Uint32(raw[i*4 : i*4+4])
		f := math.Float32frombits(bits)
		samples[i] = float64(f)
	}
	return samples, nil
}
