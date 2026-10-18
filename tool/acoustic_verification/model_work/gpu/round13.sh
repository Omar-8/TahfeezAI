#!/usr/bin/env bash
# Round 13 (2026-10-18): from v3.6 (G2e), one after the other —
#   G4b  G4 with Juz 30 weighed less (x1, v3.5 at 0.6 on it and RetaSy): G4 found as
#        many mistakes as v3.5 on the user and Al-Ikhlas but flagged RetaSy amateurs more
#   G5   no Juz 30; v3.5 a light second teacher on all audio (0.25), on RetaSy 0.7, not
#        on the learners (their mistakes stay with the teachers)
#   tmux new -d -s round13 'bash gpu/round13.sh 2>&1 | tee -a round13.out'
set -u
cd "$(dirname "$0")/.."
log() { echo "$(date -u +%H:%M) $*" | tee -a round4.log; }
mix() {   # shards 9xxx to add to data_orig's
  rm -rf data_mix && mkdir data_mix
  local n=0 f
  for f in data_orig/shard_*.npz; do ln -s "../$f" "data_mix/$(printf 'shard_%04d.npz' $n)"; n=$((n + 1)); done
  for f in "$@"; do ln -s "../$f" "data_mix/$(basename "$f")"; done
  ln -s ../data_orig/val.npz data_mix/val.npz
}
run() {   # name repeat guide seed
  log "$1 start ($(ls data_mix/shard_*.npz | wc -l) shards)"
  TEACHER_WEIGHTS=teachers/teacher_ft4.pt,teachers/teacher_ft5.pt TEACHER_SELECT=1 .venv/bin/python distill_student.py train d6h data_mix "runs/$1" \
    --init init/G2e/student.pt --steps 6000 --max-audio 80 --lr 2e-5 --augment 0.6 --phone-extra --pitch 0.25 \
    --tempo 0.3 --hard 0.75 --focus 0.5 --crop 0.5 --repeat "$2" --trust shard_95:0.2:10 --guide "$3" \
    --spike-mode clip --val-every 1000 --save-every 1000 --resume --seed "$4" --vowel 1 \
    --stream 0.96,5.12 --stream-chunks 0.64,1.28 > "train_$1.out" 2>&1
  mkdir -p "out/$1"
  cp "runs/$1"/{student.pt,config.json,run.json,train.log} "out/$1/" 2>/dev/null
  cp init/v35s/fbank_prior.json "out/$1/"
  rm -f "runs/$1/checkpoint.pt"
  log "$1 done: $(grep VAL "runs/$1/train.log" | tail -n 1)"
}
mix data_juz30/shard_94*.npz data_retasy/shard_95*.npz data_learn/shard_9*.npz
run G4b shard_95=16,shard_97=2,shard_98=2,shard_99=2 init/v35s/student.pt:shard_94+shard_95:0.6 141
mix data_retasy/shard_95*.npz data_learn/shard_9*.npz
run G5 shard_95=16,shard_97=2,shard_98=2,shard_99=2 \
  "init/v35s/student.pt:shard_95=0.7+shard_97=0+shard_98=0+shard_99=0+shard_=0.25:" 151
log "ROUND 13 DONE"
