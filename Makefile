BINARY   = spectrum-viz
GO       = go
VERSION  ?= $(shell date +%Y%m%d)

.PHONY: build run dist dist-darwin dist-windows dist-linux \
        prepare prepare-darwin prepare-windows prepare-linux \
        bundle-darwin-arm64 bundle-darwin-amd64 bundle-darwin \
        bundle-linux-amd64 bundle-linux-arm64 bundle-linux \
        clean

# ── single-binary build ───────────────────────────────────────────────────────
# Requires embedded ffmpeg binaries; run  make prepare  first.
build:
	$(GO) build -ldflags="-s -w" -o $(BINARY) .

run: build
	./$(BINARY)

# ── download ffmpeg into internal/assets/bins/ ────────────────────────────────
prepare:
	./scripts/download-ffmpeg.sh all

prepare-darwin:
	./scripts/download-ffmpeg.sh darwin

prepare-windows:
	./scripts/download-ffmpeg.sh windows

prepare-linux:
	./scripts/download-ffmpeg.sh linux

# ── cross-compile single-binary ZIPs (legacy bundle approach kept for CI use) ─
dist:
	VERSION=$(VERSION) ./scripts/package.sh all

dist-darwin:
	VERSION=$(VERSION) ./scripts/package.sh darwin

dist-windows:
	VERSION=$(VERSION) ./scripts/package.sh windows

dist-linux:
	VERSION=$(VERSION) ./scripts/package.sh linux

# ── native platform packages ──────────────────────────────────────────────────
bundle-darwin-arm64:
	VERSION=$(VERSION) ./scripts/bundle-macos.sh arm64

bundle-darwin-amd64:
	VERSION=$(VERSION) ./scripts/bundle-macos.sh amd64

bundle-darwin: bundle-darwin-arm64 bundle-darwin-amd64

bundle-linux-amd64:
	VERSION=$(VERSION) ARCH=amd64 ./scripts/bundle-linux.sh

bundle-linux-arm64:
	VERSION=$(VERSION) ARCH=arm64 ./scripts/bundle-linux.sh

bundle-linux: bundle-linux-amd64 bundle-linux-arm64

# ── clean ─────────────────────────────────────────────────────────────────────
clean:
	rm -f $(BINARY)
	rm -rf dist/ uploads/
