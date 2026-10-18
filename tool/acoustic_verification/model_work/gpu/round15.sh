#!/usr/bin/env bash
# Round 15 (2026-10-18): what calibrating the teachers needs (calibrate_teacher.py, on
# the laptop). For ft4 and ft5:
#   1. their log-probabilities on transcribed clips — RetaSy amateurs judged correct
#      (shard_95), the expert-labelled learners (shard_96: what was heard), one shard of
#      professional recitation (data_orig/shard_0000) — to fit a temperature and biases;
#   2. their outputs on the test packs that have none yet, to judge the calibration.
#   tmux new -d -s round15 'bash gpu/round15.sh 2>&1 | tee -a round15.out'
set -u
cd "$(dirname "$0")/.."
log() { echo "$(date -u +%H:%M) $*" | tee -a round4.log; }
mkdir -p artifacts/results calib_fit
for ft in ft4 ft5; do
  log "dump $ft"
  TEACHER_WEIGHTS=teachers/teacher_$ft.pt .venv/bin/python teacher_dump.py calib_fit/$ft.npz \
    data_retasy/shard_95*.npz data_real/shard_96*.npz data_orig/shard_0000.npz > dump_$ft.out 2>&1
  for pack in phone phone2 phone3 phone4 phone6 phone7 calib calibdeg ikhlash juz30h retasy quranmbh; do
    [ -f artifacts/results/${pack}_t$ft.json ] && continue
    TEACHER_WEIGHTS=teachers/teacher_$ft.pt .venv/bin/python bench_run.py torch ${pack}_t$ft --pack $pack \
      > /dev/null 2>> bench_$ft.err || log "FAILED $pack $ft"
  done
  log "$ft done"
done
log "ROUND 15 DONE"
