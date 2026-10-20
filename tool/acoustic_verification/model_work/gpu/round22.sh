#!/usr/bin/env bash
# Round 22 (2026-10-20): G12 — 12 layers cut from ft5 (the best single teacher: owner's
# recordings 3.9% flagged, v3.6 5.2%; hears «تَذْكُرُوا۟» right), its feed-forwards narrowed
# to 2048 by activity on real audio, trained from ft5 alone for live use. 12 layers is the
# deepest that streams on a POCO F3 (1025 ms per 1.28 s chunk; 16: 1361 ms, too slow).
# A fresh cut relearns hearing: each kept layer also learns its ft5 layer's output
# (--hidden; needs --crop 0), for 40k steps. --max-audio 22: at 36 the teacher's 24 layers of
# hidden states ran out of the 3090's 24 GB; at 22 one batch kept failing after every resume: 16.
# Needs data_mix as round 20 left it (or data_orig, data_mined, data_retasy, data_learn).
#   tmux new -d -s round22 'HF_HOME=/root/hf_home bash gpu/round22.sh 2>&1 | tee -a round22.out'
set -u
cd "$(dirname "$0")/.."
PY=.venv/bin/python
log() { echo "$(date -u +%H:%M) $*" | tee -a round4.log; }
export TEACHER_WEIGHTS=teachers/teacher_ft5.pt
unset TEACHER_SELECT

if [ ! -f data_mix/val.npz ]; then
  rm -rf data_mix && mkdir data_mix
  n=0
  for f in data_orig/shard_*.npz; do ln -s "../$f" "data_mix/$(printf 'shard_%04d.npz' $n)"; n=$((n + 1)); done
  for f in data_mined/shard_91*.npz data_retasy/shard_95*.npz data_learn/shard_9*.npz; do
    ln -s "../$f" "data_mix/$(basename "$f")"
  done
  ln -s ../data_orig/val.npz data_mix/val.npz
fi
if [ ! -f init/ft5_d12/student.pt ]; then
  # The full-width 12-layer cut of ft5, for --prune-by-activity to narrow.
  $PY -c "
import os, torch, distill_student as ds
t = ds.load_teacher(); s = ds.make_student(t.model, 'd12')
os.makedirs('init/ft5_d12', exist_ok=True); torch.save(s.state_dict(), 'init/ft5_d12/student.pt')
" || { log "G12: init FAILED"; exit 1; }
fi
log "G12 start ($(ls data_mix/shard_*.npz | wc -l) shards)"
for attempt in 1 2 3 4 5 6; do
  PYTORCH_CUDA_ALLOC_CONF=expandable_segments:True \
  $PY distill_student.py train d12h data_mix runs/G12 --init init/ft5_d12/student.pt --prune-by-activity \
    --hidden 1.0 --steps 40000 --max-audio 16 --lr 2e-4 --augment 0.6 --phone-extra --pitch 0.25 \
    --tempo 0.3 --hard 0.75 --focus 0.5 --repeat shard_91=4,shard_95=16,shard_97=2,shard_98=2,shard_99=2 \
    --trust shard_95:0.2:10 --guide init/v35s/student.pt:shard_95:0.7 \
    --spike-mode clip --val-every 2000 --save-every 1000 --resume --seed 231 --vowel 1 \
    --stream 0.96,5.12 --stream-chunks 0.64,1.28 >> train_G12.out 2>&1
  [ -f runs/G12/student.pt ] && break
  log "G12 attempt $attempt stopped: $(grep -E 'Error|error' train_G12.out | tail -n 1 | cut -c1-120)"
done
[ -f runs/G12/student.pt ] || { log "G12 FAILED"; exit 1; }
mkdir -p out/G12
cp runs/G12/{student.pt,config.json,run.json,train.log} out/G12/
cp init/v35s/fbank_prior.json out/G12/
rm -f runs/G12/checkpoint.pt
log "G12 done: $(grep VAL runs/G12/train.log | tail -n 1)"
