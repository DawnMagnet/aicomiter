.PHONY: build build-min build-release clean help

BINARY_NAME=aicomiter
VERSION?=$(shell git describe --tags --always 2>/dev/null || echo "dev")
BUILD_TIME?=$(shell date -u '+%Y-%m-%d_%H:%M:%S')
GIT_COMMIT?=$(shell git rev-parse --short HEAD 2>/dev/null || echo "unknown")

LDFLAGS=-ldflags "-s -w -X main.Version=$(VERSION) -X main.BuildTime=$(BUILD_TIME) -X main.GitCommit=$(GIT_COMMIT)"

help:
	@echo "aicomiter build targets:"
	@echo "  make build       - Build binary with debug info (larger, slower)"
	@echo "  make build-min   - Build minimal binary (stripped, ~7.7MB)"
	@echo "  make build-release - Build optimized release binary (smallest, ~5-6MB)"
	@echo "  make clean       - Remove built binaries"
	@echo "  make install     - Build and install to \$$GOPATH/bin"

build:
	go build -o $(BINARY_NAME) main.go
	@ls -lh $(BINARY_NAME)

build-min: clean
	go build -ldflags="-s -w" -o $(BINARY_NAME) main.go
	@ls -lh $(BINARY_NAME)

build-release: clean
	CGO_ENABLED=0 go build -trimpath -ldflags="-s -w" -o $(BINARY_NAME) main.go
	@ls -lh $(BINARY_NAME)

install: build-release
	go install

clean:
	rm -f $(BINARY_NAME)

run: build
	./$(BINARY_NAME) generate

test:
	go test ./...

lint:
	golangci-lint run ./...

fmt:
	go fmt ./...

vet:
	go vet ./...
