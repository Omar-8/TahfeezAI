#!/usr/bin/env bash
# Round 24 (2026-10-20): real phones. On Tarteel users' own phones (`tlog`) v3.6 hears 1.7x
# the teacher's wrong letters (227 / 132); on studio audio through the training's simulated
# phone effects only 1.25x — the same as on clean audio: the simulation teaches nothing.
# Through phone_channels.py's bank (2,025 microphone + room responses and 20 min of
# background noise measured on crowd recordings: Juz 30 amateurs, RetaSy, learners; not the
# owner's, whose phone sets stay a test of a phone never measured) the gap is 1.6x.
#   G14: v3.6 (G2e) continued with its own recipe (d6h, ft5 as in G13), only --channels new.
#   G15: G14's recipe + the teacher's layers held (--hidden; uncropped, as --hidden needs).
# Upload first: artifacts/phone_channels_local.npz -> channels/phone_channels.npz, and
# phone_channels.py + distill_student.py.
#   tmux new -d -s round24 'HF_HOME=/root/hf_home bash gpu/round24.sh 2>&1 | tee -a round24.out'
set -u
cd "$(dirname "$0")/.."
PY=.venv/bin/python
log() { echo "$(date -u +%H:%M) $*" | tee -a round4.log; }
export TEACHER_WEIGHTS=teachers/teacher_ft5.pt
export MAX_CLIP_S=20
unset TEACHER_SELECT
[ -f channels/phone_channels.npz ] || { log "R24: channels/phone_channels.npz missing"; exit 1; }
# A fresh machine (2026-10-20, the old one lost): the studio data rebuilt as for round 20,
# and v3.6's own mix — data_orig + RetaSy + learners (no mined clips: those were G10's).
if [ ! -f data_orig/val.npz ]; then
  log "data_orig start"
  # (the dataset library may crash on exit after "prepared": harmless)
  $PY distill_student.py prepare data_orig --hours 80 > prep_orig.out 2>&1
  grep -q '^prepared' prep_orig.out || { log "data_orig FAILED: $(tail -n 1 prep_orig.out)"; exit 1; }
  log "data_orig: $(ls data_orig/shard_*.npz | wc -l) shards"
fi
# The laptop's uploads (rsync renames each file into place only when complete; the
# teacher goes last): the mix must not be built before the crowd shards are in.
until [ -f teachers/teacher_ft5.pt ] && [ -f init/G2e/student.pt ] && [ -f init/v35s/student.pt ]; do sleep 30; done
[ "$(ls data_retasy/shard_95*.npz | wc -l)" -ge 1 ] && [ "$(ls data_learn/shard_9*.npz | wc -l)" -ge 8 ] \
  || { log "R24: crowd shards missing"; exit 1; }
if [ ! -f data_mix/val.npz ]; then
  rm -rf data_mix && mkdir data_mix
  n=0
  for f in data_orig/shard_*.npz; do ln -s "../$f" "data_mix/$(printf 'shard_%04d.npz' $n)"; n=$((n + 1)); done
  for f in data_retasy/shard_95*.npz data_learn/shard_9*.npz; do ln -s "../$f" "data_mix/$(basename "$f")"; done
  ln -s ../data_orig/val.npz data_mix/val.npz
  log "data_mix: $(ls data_mix/shard_*.npz | wc -l) shards"
fi
COMMON=(--init init/G2e/student.pt --steps 10000 --lr 2e-5 --augment 0.7 --phone-extra --pitch 0.25
  --tempo 0.3 --hard 0.75 --focus 0.5 --repeat shard_95=16,shard_97=2,shard_98=2,shard_99=2
  --trust shard_95:0.2:10 --guide init/v35s/student.pt:shard_95:0.7
  --channels channels/phone_channels.npz --channel-share 0.7
  --spike-mode clip --val-every 1000 --save-every 500 --resume --vowel 1
  --stream 0.96,5.12 --stream-chunks 0.64,1.28)

run() {   # run <name> <seed> <extra args...>: resumes, smaller batches after an out-of-memory stop
  name=$1 seed=$2; shift 2
  log "$name start"
  for ma in 70 56 44 36 30 30 30 30; do
    PYTORCH_CUDA_ALLOC_CONF=expandable_segments:True \
    $PY distill_student.py train d6h data_mix runs/$name --max-audio $ma --seed $seed \
      "${COMMON[@]}" "$@" >> train_$name.out 2>&1
    [ -f runs/$name/student.pt ] && break
    log "$name stopped at max-audio $ma: $(grep -E 'Error|error' train_$name.out | tail -n 1 | cut -c1-100)"
  done
  [ -f runs/$name/student.pt ] || { log "$name FAILED"; return 1; }
  mkdir -p out/$name
  cp runs/$name/{student.pt,config.json,run.json,train.log} out/$name/
  cp init/v35s/fbank_prior.json out/$name/
  log "$name done: $(grep VAL runs/$name/train.log | tail -n 1)"
}

run G14 251 --crop 0.5
run G15 252 --crop 0 --hidden 0.5
log "ROUND 24 DONE"
