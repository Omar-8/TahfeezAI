#!/usr/bin/env bash
# Round 14 (2026-10-18): G6 — v3.6 (G2e) continued with its own recipe, the only change
# the objective: each frame's teacher target weighed by teacher agreement (--gate):
# ft4/ft5 disagreeing x0.25, a trusted correct transcript contradicted x0.1, learners'
# shards taking ft5 where they disagree. Same data as G5 (no Juz 30). After round 13.
#   tmux new -d -s round14 'bash gpu/round14.sh 2>&1 | tee -a round14.out'
set -u
cd "$(dirname "$0")/.."
log() { echo "$(date -u +%H:%M) $*" | tee -a round4.log; }
until grep -q "ROUND 13 DONE" round4.log; do sleep 30; done
rm -rf data_mix && mkdir data_mix
n=0
for f in data_orig/shard_*.npz; do ln -s "../$f" "data_mix/$(printf 'shard_%04d.npz' $n)"; n=$((n + 1)); done
for f in data_retasy/shard_95*.npz data_learn/shard_9*.npz; do ln -s "../$f" "data_mix/$(basename "$f")"; done
ln -s ../data_orig/val.npz data_mix/val.npz
log "G6 start ($(ls data_mix/shard_*.npz | wc -l) shards)"
TEACHER_WEIGHTS=teachers/teacher_ft4.pt,teachers/teacher_ft5.pt TEACHER_SELECT=1 .venv/bin/python distill_student.py train d6h data_mix runs/G6 \
  --init init/G2e/student.pt --steps 6000 --max-audio 80 --lr 2e-5 --augment 0.6 --phone-extra --pitch 0.25 \
  --tempo 0.3 --hard 0.75 --focus 0.5 --crop 0.5 --repeat shard_95=16,shard_97=2,shard_98=2,shard_99=2 \
  --trust shard_95:0.2:10 --guide init/v35s/student.pt:shard_95:0.7 \
  --gate 0.25:0.1:shard_97+shard_98+shard_99 \
  --spike-mode clip --val-every 1000 --save-every 1000 --resume --seed 161 --vowel 1 \
  --stream 0.96,5.12 --stream-chunks 0.64,1.28 > train_G6.out 2>&1
mkdir -p out/G6
cp runs/G6/{student.pt,config.json,run.json,train.log} out/G6/ 2>/dev/null
cp init/v35s/fbank_prior.json out/G6/
rm -f runs/G6/checkpoint.pt
log "G6 done: $(grep VAL runs/G6/train.log | tail -n 1)"
