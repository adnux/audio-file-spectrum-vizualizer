// Package fft provides FFT-based frequency spectrum analysis.
package fft

import (
	"math"
	"math/cmplx"
)

// SpectrumBin represents a single frequency bin in the spectrum.
type SpectrumBin struct {
	Frequency float64 `json:"frequency"` // Hz
	Magnitude float64 `json:"magnitude"` // dBFS
}

// Compute performs an FFT on the input samples and returns the frequency spectrum.
// windowSize controls FFT resolution; overlap is the hop fraction (0..1).
// The returned spectrum is averaged across all windows and expressed in dBFS.
func Compute(samples []float64, sampleRate int, windowSize int) []SpectrumBin {
	if len(samples) < windowSize {
		windowSize = len(samples)
	}
	// Pad to next power of two.
	n := nextPow2(windowSize)

	// Build Hann window coefficients.
	window := hannWindow(n)

	// Accumulate magnitude across overlapping windows (50% hop).
	hopSize := n / 2
	var accum []float64
	count := 0

	for start := 0; start+n <= len(samples); start += hopSize {
		frame := make([]complex128, n)
		for i := 0; i < n; i++ {
			frame[i] = complex(samples[start+i]*window[i], 0)
		}
		spectrum := radix2FFT(frame)

		half := n/2 + 1
		if accum == nil {
			accum = make([]float64, half)
		}
		for i := 0; i < half; i++ {
			accum[i] += cmplx.Abs(spectrum[i])
		}
		count++
	}

	if count == 0 || accum == nil {
		return nil
	}

	half := n/2 + 1
	bins := make([]SpectrumBin, half)
	freqResolution := float64(sampleRate) / float64(n)

	for i := 0; i < half; i++ {
		mag := accum[i] / float64(count)
		// Normalise by window size and convert to dBFS.
		mag /= float64(n) / 2.0
		var dB float64
		if mag > 0 {
			dB = 20 * math.Log10(mag)
		} else {
			dB = -120
		}
		if dB < -120 {
			dB = -120
		}
		bins[i] = SpectrumBin{
			Frequency: float64(i) * freqResolution,
			Magnitude: dB,
		}
	}
	return bins
}

// radix2FFT is an in-place Cooley-Tukey FFT (n must be a power of 2).
func radix2FFT(x []complex128) []complex128 {
	n := len(x)
	// Bit-reversal permutation.
	j := 0
	for i := 1; i < n; i++ {
		bit := n >> 1
		for ; j&bit != 0; bit >>= 1 {
			j ^= bit
		}
		j ^= bit
		if i < j {
			x[i], x[j] = x[j], x[i]
		}
	}
	// Butterfly stages.
	for length := 2; length <= n; length <<= 1 {
		angle := -2 * math.Pi / float64(length)
		wLen := complex(math.Cos(angle), math.Sin(angle))
		for i := 0; i < n; i += length {
			w := complex(1, 0)
			for k := 0; k < length/2; k++ {
				u := x[i+k]
				v := x[i+k+length/2] * w
				x[i+k] = u + v
				x[i+k+length/2] = u - v
				w *= wLen
			}
		}
	}
	return x
}

func hannWindow(n int) []float64 {
	w := make([]float64, n)
	for i := range w {
		w[i] = 0.5 * (1 - math.Cos(2*math.Pi*float64(i)/float64(n-1)))
	}
	return w
}

func nextPow2(n int) int {
	p := 1
	for p < n {
		p <<= 1
	}
	return p
}
