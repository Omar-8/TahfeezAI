#!/usr/bin/env bash
# Round 20 (2026-10-19): G11 — an 8-layer student at v3.6's width (d8h), grown from v3.6
# (init/G2e8: G2e's six layers with its 3rd and 5th doubled — agrees with v3.6 on 92% of
# frames before training; built from the teacher's own layers instead it was still at
# validation KL 0.46 after 4000 steps, v3.6 0.086). v3.6 (6 layers) is confidently wrong where the teachers are sure (owner's
# «تَذْكُرُوا۟», 43:13: teachers llr −11, v3.5 / v3.6 +7); one more round on hard clips
# (G10) only moved errors around. With the app's thread fix d8h runs 703 ms per 1.28 s
# chunk on a POCO F3 (v3.6 538 ms) and is 117 MB (fits the Play download). 8 layers
# first: 10 only if 8 doesn't close the gap (fewer phones keep up with 10).
# Data as G10: the professional 80 h, RetaSy trusted, learners, the 3,000 mined hard
# clips (data_mined: shard_9100-9107 rebuilt on the laptop from round 19's mining, and
# the owner's training half shard_9190).
#   tmux new -d -s round20 'bash gpu/round20.sh 2>&1 | tee -a round20.out'
set -u
cd "$(dirname "$0")/.."
PY=.venv/bin/python
log() { echo "$(date -u +%H:%M) $*" | tee -a round4.log; }
export TEACHER_WEIGHTS=teachers/teacher_ft4.pt,teachers/teacher_ft5.pt TEACHER_SELECT=1

if [ ! -f data_orig/val.npz ]; then
  log "data_orig start"
  # (the dataset library may crash on exit after "prepared": harmless)
  $PY distill_student.py prepare data_orig --hours 80 > prep_orig.out 2>&1
  grep -q '^prepared' prep_orig.out || { log "data_orig FAILED: $(tail -n 1 prep_orig.out)"; exit 1; }
  log "data_orig: $(ls data_orig/shard_*.npz | wc -l) shards"
fi

rm -rf data_mix && mkdir data_mix
n=0
for f in data_orig/shard_*.npz; do ln -s "../$f" "data_mix/$(printf 'shard_%04d.npz' $n)"; n=$((n + 1)); done
for f in data_mined/shard_91*.npz data_retasy/shard_95*.npz data_learn/shard_9*.npz; do
  ln -s "../$f" "data_mix/$(basename "$f")"
done
ln -s ../data_orig/val.npz data_mix/val.npz
log "G11 start ($(ls data_mix/shard_*.npz | wc -l) shards)"
# --max-audio 45: at 60 a batch of long clips ran out of the 3090's 24 GB after step 1000.
# A crash resumes from the last checkpoint (every 1000 steps), up to 5 times.
for attempt in 1 2 3 4 5; do
PYTORCH_CUDA_ALLOC_CONF=expandable_segments:True \
$PY distill_student.py train d8h data_mix runs/G11 --init init/G2e8/student.pt \
  --steps 15000 --max-audio 45 --lr 3e-5 --augment 0.6 --phone-extra --pitch 0.25 \
  --tempo 0.3 --hard 0.75 --focus 0.5 --crop 0.5 --repeat shard_91=4,shard_95=16,shard_97=2,shard_98=2,shard_99=2 \
  --trust shard_95:0.2:10 --guide init/v35s/student.pt:shard_95:0.7 \
  --spike-mode clip --val-every 1000 --save-every 1000 --resume --seed 211 --vowel 1 \
  --stream 0.96,5.12 --stream-chunks 0.64,1.28 >> train_G11.out 2>&1
[ -f runs/G11/student.pt ] && break
log "G11 attempt $attempt stopped: $(grep -E 'Error|error' train_G11.out | tail -n 1 | cut -c1-120)"
done
[ -f runs/G11/student.pt ] || { log "G11 FAILED: $(tail -n 1 train_G11.out)"; exit 1; }
mkdir -p out/G11
cp runs/G11/{student.pt,config.json,run.json,train.log} out/G11/
cp init/v35s/fbank_prior.json out/G11/
rm -f runs/G11/checkpoint.pt
log "G11 done: $(grep VAL runs/G11/train.log | tail -n 1)"
