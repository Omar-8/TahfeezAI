#!/usr/bin/env bash
# Tahfeez patch 0004: builds ios/Frameworks/qvp_ffi.xcframework — the
# engine's C ABI (`crates/qvp-ffi`) as a dynamic framework for iPhones
# (arm64) and the simulator (arm64 + x86_64). Run on a Mac with Xcode and
# rustup:
#
#   QVP_REPO=~/src/quran-engine bash third_party/qvp_flutter/scripts/build-engine-ios.sh
#
# QVP_REPO must be the upstream monorepo (github.com/quran-ws/quran-engine)
# at the commit qvp_flutter 0.2.2 was published from: its C ABI must match
# this package's Dart bindings (lib/src/bindings.dart) — see PATCHES.md.
set -euo pipefail
here="$(cd "$(dirname "$0")/.." && pwd)"
repo="${QVP_REPO:?set QVP_REPO to the quran-engine checkout}"
header="$repo/crates/qvp-ffi/include/qvp.h"

# The ABI check: 0.2.2's QvpLayoutSpec has max_aspect_slack (patch 0001);
# older engine commits don't, and would corrupt every layout call.
grep -q "max_aspect_slack" "$header" || {
  echo "error: $header has no max_aspect_slack — not the ABI of qvp_flutter 0.2.2" >&2
  exit 1
}

targets=(aarch64-apple-ios aarch64-apple-ios-sim x86_64-apple-ios)
rustup target add "${targets[@]}"
export IPHONEOS_DEPLOYMENT_TARGET=13.0
for t in "${targets[@]}"; do
  (cd "$repo" && cargo build -p qvp-ffi --release --target "$t")
done

work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT

# One framework bundle around a dylib (install name @rpath/qvp_ffi.framework/qvp_ffi).
framework() {
  local dir="$1"; shift
  mkdir -p "$dir/qvp_ffi.framework"
  lipo -create "$@" -output "$dir/qvp_ffi.framework/qvp_ffi"
  install_name_tool -id @rpath/qvp_ffi.framework/qvp_ffi "$dir/qvp_ffi.framework/qvp_ffi"
  cat > "$dir/qvp_ffi.framework/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleExecutable</key><string>qvp_ffi</string>
  <key>CFBundleIdentifier</key><string>ws.quran.qvp-ffi</string>
  <key>CFBundleName</key><string>qvp_ffi</string>
  <key>CFBundlePackageType</key><string>FMWK</string>
  <key>CFBundleShortVersionString</key><string>0.2.2</string>
  <key>CFBundleVersion</key><string>1</string>
  <key>MinimumOSVersion</key><string>13.0</string>
</dict>
</plist>
PLIST
}

lib() { echo "$repo/target/$1/release/libqvp_ffi.dylib"; }
framework "$work/device" "$(lib aarch64-apple-ios)"
framework "$work/sim" "$(lib aarch64-apple-ios-sim)" "$(lib x86_64-apple-ios)"

out="$here/ios/Frameworks/qvp_ffi.xcframework"
rm -rf "$out"
xcodebuild -create-xcframework \
  -framework "$work/device/qvp_ffi.framework" \
  -framework "$work/sim/qvp_ffi.framework" \
  -output "$out"
echo "built $out"
