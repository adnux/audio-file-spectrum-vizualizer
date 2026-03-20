//go:build linux && arm64

package assets

import _ "embed"

//go:embed bins/ffmpeg-linux-arm64
var FFmpegBin []byte

//go:embed bins/ffprobe-linux-arm64
var FFprobeBin []byte
