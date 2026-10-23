#!/usr/bin/env bash
# Round 31 (2026-10-21): G22 — v3.7 + ordinary Arabic speech from many people, devices and rooms,
# for acoustic robustness only (diverse_speech.py: FLEURS ar_eg shard_63xx, CC BY 4.0; Common
# Voice 18 Arabic shard_64xx, CC0, <= 3 min per speaker). No transcripts on them: the teacher's
# frames are the target (KL, T=1 — ablation A: T=2 hurt), no Quran CTC; never augmented
# (--real-phone), so teacher and student hear the same real waveform.
# From v3.7 (init/v37), v3.7's own data as the main supervision: per pass the existing 171 h
# (~70%), Tarteel users' phone recordings (data_phone3: random x R60, hard x R61; ~15%) and the
# new speech (x R63 / x R64; ~15%). RetaSy / learners keep their augmentation (ablation A).
# lr 1e-5 (a fine-tune of v3.7, which overfitted past 2,000 steps at 2e-5), 2,000 steps.
#   R63=1 R64=1 R60=2 R61=3 tmux new -d -s round31 'bash gpu/round31.sh 2>&1 | tee -a round31.out'
set -u
cd "$(dirname "$0")/.."
PY=.venv/bin/python
log() { echo "$(date -u +%H:%M) $*" | tee -a round4.log; }
export TEACHER_WEIGHTS=teachers/teacher_ft5.pt MAX_CLIP_S=20
unset TEACHER_SELECT
R60=${R60:-2} R61=${R61:-3} R63=${R63:-1} R64=${R64:-1}
rm -rf data_mix && mkdir data_mix
n=0
for f in data_orig/shard_*.npz; do ln -s "../$f" "data_mix/$(printf 'shard_%04d.npz' $n)"; n=$((n + 1)); done
# NO_DIVERSE=1: G22's control — everything identical, Common Voice and FLEURS left out.
DIVERSE=$([ "${NO_DIVERSE:-0}" = 1 ] || echo "data_diverse/shard_6*.npz")
for f in data_retasy/shard_95*.npz data_learn/shard_9*.npz data_phone3/shard_6*.npz $DIVERSE; do
  ln -s "../$f" "data_mix/$(basename "$f")"
done
ln -s ../data_orig/val.npz data_mix/val.npz
name=${NAME:-G22}
log "$name start from v3.7 ($(ls data_mix/shard_*.npz | wc -l) shards; phone x$R60/x$R61, fleurs x$R63, cv x$R64)"
for ma in 70 56 44 36 30 30; do
  PYTORCH_CUDA_ALLOC_CONF=expandable_segments:True \
  $PY distill_student.py train d6h data_mix runs/$name --max-audio $ma --seed 321 \
    --init init/v37/student.pt --steps 2000 --lr 1e-5 --augment 0.6 --phone-extra \
    --pitch 0.25 --tempo 0.3 --hard 0.75 --focus 0.5 --crop 0.5 \
    --repeat shard_95=16,shard_97=2,shard_98=2,shard_99=2,shard_60=$R60,shard_61=$R61,shard_63=$R63,shard_64=$R64 \
    --real-phone shard_60+shard_61+shard_63+shard_64 \
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
