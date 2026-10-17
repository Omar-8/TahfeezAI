#!/usr/bin/env bash
# A trained student (a run dir: student.pt + config.json) in the phone's format, over
# every test set v3.5 was judged on, on this laptop (the test sets stay here):
#   1. stream_model.py --export: the stateful streaming ONNX (chunk, 5.12 s of past)
#   2. 4-bit weights, block 128 (export_candidates.py quant), int8 activations
#      (set_accuracy_level.py) — as shipped
#   3. bench_run.py over each pack -> artifacts/results/<pack>_<tag>.{json,f32}
# Then judge with the Dart tools against v35ss (v3.5 as shipped, 1.28 s chunks):
# tune_sound_margins.dart, qdat_rules.dart --pack qdath, real_mistakes.dart,
# final_vowels.dart, qalqala_threshold.dart, and the session replay.
#
#   bash eval_candidate.sh <run dir> <tag> [chunk_s=0.64]
set -euo pipefail
cd "$(dirname "$0")"
run=$1 tag=$2 chunk=${3:-0.64}
PY=../.venv/bin/python
PACKS=${PACKS:-"quranmb qdath ikhlash retasy calib calibdeg sessions phone phone2 phone3 phone4 phone6 phone7 phone8 phone9 bayyinah fatiha12 fatiha13 quraysh"}

if [ ! -f "artifacts/${tag}_b128_acc4.onnx" ]; then
  $PY stream_model.py "$run" --export "artifacts/fp32_$tag" --chunk "$chunk" --left 5.12 2>&1 | grep -E 'WORST|exported|lacks'
  $PY export_candidates.py quant "${tag}_b128" 4 128 --src "fp32_$tag" 2>&1 | tail -n 1
  $PY set_accuracy_level.py "artifacts/${tag}_b128.onnx" "artifacts/${tag}_b128_acc4.onnx" --level 4 | tail -n 1
  cp "artifacts/fp32_$tag/stream.json" "artifacts/${tag}_stream.json"
fi
for pack in $PACKS; do
  [ -f "artifacts/results/${pack}_${tag}.json" ] && continue
  STREAM_CFG="artifacts/${tag}_stream.json" $PY bench_run.py "artifacts/${tag}_b128_acc4.onnx" \
    "${pack}_${tag}" --pack "$pack" > /dev/null 2>&1 || echo "FAILED: $pack"
  echo "$pack done"
done
