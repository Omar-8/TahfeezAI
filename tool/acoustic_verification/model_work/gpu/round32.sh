#!/usr/bin/env bash
# Round 32 (2026-10-21): G23 — Quran-only diversity. v3.7 + Tadabur (FaisaI/tadabur, CC BY-NC
# 4.0: 600+ reciters' verse clips from public recordings; hf_ayah_data.py --source tadabur
# --hours-per-reciter 0.05: <= 3 min per reciter, Hafs only by the teacher's alignment, the
# test and calibration reciters excluded; teacher-only targets -> shard_84xx) and RetaSy
# repeated less (x6, was x16: the same ~1,000 amateurs). Both heard as recorded
# (--real-phone): teacher and student the same waveform. AQQD not used (no download found).
# Otherwise G22's control exactly: from v3.7, the Tarteel users' phone recordings (data_phone3
# x2 / x3), learners x2, ft5 at T=1, lr 1e-5, 2,000 steps, seed 321.
# NO_TADABUR=1 / RETASY=16 RETASY_RAW=0 (v3.7's RetaSy, augmented): the single-source checks.
#   tmux new -d -s round32 'bash gpu/round32.sh 2>&1 | tee -a round32.out'
set -u
cd "$(dirname "$0")/.."
PY=.venv/bin/python
log() { echo "$(date -u +%H:%M) $*" | tee -a round4.log; }
export TEACHER_WEIGHTS=teachers/teacher_ft5.pt MAX_CLIP_S=20
unset TEACHER_SELECT
RETASY=${RETASY:-6}
TAD=$([ "${NO_TADABUR:-0}" = 1 ] || echo "data_tadabur/shard_84*.npz")
rm -rf data_mix && mkdir data_mix
n=0
for f in data_orig/shard_*.npz; do ln -s "../$f" "data_mix/$(printf 'shard_%04d.npz' $n)"; n=$((n + 1)); done
for f in data_retasy/shard_95*.npz data_learn/shard_9*.npz data_phone3/shard_6*.npz $TAD; do
  ln -s "../$f" "data_mix/$(basename "$f")"
done
ln -s ../data_orig/val.npz data_mix/val.npz
name=${NAME:-G23}
log "$name start from v3.7 ($(ls data_mix/shard_*.npz | wc -l) shards; tadabur $(ls data_mix/shard_84*.npz 2>/dev/null | wc -l), retasy x$RETASY)"
for ma in 70 56 44 36 30 30; do
  PYTORCH_CUDA_ALLOC_CONF=expandable_segments:True \
  $PY distill_student.py train d6h data_mix runs/$name --max-audio $ma --seed 321 \
    --init init/v37/student.pt --steps 2000 --lr 1e-5 --augment 0.6 --phone-extra \
    --pitch 0.25 --tempo 0.3 --hard 0.75 --focus 0.5 --crop 0.5 \
    --repeat shard_95=$RETASY,shard_97=2,shard_98=2,shard_99=2,shard_60=2,shard_61=3,shard_84=1 \
    --real-phone shard_60+shard_61+shard_84$([ "${RETASY_RAW:-1}" = 1 ] && echo +shard_95) \
    --trust shard_95:0.2:10 --guide init/v35s/student.pt:shard_95:0.7 \
    --spike-mode clip --val-every 500 --save-every 500 --resume --vowel 1 \
    --stream 0.96,5.12 --stream-chunks 0.64,1.28 >> train_$name.out 2>&1
  [ -f runs/$name/student.pt ] && break
  log "$name stopped at max-audio $ma: $(grep -E 'Error|error' train_$name.out | tail -n 1 | cut -c1-100)"
done
[ -f runs/$name/student.pt ] || { log "$name FAILED"; exit 1; }
mkdir -p out/$name; cp runs/$name/{student.pt,config.json,run.json,train.log} out/$name/
cp init/v35s/fbank_prior.json out/$name/
log "$name done: $(grep VAL runs/$name/train.log | tail -n 1)"
