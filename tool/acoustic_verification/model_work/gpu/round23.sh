#!/usr/bin/env bash
# Round 23 (2026-10-20): G13 — 12 layers grown from v3.6: its six trained layers (at ft5's
# positions 0 4 8 13 18 23) with ft5's own layers 2 6 10 15 16 20 between them, narrowed to
# 2048; the inserted layers start damped to 10% with their final norm fitted on real audio
# so the model starts as v3.6 (90% agreement; KL to ft5 0.463, v3.6 0.466). Trained from
# ft5 alone, live (1.28 s chunks), G11's data. A fresh 12-layer cut of ft5 (G12) was still
# at validation KL 0.20 after 10k steps (v3.6 0.086).
# An out-of-memory stop resumes from the last checkpoint with a smaller batch.
#   tmux new -d -s round23 'HF_HOME=/root/hf_home bash gpu/round23.sh 2>&1 | tee -a round23.out'
set -u
cd "$(dirname "$0")/.."
PY=.venv/bin/python
log() { echo "$(date -u +%H:%M) $*" | tee -a round4.log; }
export TEACHER_WEIGHTS=teachers/teacher_ft5.pt
# One clip in the mix needs ~1.6 GB alone for the teacher's attention: skip clips > 20 s.
export MAX_CLIP_S=20
unset TEACHER_SELECT
[ -f data_mix/val.npz ] || { log "G13: data_mix missing"; exit 1; }
log "G13 start"
for ma in 40 32 26 22 18 16 16 16 16 16 16 16 16 16 16 16; do
  PYTORCH_CUDA_ALLOC_CONF=expandable_segments:True \
  $PY distill_student.py train d12gh data_mix runs/G13 --init init/G2e12_ft5/student.pt \
    --steps 20000 --max-audio $ma --lr 5e-5 --augment 0.6 --phone-extra --pitch 0.25 \
    --tempo 0.3 --hard 0.75 --focus 0.5 --crop 0.5 --repeat shard_91=4,shard_95=16,shard_97=2,shard_98=2,shard_99=2 \
    --trust shard_95:0.2:10 --guide init/v35s/student.pt:shard_95:0.7 \
    --spike-mode clip --val-every 1000 --save-every 500 --resume --seed 241 --vowel 1 \
    --stream 0.96,5.12 --stream-chunks 0.64,1.28 >> train_G13.out 2>&1
  [ -f runs/G13/student.pt ] && break
  log "G13 stopped at max-audio $ma: $(grep -E 'Error|error' train_G13.out | tail -n 1 | cut -c1-100)"
done
[ -f runs/G13/student.pt ] || { log "G13 FAILED"; exit 1; }
mkdir -p out/G13
cp runs/G13/{student.pt,config.json,run.json,train.log} out/G13/
cp init/v35s/fbank_prior.json out/G13/
rm -f runs/G13/checkpoint.pt
log "G13 done: $(grep VAL runs/G13/train.log | tail -n 1)"
