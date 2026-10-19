#!/usr/bin/env bash
# Round 21 (2026-10-20): M1 — mHuBERT-147 (94M, its own pretrained ear intact) with a
# 43-sound head, distilled from ft4 + ft5 on G11's data (mhubert_student.py), offline
# (whole clips) as a test: does a student that keeps its pretraining hear the owner's
# phone audio as the teacher does, where every cut-down student failed?
#   tmux new -d -s round21 'HF_HOME=/root/hf_home bash gpu/round21.sh 2>&1 | tee -a round21.out'
set -u
cd "$(dirname "$0")/.."
PY=.venv/bin/python
log() { echo "$(date -u +%H:%M) $*" | tee -a round4.log; }
export TEACHER_WEIGHTS=teachers/teacher_ft4.pt,teachers/teacher_ft5.pt TEACHER_SELECT=1
[ -f data_mix/val.npz ] || { log "M1: data_mix missing"; exit 1; }
log "M1 start"
for attempt in 1 2 3 4 5; do
  PYTORCH_CUDA_ALLOC_CONF=expandable_segments:True \
  $PY mhubert_student.py train data_mix runs/M1 --steps 12000 --max-audio 100 --lr 5e-5 \
    --augment 0.6 --repeat shard_91=4,shard_95=16,shard_97=2,shard_98=2,shard_99=2 \
    --trust shard_95 --seed 221 >> train_M1.out 2>&1
  [ -f runs/M1/student.pt ] && break
  log "M1 attempt $attempt stopped: $(grep -E 'Error|error' train_M1.out | tail -n 1 | cut -c1-120)"
done
[ -f runs/M1/student.pt ] || { log "M1 FAILED"; exit 1; }
mkdir -p out/M1 && cp runs/M1/{student.pt,config.json,run.json,train.log} out/M1/
log "M1 done: $(grep VAL runs/M1/train.log | tail -n 1)"
