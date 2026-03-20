package main

import (
	"embed"
	"fmt"
	"io/fs"
	"log"
	"net"
	"net/http"
	"os/exec"
	"runtime"
	"time"

	"audio-spectrum-visualizer/internal/assets"
	"audio-spectrum-visualizer/internal/audio"
	"audio-spectrum-visualizer/internal/server"
)

//go:embed static
var staticFiles embed.FS

func main() {
	// Extract bundled ffmpeg/ffprobe binaries from the embedded assets on first
	// run; subsequent runs reuse the cached copy.
	ffmpegPath, ffprobePath, err := assets.Extract()
	if err != nil {
		log.Printf("warning: could not extract bundled ffmpeg, falling back to PATH: %v", err)
	} else {
		audio.SetBinaryPaths(ffmpegPath, ffprobePath)
	}

	staticFS, err := fs.Sub(staticFiles, "static")
	if err != nil {
		log.Fatalf("failed to load embedded static files: %v", err)
	}

	port := findFreePort(8080)
	addr := fmt.Sprintf(":%d", port)
	url := fmt.Sprintf("http://localhost:%d", port)

	handler := server.New(staticFS)

	log.Printf("Audio Spectrum Visualizer → %s", url)

	go func() {
		time.Sleep(300 * time.Millisecond)
		openBrowser(url)
	}()

	if err := http.ListenAndServe(addr, handler); err != nil {
		log.Fatalf("server error: %v", err)
	}
}

// findFreePort returns the first available TCP port starting from preferred.
func findFreePort(preferred int) int {
	for port := preferred; port < preferred+100; port++ {
		ln, err := net.Listen("tcp", fmt.Sprintf(":%d", port))
		if err == nil {
			ln.Close()
			return port
		}
	}
	return preferred
}

// openBrowser opens the given URL in the default browser.
func openBrowser(url string) {
	var cmd *exec.Cmd
	switch runtime.GOOS {
	case "darwin":
		cmd = exec.Command("open", url)
	case "windows":
		cmd = exec.Command("rundll32", "url.dll,FileProtocolHandler", url)
	default:
		cmd = exec.Command("xdg-open", url)
	}
	_ = cmd.Start()
}
