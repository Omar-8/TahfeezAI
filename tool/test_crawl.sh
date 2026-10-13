#!/usr/bin/env bash
# Every screen's every control tapped and long-pressed, one at a time
# (test/app/crawl_test.dart), in memory-capped shards — see
# tool/test_responsive_all.sh.
cd "$(dirname "$0")/.."
TEST=test/app/crawl_test.dart SHARDS=${SHARDS:-40} LOGS=${LOGS:-build/crawl} \
  exec tool/test_responsive_all.sh
