#!/usr/bin/env bash
# s150 end to end on the GPU machine: data, throughput check, training.
# Every stage resumes: re-run the script after an interruption.
set -euo pipefail
cd "$(dirname "$0")/.."
DATA=${DATA:-data}; OUT=${OUT:-runs/s150}; HOURS=${HOURS:-150}; STEPS=${STEPS:-30000}; BATCH=${BATCH:-320}
[ -f "$DATA/val.npz" ] || .venv/bin/python distill_student.py prepare "$DATA" --hours "$HOURS" 2>&1 | tee -a prepare.log
.venv/bin/python distill_student.py bench s150 "$DATA" --max-audio "$BATCH" 2>&1 | tail -1 | tee bench_s150.json
nohup .venv/bin/python distill_student.py train s150 "$DATA" "$OUT" --steps "$STEPS" --max-audio "$BATCH" --resume > "train_s150.out" 2>&1 &
echo "training in the background: tail -f train_s150.out"
