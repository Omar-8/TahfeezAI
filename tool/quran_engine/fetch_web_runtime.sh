#!/usr/bin/env bash
# Builds the Web WASM runtime from the pinned Quran Engine Rust source and
# vendors it alongside the pinned web/qvp.js wrapper — see
# tool/quran_engine/README.md for the exact pinned commit.
#
# Requires: a Rust toolchain with the wasm32-unknown-unknown target
#   curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y --profile minimal
#   rustup target add wasm32-unknown-unknown
set -euo pipefail

ENGINE_COMMIT="a19ee9b16ec60689dfd9ef566c49d393f9a47459"
SRC_DIR="$(mktemp -d)"
trap 'rm -rf "$SRC_DIR"' EXIT

OUT_DIR="web/quran_engine"
mkdir -p "$OUT_DIR"

echo "Fetching quran-engine @ $ENGINE_COMMIT..."
curl -sSL -m 60 "https://github.com/quran-ws/quran-engine/archive/${ENGINE_COMMIT}.tar.gz" \
  -o "$SRC_DIR/engine.tar.gz"
tar xzf "$SRC_DIR/engine.tar.gz" -C "$SRC_DIR"
REPO_DIR="$SRC_DIR/quran-engine-${ENGINE_COMMIT}"

echo "Building qvp-ffi for wasm32-unknown-unknown (release)..."
( cd "$REPO_DIR" && cargo build -p qvp-ffi --release --target wasm32-unknown-unknown )

cp "$REPO_DIR/target/wasm32-unknown-unknown/release/qvp_ffi.wasm" "$OUT_DIR/qvp_ffi.wasm"
cp "$REPO_DIR/web/qvp.js" "$OUT_DIR/qvp.js"

echo ""
echo "Vendored to $OUT_DIR/:"
sha256sum "$OUT_DIR/qvp_ffi.wasm" "$OUT_DIR/qvp.js"
