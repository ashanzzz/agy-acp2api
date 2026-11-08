.PHONY: build-linux build-darwin build-windows clean test

PLUGIN_ID := agy-acp2api
DIST_DIR := dist

build-linux:
	mkdir -p $(DIST_DIR)
	CGO_ENABLED=1 GOOS=linux GOARCH=amd64 go build -buildvcs=false -tags cshared -buildmode=c-shared -o $(DIST_DIR)/$(PLUGIN_ID)_linux_amd64.so ./cmd/agy-acp2api

build-darwin:
	mkdir -p $(DIST_DIR)
	CGO_ENABLED=1 GOOS=darwin GOARCH=arm64 go build -buildvcs=false -tags cshared -buildmode=c-shared -o $(DIST_DIR)/$(PLUGIN_ID)_darwin_arm64.dylib ./cmd/agy-acp2api

build-windows:
	mkdir -p $(DIST_DIR)
	CGO_ENABLED=1 GOOS=windows GOARCH=amd64 go build -buildvcs=false -tags cshared -buildmode=c-shared -o $(DIST_DIR)/$(PLUGIN_ID)_windows_amd64.dll ./cmd/agy-acp2api

test:
	go test ./...

clean:
	rm -rf $(DIST_DIR)
