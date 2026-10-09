#!/usr/bin/env bash
# Downloads Quran Engine pages from the pinned data release, verifying each
# file's SHA-256 against that release's own manifest.json before writing
# anything — see tool/quran_engine/README.md.
#
# Usage:
#   tool/quran_engine/fetch_page_data.sh            # 6 representative pages
#   tool/quran_engine/fetch_page_data.sh --all       # all 604 pages
set -euo pipefail

MANIFEST_URL="https://cdn.quran.ws/qvp/v0.3.0/manifest.json"
# The app bundles only the .qvp pages (pubspec.yaml); the release's
# word sidecars, atlas and manifest go beside them, unbundled.
OUT_DIR="assets/quran/quran_engine/pages"
SIDECAR_DIR="assets/quran/quran_engine/sidecar"

if [[ "${1:-}" == "--all" ]]; then
  PAGES=($(seq 1 604))
else
  PAGES=(1 2 42 106 302 604)
fi

mkdir -p "$OUT_DIR" "$SIDECAR_DIR"
curl -sS -m 30 "$MANIFEST_URL" -o "$SIDECAR_DIR/manifest.json"

python3 - "$OUT_DIR" "$SIDECAR_DIR" "${PAGES[@]}" <<'PYEOF'
import hashlib
import json
import subprocess
import sys
from concurrent.futures import ThreadPoolExecutor, as_completed

out_dir = sys.argv[1]
sidecar_dir = sys.argv[2]
pages = [int(p) for p in sys.argv[3:]]

manifest = json.load(open(f"{sidecar_dir}/manifest.json"))
release = manifest["release"]
base = release.get("base") or "https://cdn.quran.ws/qvp/v0.3.0/"
files = release["files"]

targets = []
for p in pages:
    k = f"{p:03d}"
    targets.append(f"{k}.qvp")
    targets.append(f"{k}.words.json")
targets.append("atlas.qva")

def fetch_one(name):
    expected = files.get(name)
    if expected is None:
        return name, False, f"MISSING FROM MANIFEST: {name}"
    path = f"{out_dir if name.endswith('.qvp') else sidecar_dir}/{name}"
    url = base + name
    result = subprocess.run(
        ["curl", "-sS", "-m", "30", url, "-o", path],
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
    )
    if result.returncode != 0:
        return name, False, f"DOWNLOAD FAILED: {name}"
    actual = hashlib.sha256(open(path, "rb").read()).hexdigest()
    if actual != expected:
        return name, False, f"HASH MISMATCH: {name} (expected {expected}, got {actual})"
    return name, True, f"OK: {name}"

failed = False
ok_count = 0
# A small worker pool -- polite to the CDN, still far faster than one
# curl process at a time for a full 604-page (1,813-file) fetch.
with ThreadPoolExecutor(max_workers=8) as pool:
    futures = [pool.submit(fetch_one, name) for name in targets]
    for i, future in enumerate(as_completed(futures), start=1):
        name, ok, message = future.result()
        if ok:
            ok_count += 1
        else:
            failed = True
            print(message, file=sys.stderr)
        if i % 100 == 0 or i == len(targets):
            print(f"progress: {i}/{len(targets)} ({ok_count} OK)")

if failed:
    sys.exit(1)

print(f"\nAll {ok_count} files verified OK.")
print(f"release: {release['name']} v{release['version']}")
print(f"engine_commit (data release's own pin): {release['engine_commit']}")
print(f"generated_at: {release['generated_at']}")
PYEOF
