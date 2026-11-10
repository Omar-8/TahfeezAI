#!/usr/bin/env bash
# The web app, built for release: tool/build_web.sh [--base-href /path/] [extra flutter args]
#   - WebAssembly (skwasm, multi-threaded where the page is cross-origin
#     isolated) with the JavaScript build beside it for browsers without
#     WasmGC;
#   - CanvasKit served from the build itself, not Google's CDN;
#   - web/isolation_sw.js (registered by
#     web/flutter_bootstrap.js, not Flutter's own worker) only adds
#     COOP/COEP; the browser caches.
# Output: build/web (unused files removed). Serve it over HTTPS (or localhost): the microphone and
# the isolation worker need a secure context.
set -euo pipefail
cd "$(dirname "$0")/.."
flutter build web --release \
  --wasm \
  --no-web-resources-cdn \
  --no-wasm-dry-run \
  "$@"
# What the browser never asks for: the datasets only desktop development
# imports, the phones' xz meaning packs (the web imports the JSON), debug
# symbols and Flutter's own (unregistered) service worker.
rm -rf build/web/assets/assets/quran/mushaf build/web/assets/assets/quran/db/packs \
  build/web/assets/assets/quran/quran_engine/page_groups build/web/assets/assets/quran/quran_engine/page_groups.json
rm -f build/web/assets/assets/quran/quran_dataset.json build/web/flutter_service_worker.js
find build/web -name '*.symbols' -delete
du -sh build/web
