//go:build darwin && amd64

package assets

import _ "embed"

//go:embed bins/ffmpeg-darwin-amd64
var FFmpegBin []byte

//go:embed bins/ffprobe-darwin-amd64
var FFprobeBin []byte
