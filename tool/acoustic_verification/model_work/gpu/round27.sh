#!/usr/bin/env bash
# Round 27 (2026-10-20): G18 from G15 — round 26b (G17) without its two teachers.
# G16 (G14 pushed hard: 2x lr and steps, 95% real phones, noise to 0 dB) heard the bank's
# phones best at its halfway point (studio through the bank 146) but other people's phones
# worse than v3.6 (tlog 238 / 227): the bank's few hundred phones learned, not phones.
# G15 (G14's gentle recipe + the teacher's layers, uncropped) was the best balance (tlog 222,
# owner's sets 33, amateurs 4.2%) but caught fewer mistakes (spliced 86.3%), likely from
# losing the crops. Here: from G15, v3.6's two teachers, the crops back with the teacher's
# layers held on them (--hidden on cropped views), and G14's gentle phone dose.
#   tmux new -d -s round27 'HF_HOME=/workspace/hf_home bash gpu/round27.sh 2>&1 | tee -a round27.out'
set -u
cd "$(dirname "$0")/.."
PY=.venv/bin/python
log() { echo "$(date -u +%H:%M) $*" | tee -a round4.log; }
# G17 (two teachers, as v3.6) flagged more on Tarteel users' phones at step 3000 (17.8% of words
# against v3.6 15.6%, beyond noise), as G16 (also two teachers) did; G14 and G15 (ft5 alone)
# stayed level. So ft5 alone: G18 tests the crops + held layers alone.
export TEACHER_WEIGHTS=teachers/teacher_ft5.pt MAX_CLIP_S=20
unset TEACHER_SELECT
[ -f out/G15/student.pt ] || { log "G18: no G15"; exit 1; }
name=G18
rm -rf runs/$name
log "$name start (from G15)"
for ma in 70 56 44 36 30 30 30 30; do
  PYTORCH_CUDA_ALLOC_CONF=expandable_segments:True \
  $PY distill_student.py train d6h data_mix runs/$name --max-audio $ma --seed 281 \
    --init out/G15/student.pt --steps 10000 --lr 2e-5 --hidden 0.5 --augment 0.7 --phone-extra --pitch 0.25 \
    --tempo 0.3 --hard 0.75 --focus 0.5 --crop 0.5 \
    --repeat shard_95=16,shard_97=2,shard_98=2,shard_99=2 \
    --trust shard_95:0.2:10 --guide init/v35s/student.pt:shard_95:0.7 \
    --channels channels/phone_channels.npz --channel-share 0.7 \
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
