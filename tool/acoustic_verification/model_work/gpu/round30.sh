#!/usr/bin/env bash
# Round 30 (2026-10-21): G21 — v3.7's recipe (round 28, G19 @2000) with two cheap changes:
#   1. RetaSy and the learners' clips (real phone recordings, shard_95 / 97-99) are treated
#      as real phone audio too: never augmented with simulated phone effects (--real-phone).
#   2. The teacher's targets softened on real phone batches (--real-temperature 2, the KL
#      rescaled by T^2): which letters the teacher nearly confused is passed on too.
# Everything else as G19: from v3.6 (init/G2e), ft5, lr 2e-5 on a 5,000-step schedule,
# paused at 2,000; the phone data mined with v3.6 as the student (phone_mine.py) and split
# as for G19 (phone_select.py), x4 random / x6 hard. One difference: every 7th usable
# recording is held out as a phone test pack (phonedev, ~1,000 clips; --holdout 7).
# Builds everything on a fresh machine (setup.sh run, kit uploaded). The mining and shards are
# built once and reused, and the seed is fixed: runs at other temperatures (REAL_T) or with
# the phone clips augmented (REAL_AUG=1) see the same data in the same order — only that
# one setting differs.
#   tmux new -d -s round30 'PAUSE=2000 HF_HOME=/workspace/hf_home bash gpu/round30.sh 2>&1 | tee -a round30.out'
#   NAME=G21t1 REAL_T=1 ...   NAME=G21t15 REAL_T=1.5 ...   NAME=G21aug REAL_AUG=1 ...
set -u
cd "$(dirname "$0")/.."
PY=.venv/bin/python
log() { echo "$(date -u +%H:%M) $*" | tee -a round4.log; }
export TEACHER_WEIGHTS=teachers/teacher_ft5.pt MAX_CLIP_S=20
unset TEACHER_SELECT
until [ -f teachers/teacher_ft5.pt ] && [ -f init/G2e/student.pt ] && [ -f init/v35s/student.pt ] \
      && [ "$(ls data_learn/shard_9*.npz 2>/dev/null | wc -l)" -ge 8 ]; do sleep 30; done
if [ ! -f data_orig/val.npz ]; then
  log "data_orig start"
  $PY distill_student.py prepare data_orig --hours 80 > prep_orig.out 2>&1
  grep -q '^prepared' prep_orig.out || { log "data_orig FAILED: $(tail -n 1 prep_orig.out)"; exit 1; }
fi
if [ ! -f data_phone_cand3/index.json ] || ! grep -q '"held_out"' data_phone_cand3/index.json; then
  log "mining (v3.6 as student, holdout 7)"
  $PY phone_mine.py data_phone_cand3 --student init/G2e/student.pt --test tlog_audio.npz tlog_cases.json \
    --holdout 7 > mine3.out 2>&1
  grep -q '^done' mine3.out || { log "mining FAILED: $(tail -n 1 mine3.out)"; exit 1; }
  log "mined: $(grep '^done' mine3.out)"
fi
if [ ! -d data_phone3 ]; then
  $PY phone_select.py data_phone_cand3 data_phone3 | tee -a round4.log
fi
rm -rf data_mix && mkdir data_mix
n=0
for f in data_orig/shard_*.npz; do ln -s "../$f" "data_mix/$(printf 'shard_%04d.npz' $n)"; n=$((n + 1)); done
for f in data_retasy/shard_95*.npz data_learn/shard_9*.npz data_phone3/shard_6*.npz; do ln -s "../$f" "data_mix/$(basename "$f")"; done
ln -s ../data_orig/val.npz data_mix/val.npz
name=${NAME:-G21}
REAL_T=${REAL_T:-2}
AUG_FLAG=$([ "${REAL_AUG:-0}" = 1 ] && echo --real-phone-augment)
PAUSE=${PAUSE:-2000}
log "$name to $PAUSE, real-phone T=$REAL_T ${AUG_FLAG:-raw} ($(ls data_mix/shard_*.npz | wc -l) shards)"
for ma in 70 56 44 36 30 30; do
  PYTORCH_CUDA_ALLOC_CONF=expandable_segments:True \
  $PY distill_student.py train d6h data_mix runs/$name --max-audio $ma --seed 311 \
    --init init/G2e/student.pt --steps 5000 --pause-at $PAUSE --lr 2e-5 --augment 0.6 --phone-extra \
    --pitch 0.25 --tempo 0.3 --hard 0.75 --focus 0.5 --crop 0.5 \
    --repeat shard_95=16,shard_97=2,shard_98=2,shard_99=2,shard_60=4,shard_61=6 \
    --real-phone shard_60+shard_61+shard_95+shard_97+shard_98+shard_99 --real-temperature $REAL_T $AUG_FLAG \
    --trust shard_95:0.2:10 --guide init/v35s/student.pt:shard_95:0.7 \
    --spike-mode clip --val-every 500 --save-every 500 --resume --vowel 1 \
    --stream 0.96,5.12 --stream-chunks 0.64,1.28 >> train_$name.out 2>&1
  [ -f runs/$name/ema_$PAUSE.pt ] && break
  log "$name stopped at max-audio $ma: $(grep -E 'Error|error' train_$name.out | tail -n 1 | cut -c1-100)"
done
if [ -f runs/$name/ema_$PAUSE.pt ]; then
  mkdir -p out/${name}_$PAUSE; cp runs/$name/ema_$PAUSE.pt out/${name}_$PAUSE/student.pt
  cp runs/$name/config.json out/${name}_$PAUSE/; cp init/v35s/fbank_prior.json out/${name}_$PAUSE/
  log "$name at $PAUSE: $(grep VAL runs/$name/train.log | tail -n 1)"
else log "$name FAILED"; fi
