#!/usr/bin/env bash
# Round 33 (2026-10-21): G24 — v3.7 with a tiny phone adapter (--phone-adapter 64: a residual
# bottleneck after the input projection, frame by frame — streaming unchanged; 132k
# parameters, +0.11 MB quantized, speed unchanged; starts as an exact no-op).
# Trained on v3.7's own Quran data only (no Common Voice / FLEURS / Tadabur): per pass the
# existing 171 h (~69%), Tarteel users' random phone clips (data_phone3 shard_60, 10.4 h x4,
# ~17%) and hard phone clips (shard_61, 5.2 h x7, ~15%), the phone clips raw (teacher and
# student the same waveform); ft5 at T=1, KL the main loss; on the hard clips a small pairwise
# margin (--margin-weight 0.1) where the teacher is sure of a letter and the student's best
# other sound comes close, the remaining confusions (ح→ه ض→د ق→ك ء→ي ن→ي ك→ق) double.
#   G24a: adapter only (lr 1e-4; everything else frozen: --lr 0).
#   G24b: adapter + top encoder layer + head (--train-top 1 --lr 1e-5) — only if G24a falls short.
# 2,000 steps, every 500th step's EMA kept (--keep-ema) and judged by the stop rules after.
#   VARIANT=a tmux new -d -s round33 'bash gpu/round33.sh 2>&1 | tee -a round33.out'
set -u
cd "$(dirname "$0")/.."
PY=.venv/bin/python
log() { echo "$(date -u +%H:%M) $*" | tee -a round4.log; }
export TEACHER_WEIGHTS=teachers/teacher_ft5.pt MAX_CLIP_S=20
unset TEACHER_SELECT
rm -rf data_mix && mkdir data_mix
n=0
for f in data_orig/shard_*.npz; do ln -s "../$f" "data_mix/$(printf 'shard_%04d.npz' $n)"; n=$((n + 1)); done
for f in data_retasy/shard_95*.npz data_learn/shard_9*.npz data_phone3/shard_6*.npz; do ln -s "../$f" "data_mix/$(basename "$f")"; done
ln -s ../data_orig/val.npz data_mix/val.npz
V=${VARIANT:-a}
case $V in
  a) TRAIN="--lr 0" ;;
  b) TRAIN="--lr 1e-5 --train-top 1" ;;
esac
name=G24$V
log "$name start from v3.7 ($(ls data_mix/shard_*.npz | wc -l) shards; $TRAIN)"
for ma in 70 56 44 36 30 30; do
  PYTORCH_CUDA_ALLOC_CONF=expandable_segments:True \
  $PY distill_student.py train d6h data_mix runs/$name --max-audio $ma --seed 331 \
    --init init/v37/student.pt --steps 2000 $TRAIN --phone-adapter 64 --adapter-lr 1e-4 \
    --margin-shards shard_61 --margin-weight 0.1 --keep-ema \
    --augment 0.6 --phone-extra --pitch 0.25 --tempo 0.3 --hard 0.75 --focus 0.5 --crop 0.5 \
    --repeat shard_95=16,shard_97=2,shard_98=2,shard_99=2,shard_60=4,shard_61=7 \
    --real-phone shard_60+shard_61 \
    --trust shard_95:0.2:10 --guide init/v35s/student.pt:shard_95:0.7 \
    --spike-mode clip --val-every 500 --save-every 500 --resume --vowel 1 \
    --stream 0.96,5.12 --stream-chunks 0.64,1.28 >> train_$name.out 2>&1
  [ -f runs/$name/student.pt ] && break
  log "$name stopped at max-audio $ma: $(grep -E 'Error|error' train_$name.out | tail -n 1 | cut -c1-100)"
done
[ -f runs/$name/student.pt ] || { log "$name FAILED"; exit 1; }
for st in 500 1000 1500 2000; do
  mkdir -p out/${name}_$st; cp runs/$name/ema_$st.pt out/${name}_$st/student.pt
  cp runs/$name/config.json out/${name}_$st/; cp init/v35s/fbank_prior.json out/${name}_$st/
done
log "$name done: $(grep VAL runs/$name/train.log | tr '\n' ' ' | sed 's/ema kl(T=1) //g')"
