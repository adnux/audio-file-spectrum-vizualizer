//go:build windows && amd64

package assets

import _ "embed"

//go:embed bins/ffmpeg-windows-amd64.exe
var FFmpegBin []byte

//go:embed bins/ffprobe-windows-amd64.exe
var FFprobeBin []byte
