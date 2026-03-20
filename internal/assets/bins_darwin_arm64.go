//go:build darwin && arm64

package assets

import _ "embed"

//go:embed bins/ffmpeg-darwin-arm64
var FFmpegBin []byte

//go:embed bins/ffprobe-darwin-arm64
var FFprobeBin []byte
