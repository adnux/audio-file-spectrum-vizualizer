//go:build linux && amd64

package assets

import _ "embed"

//go:embed bins/ffmpeg-linux-amd64
var FFmpegBin []byte

//go:embed bins/ffprobe-linux-amd64
var FFprobeBin []byte
