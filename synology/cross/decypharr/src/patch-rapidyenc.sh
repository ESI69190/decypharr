#!/bin/sh
set -eu

GO_SRC_DIR="$1"

cd "$GO_SRC_DIR"
go mod download github.com/Tensai75/rapidyenc@v0.0.1

MOD_DIR="$(go list -m -f '{{.Dir}}' github.com/Tensai75/rapidyenc)"
CGO_FILE="${MOD_DIR}/cgo.go"

chmod u+w "$CGO_FILE"

if ! grep -q '#cgo linux,arm LDFLAGS:' "$CGO_FILE"; then
    sed -i '/#cgo linux,arm64 LDFLAGS:/a #cgo linux,arm LDFLAGS: -lrapidyenc -lstdc++' "$CGO_FILE"
fi
