#!/usr/bin/env bash
# Publishes the meaning packs (assets/quran/db/packs/*.xz) to the GitHub
# release the app downloads them from: `meaning-packs-<version>`, the
# version in assets/quran/db/manifest.json (DownloadingMeaningPackStore).
# Run it whenever tool/quran_db/build_databases_test.dart builds a new
# version — before a release that carries it — or the phones can't get
# their packs. Re-running it is safe (files are replaced).
#
#   GH_TOKEN=… tool/quran_db/publish_meaning_packs.sh
set -euo pipefail
cd "$(dirname "$0")/../.."

version=$(python3 -c "import json; print(json.load(open('assets/quran/db/manifest.json'))['version'])")
tag="meaning-packs-$version"
if ! gh release view "$tag" >/dev/null 2>&1; then
  gh release create "$tag" --title "Meaning packs $version" --latest=false \
    --notes "Translation, tafsir and word-meaning packs the app downloads (databases version $version). Each is checked against its SHA-256 in assets/quran/db/manifest.json; sources and licences: docs/THIRD_PARTY_RESOURCES.md."
fi
gh release upload "$tag" assets/quran/db/packs/*.xz --clobber
count=$(gh release view "$tag" --json assets -q '.assets | length')
echo "$tag: $count files"

# Every pack the manifest names must be there, at its size.
python3 - "$tag" <<'PY'
import json, subprocess, sys
tag = sys.argv[1]
assets = {a['name']: a['size'] for a in json.loads(subprocess.check_output(
    ['gh', 'release', 'view', tag, '--json', 'assets', '-q', '.assets']))}
manifest = json.load(open('assets/quran/db/manifest.json'))
bad = []
for kind, packs in manifest['packs'].items():
    for pid, e in packs.items():
        name = e['asset'].split('/')[-1]
        if assets.get(name) != e['xzBytes']:
            bad.append(name)
if bad:
    sys.exit(f'missing or wrong size: {bad}')
print('every pack published, at its size')
PY
