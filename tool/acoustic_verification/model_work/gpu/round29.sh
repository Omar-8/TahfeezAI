#!/usr/bin/env bash
# Round 29 (2026-10-21): G20 — G19@2k kept, not overfitted. From runs/G19/ema_2000.pt (owner
# letters 31, Tarteel-200 205, QuranMB 66.2%; G19 on to 5k got worse: owner 45, amateurs 5.1%).
# lr 8e-6; only the top 3 encoder layers + adapter + head learn (--train-top 3, 68M of 116M).
# Mix per pass: existing 171 h (74.1%), random real phone shard_60 12.2 h x2 (10.6%),
# balanced hard phone shard_62 11.8 h x3 (15.3%): re-mined with G19@2k as the student
# (phone_mine.py), alignment cost <= 0.4, the expected letter the teacher's own top letter
# (mean p >= 0.6), the student preferring another by >= 0.15, ں never counted; drawn 40 per
# confusion pair (x3 for ح→ه ض→د ك→ق ء→ي ن→ي), a clip at most 4 times (phone_select.py
# --balanced: 954 clips, 3,664 draws). 2,000 steps, paused every 500 for the stop rules.
#   PAUSE=500 bash gpu/round29.sh   (then 1000, 1500, 2000 — each resumes)
set -u
cd "$(dirname "$0")/.."
PY=.venv/bin/python
log() { echo "$(date -u +%H:%M) $*" | tee -a round4.log; }
export TEACHER_WEIGHTS=teachers/teacher_ft5.pt MAX_CLIP_S=20
unset TEACHER_SELECT
rm -f data_mix/shard_61*.npz
for f in data_phone2/shard_62*.npz; do ln -sf "../$f" "data_mix/$(basename "$f")"; done
name=G20
PAUSE=${PAUSE:-500}
log "$name to $PAUSE ($(ls data_mix/shard_*.npz | wc -l) shards: $(ls data_mix/shard_60*.npz | wc -l) random, $(ls data_mix/shard_62*.npz | wc -l) hard phone)"
for ma in 70 56 44 36 30 30; do
  PYTORCH_CUDA_ALLOC_CONF=expandable_segments:True \
  $PY distill_student.py train d6h data_mix runs/$name --max-audio $ma --seed 301 \
    --init runs/G19/ema_2000.pt --steps 2000 --pause-at $PAUSE --lr 8e-6 --train-top 3 \
    --augment 0.6 --phone-extra --pitch 0.25 --tempo 0.3 --hard 0.75 --focus 0.5 --crop 0.5 \
    --repeat shard_95=16,shard_97=2,shard_98=2,shard_99=2,shard_60=2,shard_62=3 \
    --real-phone shard_60+shard_62 \
    --trust shard_95:0.2:10 --guide init/v35s/student.pt:shard_95:0.7 \
    --spike-mode clip --val-every 500 --save-every 500 --resume --vowel 1 \
    --stream 0.96,5.12 --stream-chunks 0.64,1.28 >> train_$name.out 2>&1
  [ -f runs/$name/ema_$PAUSE.pt ] && break
  log "$name stopped at max-audio $ma: $(grep -E 'Error|error' train_$name.out | tail -n 1 | cut -c1-100)"
done
[ -f runs/$name/ema_$PAUSE.pt ] && log "$name at $PAUSE: $(grep VAL runs/$name/train.log | tail -n 1)" || log "$name FAILED at $PAUSE"
