#!/usr/bin/env bash
# Round 17 (2026-10-18): G8 — v3.6 (G2e) continued with its own recipe and a third
# teacher, the original Muaalem, on every frame near a noon / meem: it still hears a
# ghunnah's length (the owner's held «إِنَّ» decoded as 4 noons in 16 of 17 pairs, his cut
# ones as 2 or fewer in 16 of 17), which ft4 / ft5 and every student lost.
#   tmux new -d -s round17 'bash gpu/round17.sh 2>&1 | tee -a round17.out'
set -u
cd "$(dirname "$0")/.."
log() { echo "$(date -u +%H:%M) $*" | tee -a round4.log; }
until tail -n 1 round4.log | grep -qE 'G7a (done|FAILED)'; do sleep 30; done
rm -rf data_mix && mkdir data_mix
n=0
for f in data_orig/shard_*.npz; do ln -s "../$f" "data_mix/$(printf 'shard_%04d.npz' $n)"; n=$((n + 1)); done
for f in data_retasy/shard_95*.npz data_learn/shard_9*.npz; do ln -s "../$f" "data_mix/$(basename "$f")"; done
ln -s ../data_orig/val.npz data_mix/val.npz
log "G8 start ($(ls data_mix/shard_*.npz | wc -l) shards)"
PYTORCH_CUDA_ALLOC_CONF=expandable_segments:True \
TEACHER_WEIGHTS=teachers/teacher_ft4.pt,teachers/teacher_ft5.pt,base TEACHER_SELECT=1 .venv/bin/python distill_student.py train d6h data_mix runs/G8 \
  --init init/G2e/student.pt --steps 6000 --max-audio 60 --lr 2e-5 --augment 0.6 --phone-extra --pitch 0.25 \
  --tempo 0.3 --hard 0.75 --focus 0.5 --crop 0.5 --repeat shard_95=16,shard_97=2,shard_98=2,shard_99=2 \
  --trust shard_95:0.2:10 --guide init/v35s/student.pt:shard_95:0.7 \
  --spike-mode clip --val-every 1000 --save-every 1000 --resume --seed 181 --vowel 1 \
  --stream 0.96,5.12 --stream-chunks 0.64,1.28 > train_G8.out 2>&1
[ -f runs/G8/student.pt ] || { log "G8 FAILED: $(tail -n 1 train_G8.out)"; exit 1; }
mkdir -p out/G8
cp runs/G8/{student.pt,config.json,run.json,train.log} out/G8/
cp init/v35s/fbank_prior.json out/G8/
rm -f runs/G8/checkpoint.pt
log "G8 done: $(grep VAL runs/G8/train.log | tail -n 1)"
