BINARY   = spectrum-viz
GO       = go
VERSION  ?= $(shell date +%Y%m%d)

.PHONY: build run dist dist-darwin dist-windows dist-linux clean

build:
	$(GO) build -ldflags="-s -w" -o $(BINARY) .

run: build
	./$(BINARY)

## Package for all platforms (requires curl, unzip, tar)
dist:
	VERSION=$(VERSION) ./scripts/package.sh all

dist-darwin:
	VERSION=$(VERSION) ./scripts/package.sh darwin

dist-windows:
	VERSION=$(VERSION) ./scripts/package.sh windows

dist-linux:
	VERSION=$(VERSION) ./scripts/package.sh linux

clean:
	rm -f $(BINARY)
	rm -rf dist/ uploads/
