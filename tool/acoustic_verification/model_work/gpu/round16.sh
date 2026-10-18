#!/usr/bin/env bash
# Round 16 (2026-10-18): G7a — v3.6 (G2e) continued with its own recipe, the teachers
# calibrated at half strength (TEACHER_CAL: calibrate_teacher.py fit, then T and biases
# halved): as targets, at v3.6's thresholds, the owner's false flags 5.8 -> 5.0% against
# the raw teachers at their best matched setting, QuranMB mistakes found the same.
#   tmux new -d -s round16 'bash gpu/round16.sh 2>&1 | tee -a round16.out'
set -u
cd "$(dirname "$0")/.."
log() { echo "$(date -u +%H:%M) $*" | tee -a round4.log; }
rm -rf data_mix && mkdir data_mix
n=0
for f in data_orig/shard_*.npz; do ln -s "../$f" "data_mix/$(printf 'shard_%04d.npz' $n)"; n=$((n + 1)); done
for f in data_retasy/shard_95*.npz data_learn/shard_9*.npz; do ln -s "../$f" "data_mix/$(basename "$f")"; done
ln -s ../data_orig/val.npz data_mix/val.npz
log "G7a start ($(ls data_mix/shard_*.npz | wc -l) shards)"
PYTORCH_CUDA_ALLOC_CONF=expandable_segments:True TEACHER_CAL=teacher_cal_half_list.json \
TEACHER_WEIGHTS=teachers/teacher_ft4.pt,teachers/teacher_ft5.pt TEACHER_SELECT=1 .venv/bin/python distill_student.py train d6h data_mix runs/G7a \
  --init init/G2e/student.pt --steps 6000 --max-audio 70 --lr 2e-5 --augment 0.6 --phone-extra --pitch 0.25 \
  --tempo 0.3 --hard 0.75 --focus 0.5 --crop 0.5 --repeat shard_95=16,shard_97=2,shard_98=2,shard_99=2 \
  --trust shard_95:0.2:10 --guide init/v35s/student.pt:shard_95:0.7 \
  --spike-mode clip --val-every 1000 --save-every 1000 --resume --seed 171 --vowel 1 \
  --stream 0.96,5.12 --stream-chunks 0.64,1.28 > train_G7a.out 2>&1
[ -f runs/G7a/student.pt ] || { log "G7a FAILED: $(tail -n 1 train_G7a.out)"; exit 1; }
mkdir -p out/G7a
cp runs/G7a/{student.pt,config.json,run.json,train.log} out/G7a/
cp init/v35s/fbank_prior.json out/G7a/
rm -f runs/G7a/checkpoint.pt
log "G7a done: $(grep VAL runs/G7a/train.log | tail -n 1)"
