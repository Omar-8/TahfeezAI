#!/usr/bin/env bash
# Round 28 (2026-10-21): G19 — v3.6 fine-tuned on real phone recordings.
# greentechapps/user_recited_verses_full (CC BY 4.0, Tarteel users' recordings): phone_mine.py
# kept 7,012 clips (18.3 h; 20 held-out Tarteel-200 test clips found and excluded, benchmark
# ayahs skipped); phone_select.py: 1,966 hard clips (v3.6 prefers another letter where ft5
# is sure of the expected one, margin >= 0.2, or a tracked confusion; 6.1 h) -> shard_61xx,
# the other 5,046 (12.2 h) -> shard_60xx.
# Mix per pass (hours x repeat): existing 171 h (66.7%), random phone 12.2 x 4 (19.0%),
# hard phone 6.1 x 6 (14.3%). Real phone clips are never augmented (--real-phone): teacher
# and student hear the same waveform; no transcript, so no CTC on them — the teacher's KL is
# the target. No simulated phone bank. 5,000-step schedule, paused at 2,000 for evaluation.
#   tmux new -d -s round28 'HF_HOME=/workspace/hf_home bash gpu/round28.sh 2>&1 | tee -a round28.out'
set -u
cd "$(dirname "$0")/.."
PY=.venv/bin/python
log() { echo "$(date -u +%H:%M) $*" | tee -a round4.log; }
export TEACHER_WEIGHTS=teachers/teacher_ft5.pt MAX_CLIP_S=20
unset TEACHER_SELECT
for f in data_phone/shard_6*.npz; do ln -sf "../$f" "data_mix/$(basename "$f")"; done
log "G19 data_mix: $(ls data_mix/shard_*.npz | wc -l) shards ($(ls data_mix/shard_6*.npz | wc -l) real phone)"
name=G19
PAUSE=${PAUSE:-2000}
log "$name start (pause at $PAUSE)"
for ma in 70 56 44 36 30 30 30 30; do
  PYTORCH_CUDA_ALLOC_CONF=expandable_segments:True \
  $PY distill_student.py train d6h data_mix runs/$name --max-audio $ma --seed 291 \
    --init init/G2e/student.pt --steps 5000 --pause-at $PAUSE --lr 2e-5 --augment 0.6 --phone-extra \
    --pitch 0.25 --tempo 0.3 --hard 0.75 --focus 0.5 --crop 0.5 \
    --repeat shard_95=16,shard_97=2,shard_98=2,shard_99=2,shard_60=4,shard_61=6 \
    --real-phone shard_60+shard_61 \
    --trust shard_95:0.2:10 --guide init/v35s/student.pt:shard_95:0.7 \
    --spike-mode clip --val-every 500 --save-every 500 --resume --vowel 1 \
    --stream 0.96,5.12 --stream-chunks 0.64,1.28 >> train_$name.out 2>&1
  { [ -f runs/$name/ema_$PAUSE.pt ] || [ -f runs/$name/student.pt ]; } && break
  log "$name stopped at max-audio $ma: $(grep -E 'Error|error' train_$name.out | tail -n 1 | cut -c1-100)"
done
if [ -f runs/$name/student.pt ]; then
  mkdir -p out/$name; cp runs/$name/{student.pt,config.json,run.json,train.log} out/$name/
  cp init/v35s/fbank_prior.json out/$name/; log "$name done: $(grep VAL runs/$name/train.log | tail -n 1)"
elif [ -f runs/$name/ema_$PAUSE.pt ]; then
  mkdir -p out/${name}_$PAUSE; cp runs/$name/ema_$PAUSE.pt out/${name}_$PAUSE/student.pt
  cp runs/$name/config.json out/${name}_$PAUSE/; cp init/v35s/fbank_prior.json out/${name}_$PAUSE/
  log "$name paused at $PAUSE: $(grep VAL runs/$name/train.log | tail -n 1)"
else log "$name FAILED"; fi
