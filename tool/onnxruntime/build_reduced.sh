#!/usr/bin/env bash
# Builds a reduced ONNX Runtime for Android arm64 — only the operators the
# on-device acoustic model uses (required_ops.config) — and puts its native
# libraries where android/app/build.gradle.kts picks them up
# (android/app/src/main/jniLibs-ort/, not in git). 15.9 MB instead of the Maven
# package's 33.0 MB; the Java API stays the Maven package's (same version).
#
#   tool/onnxruntime/build_reduced.sh [work dir]
#
# Needs: git, Python 3 with `pip install "cmake>=3.28" ninja pkgconf` on PATH,
# the Android SDK (ANDROID_HOME) and NDK 27 (ANDROID_NDK_HOME). About 30-60 min.
#
# required_ops.config: tools/python/create_reduced_build_config.py over the
# model and the model as ONNX Runtime optimizes it (ORT_ENABLE_EXTENDED —
# fusions add FusedMatMul and QuickGelu), plus fused operators ARM may add at
# ORT_ENABLE_ALL. Regenerate it whenever the model's architecture changes, and
# check a new model loads and runs on a device before shipping it.
set -euo pipefail
VERSION=v1.30.0                 # must match the Maven onnxruntime-android version
HERE="$(cd "$(dirname "$0")" && pwd)"
APP="$HERE/../../android/app/src/main/jniLibs-ort/arm64-v8a"
WORK="${1:-${TMPDIR:-/tmp}/ortbuild}"
mkdir -p "$WORK"
cd "$WORK"
[ -d onnxruntime ] || git clone --depth 1 --branch "$VERSION" --recurse-submodules \
  --shallow-submodules https://github.com/microsoft/onnxruntime.git
cat > settings.json <<EOF
{
  "build_abis": ["arm64-v8a"],
  "android_min_sdk_version": 24,
  "android_target_sdk_version": 34,
  "build_params": ["--enable_lto", "--android", "--parallel", "--cmake_generator=Ninja",
                   "--build_java", "--build_shared_lib", "--skip_tests",
                   "--compile_no_warning_as_error"]
}
EOF
# The AAR packaging step at the end may fail (Android Gradle Plugin vs the JDK);
# only the two native libraries below are used.
python3 onnxruntime/tools/ci_build/github/android/build_aar_package.py \
  --build_dir "$WORK/out" --config Release \
  --include_ops_by_config "$HERE/required_ops.config" settings.json || true
LIB="$WORK/out/intermediates/arm64-v8a/Release"
STRIP="$ANDROID_NDK_HOME/toolchains/llvm/prebuilt/linux-x86_64/bin/llvm-strip"
mkdir -p "$APP"
for so in libonnxruntime.so libonnxruntime4j_jni.so; do
  cp "$LIB/$so" "$APP/$so"
  "$STRIP" --strip-unneeded "$APP/$so"
done
ls -l "$APP"
