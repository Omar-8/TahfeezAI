#!/usr/bin/env bash
# Round 25 (2026-10-20): G16 — G14 pushed further. G14 (v3.6 + real phones, round 24) closed
# little of the gap on real phones (tlog 227 -> 223, owner's sets 40 -> 35, studio through
# the bank 172 -> 160; teacher 132 / 22 / 106) with v3.6's cautious recipe. Here: from G14,
# twice the learning rate and steps, more clips degraded and nearly all of those through a
# real phone, noise down to 0 dB, the crowd's own phone recordings weighed more, and v3.6's
# two teachers back.
#   tmux new -d -s round25 'HF_HOME=/workspace/hf_home bash gpu/round25.sh 2>&1 | tee -a round25.out'
set -u
cd "$(dirname "$0")/.."
PY=.venv/bin/python
log() { echo "$(date -u +%H:%M) $*" | tee -a round4.log; }
# v3.6's own teachers: ft4 and ft5, each clip taking the one that fits it (TEACHER_SELECT).
# G13 and G14 had ft5 alone and both flagged amateurs more (G14 4.6 -> 5.5%, Al-Ikhlas
# caught 12.7 -> 10.6%): only the phone training should differ from v3.6.
export TEACHER_WEIGHTS=teachers/teacher_ft4.pt,teachers/teacher_ft5.pt TEACHER_SELECT=1 MAX_CLIP_S=20
until grep -q "ROUND 24 DONE" round4.log; do sleep 60; done
[ -f out/G14/student.pt ] || { log "G16: no G14"; exit 1; }
until [ -f teachers/teacher_ft4.pt ]; do sleep 30; done      # the laptop's upload
name=G16
log "$name start"
for ma in 70 56 44 36 30 30 30 30; do
  PYTORCH_CUDA_ALLOC_CONF=expandable_segments:True \
  $PY distill_student.py train d6h data_mix runs/$name --max-audio $ma --seed 261 \
    --init out/G14/student.pt --steps 20000 --lr 4e-5 --augment 0.85 --phone-extra --pitch 0.25 \
    --tempo 0.3 --hard 0.75 --focus 0.5 --crop 0.5 \
    --repeat shard_95=24,shard_97=4,shard_98=4,shard_99=4 \
    --trust shard_95:0.2:10 --guide init/v35s/student.pt:shard_95:0.7 \
    --channels channels/phone_channels.npz --channel-share 0.95 --channel-snr 0,25 \
    --spike-mode clip --val-every 1000 --save-every 500 --resume --vowel 1 \
    --stream 0.96,5.12 --stream-chunks 0.64,1.28 >> train_$name.out 2>&1
  [ -f runs/$name/student.pt ] && break
  log "$name stopped at max-audio $ma: $(grep -E 'Error|error' train_$name.out | tail -n 1 | cut -c1-100)"
done
[ -f runs/$name/student.pt ] || { log "$name FAILED"; exit 1; }
mkdir -p out/$name
cp runs/$name/{student.pt,config.json,run.json,train.log} out/$name/
cp init/v35s/fbank_prior.json out/$name/
log "$name done: $(grep VAL runs/$name/train.log | tail -n 1)"
