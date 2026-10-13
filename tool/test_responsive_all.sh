#!/usr/bin/env bash
# The whole responsive matrix (test/app/responsive_reader_test.dart with
# TAHFEEZ_RESPONSIVE=all, some 3,500 runs) in shards: each its own test
# process, one after another, under a memory cap where systemd allows one.
#
# Never run the whole matrix as one process: its reader runs keep some
# 30 MB each until the process ends — a single run grew past 13 GB and the
# out-of-memory killer took the desktop session with it (2026-10-13).
#
#   tool/test_responsive_all.sh            # all shards
#   SHARDS=60 MEMORY=3G tool/test_responsive_all.sh
#   FROM=12 tool/test_responsive_all.sh    # resume at shard 12
set -u
cd "$(dirname "$0")/.."

SHARDS=${SHARDS:-60}
MEMORY=${MEMORY:-3G}
FROM=${FROM:-0}
LOGS=${LOGS:-build/responsive}
mkdir -p "$LOGS"

capped() {
  if command -v systemd-run >/dev/null 2>&1 &&
    systemd-run --user --scope -q true 2>/dev/null; then
    systemd-run --user --scope -q -p MemoryMax="$MEMORY" -p MemorySwapMax=0 "$@"
  else
    "$@"
  fi
}

failed=()
for ((i = FROM; i < SHARDS; i++)); do
  log="$LOGS/shard-$i.txt"
  if TAHFEEZ_RESPONSIVE=all capped flutter test \
    test/app/responsive_reader_test.dart \
    --total-shards "$SHARDS" --shard-index "$i" >"$log" 2>&1; then
    echo "shard $((i + 1))/$SHARDS: $(tail -1 "$log")"
  else
    echo "shard $((i + 1))/$SHARDS FAILED: $(tail -1 "$log") — see $log"
    failed+=("$i")
  fi
done

if ((${#failed[@]})); then
  echo "Failed shards: ${failed[*]} (logs in $LOGS)"
  exit 1
fi
echo "All $SHARDS shards passed."
