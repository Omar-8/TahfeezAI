#!/usr/bin/env bash
# Downloads the Quran Engine POC's representative pages from the pinned
# data release, verifying each file's SHA-256 against that release's own
# manifest.json before writing anything — see tool/quran_engine/README.md.
set -euo pipefail

MANIFEST_URL="https://cdn.quran.ws/qvp/v0.3.0/manifest.json"
OUT_DIR="assets/quran/quran_engine/pages"
PAGES=(1 2 42 106 302 604)

mkdir -p "$OUT_DIR"
curl -sS -m 30 "$MANIFEST_URL" -o "$OUT_DIR/manifest.json"

python3 - "$OUT_DIR" "${PAGES[@]}" <<'PYEOF'
import hashlib
import json
import subprocess
import sys

out_dir = sys.argv[1]
pages = [int(p) for p in sys.argv[2:]]

manifest = json.load(open(f"{out_dir}/manifest.json"))
release = manifest["release"]
base = release.get("base") or "https://cdn.quran.ws/qvp/v0.3.0/"
files = release["files"]

targets = []
for p in pages:
    k = f"{p:03d}"
    targets.append(f"{k}.qvp")
    targets.append(f"{k}.words.json")
targets.append("atlas.qva")

failed = False
for name in targets:
    expected = files.get(name)
    if expected is None:
        print(f"MISSING FROM MANIFEST: {name}", file=sys.stderr)
        failed = True
        continue
    path = f"{out_dir}/{name}"
    url = base + name
    result = subprocess.run(["curl", "-sS", "-m", "30", url, "-o", path])
    if result.returncode != 0:
        print(f"DOWNLOAD FAILED: {name}", file=sys.stderr)
        failed = True
        continue
    actual = hashlib.sha256(open(path, "rb").read()).hexdigest()
    if actual != expected:
        print(f"HASH MISMATCH: {name} (expected {expected}, got {actual})", file=sys.stderr)
        failed = True
        continue
    print(f"OK: {name}")

if failed:
    sys.exit(1)

print(f"\nrelease: {release['name']} v{release['version']}")
print(f"engine_commit (data release's own pin): {release['engine_commit']}")
print(f"generated_at: {release['generated_at']}")
PYEOF
