#!/usr/bin/env bash
# The owner's phone build: profile, arm64, keeps recordings, re-signed with
# the upload key (so it installs over the store app, data kept).
set -euo pipefail
cd "$(dirname "$0")/.."
rm -rf build/app/outputs/apk/profile build/app/outputs/flutter-apk/app-profile.apk
flutter build apk --profile --target-platform android-arm64 --dart-define=TAHFEEZ_KEEP_RECORDINGS=true
P=$(grep '^storePassword=' android/key.properties | cut -d= -f2-)
K=$(grep '^keyPassword=' android/key.properties | cut -d= -f2-)
A=$(grep '^keyAlias=' android/key.properties | cut -d= -f2-)
S=$(grep '^storeFile=' android/key.properties | cut -d= -f2-)
case "$S" in /*) ;; *) S="android/app/$S" ;; esac
APK=build/app/outputs/flutter-apk/app-profile.apk
SP="$P" KP="$K" ~/Android/Sdk/build-tools/36.0.0/apksigner sign --ks "$S" --ks-key-alias "$A" \
  --ks-pass env:SP --key-pass env:KP --out build/phone.apk "$APK"
D=${PHONE:-a15e4df3}
adb -s "$D" shell svc power stayon usb
adb -s "$D" install -r build/phone.apk
adb -s "$D" shell svc power stayon false
