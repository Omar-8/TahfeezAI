#!/bin/sh
# The Quran's JSON datasets: the phone installs the same data as ready-made
# databases (assets/quran/db/; lib/app/bootstrap.dart), so they are left out
# of the iPhone app, as Android leaves them out of its own
# (android/app/build.gradle.kts) — only the web imports them. About 190 MB
# of the App Store size (465.7 MB at 1.2.3 build 29).
#
# Runs after "Thin Binary", which copies App.framework (with flutter_assets)
# into the app; the app is signed after it.
set -eu

fw="${TARGET_BUILD_DIR}/${FRAMEWORKS_FOLDER_PATH}/App.framework"
quran="$fw/flutter_assets/assets/quran"
if [ ! -d "$quran" ]; then
  echo "strip_unused_assets: no $quran — nothing removed"
  exit 0
fi

before=$(du -sk "$fw" | cut -f1)
rm -f "$quran/quran_dataset.json"
rm -rf "$quran/mushaf" "$quran/translations" "$quran/tafsir" "$quran/wbw"
after=$(du -sk "$fw" | cut -f1)
echo "strip_unused_assets: App.framework $((before / 1024)) MB -> $((after / 1024)) MB"

# Already signed (its resources sealed): signed again without them.
if codesign -d "$fw" >/dev/null 2>&1 \
  && [ -n "${EXPANDED_CODE_SIGN_IDENTITY:-}" ] \
  && [ "${CODE_SIGNING_REQUIRED:-YES}" != "NO" ]; then
  codesign --force --sign "$EXPANDED_CODE_SIGN_IDENTITY" -- "$fw"
  echo "strip_unused_assets: App.framework signed again"
fi
