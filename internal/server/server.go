// Package server implements the HTTP server for the audio spectrum visualizer.
package server

import (
	"encoding/json"
	"fmt"
	"io"
	"io/fs"
	"log"
	"net/http"
	"os"
	"path/filepath"

	"audio-spectrum-visualizer/internal/audio"
	"audio-spectrum-visualizer/internal/fft"
)

const (
	maxUploadSize = 500 << 20 // 500 MB
	sampleRate    = 44100
	windowSize    = 8192
	maxDuration   = 0 // 0 = full file
)

// AnalysisResult is returned as JSON for each analysed file.
type AnalysisResult struct {
	Filename   string            `json:"filename"`
	Duration   float64           `json:"duration"`
	SampleRate int               `json:"sampleRate"`
	Channels   int               `json:"channels"`
	Codec      string            `json:"codec"`
	Spectrum   []fft.SpectrumBin `json:"spectrum"`
	Error      string            `json:"error,omitempty"`
}

// New creates and returns the configured HTTP mux.
func New(staticFS fs.FS) http.Handler {
	mux := http.NewServeMux()
	mux.Handle("/", http.FileServer(http.FS(staticFS)))
	mux.HandleFunc("/api/analyze", analyzeHandler)
	return mux
}

func analyzeHandler(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		http.Error(w, "method not allowed", http.StatusMethodNotAllowed)
		return
	}

	r.Body = http.MaxBytesReader(w, r.Body, maxUploadSize)
	if err := r.ParseMultipartForm(32 << 20); err != nil {
		http.Error(w, "request too large", http.StatusRequestEntityTooLarge)
		return
	}

	files := r.MultipartForm.File["files"]
	if len(files) == 0 {
		http.Error(w, "no files provided", http.StatusBadRequest)
		return
	}

	results := make([]AnalysisResult, 0, len(files))
	var tempFiles []string

	for _, fh := range files {
		result := AnalysisResult{Filename: fh.Filename}

		// Save to OS temp dir (ffmpeg needs a real path).
		tmp, err := os.CreateTemp("", "spectrum-upload-*"+filepath.Ext(fh.Filename))
		if err != nil {
			result.Error = fmt.Sprintf("failed to create temp file: %v", err)
			results = append(results, result)
			continue
		}
		tempFiles = append(tempFiles, tmp.Name())

		src, err := fh.Open()
		if err != nil {
			result.Error = fmt.Sprintf("failed to open upload: %v", err)
			results = append(results, result)
			continue
		}

		if _, err := io.Copy(tmp, src); err != nil {
			src.Close()
			result.Error = fmt.Sprintf("failed to save file: %v", err)
			results = append(results, result)
			continue
		}
		src.Close()
		tmp.Close()

		// Analyse.
		info, err := audio.GetInfo(tmp.Name())
		if err != nil {
			result.Error = fmt.Sprintf("ffprobe error: %v", err)
			results = append(results, result)
			continue
		}
		result.Duration = info.Duration
		result.SampleRate = info.SampleRate
		result.Channels = info.Channels
		result.Codec = info.Codec

		samples, err := audio.DecodePCM(tmp.Name(), sampleRate, maxDuration)
		if err != nil {
			result.Error = fmt.Sprintf("decode error: %v", err)
			results = append(results, result)
			continue
		}

		result.Spectrum = fft.Compute(samples, sampleRate, windowSize)
		results = append(results, result)
	}

	// Clean up temp files.
	for _, f := range tempFiles {
		if err := os.Remove(f); err != nil {
			log.Printf("warning: could not remove temp file %s: %v", f, err)
		}
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(results)
}
