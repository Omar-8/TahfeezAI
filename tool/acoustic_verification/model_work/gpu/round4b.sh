#!/usr/bin/env bash
# Round 4, second part (2026-10-17). A (d6h, 0.64 s chunks) did worse than v3.5, and
# v3.5 itself at 0.64 s also lost a little: the short chunk and the pruning both cost.
#   E  d6h with v3.5's own chunks (0.64-1.28 s, validated at 0.96; the app runs 1.28):
#      the size alone
#   F  E pruned by activity (ffn_activity) and trained 20k steps
# Once round4.sh logs "C done" it is stopped (D is dropped) and E trained.
#   tmux new -d -s round4b 'bash gpu/round4b.sh 2>&1 | tee -a round4b.out'
set -u
cd "$(dirname "$0")/.."
PY=.venv/bin/python
log() { echo "$(date -u +%H:%M) $*" | tee -a round4.log; }

until grep -q "C done" round4.log; do sleep 60; done
tmux kill-session -t round4 2>/dev/null
sleep 5
pkill -f "runs/D" 2>/dev/null
sleep 10
rm -rf runs/D
log "round4.sh stopped after C; E instead of D"

COMMON=(--init init/v35s/student.pt --steps 10000 --max-audio 100 --lr 3e-5 --augment 0.6
        --phone-extra --pitch 0.25 --tempo 0.3 --hard 0.5 --focus 0.5 --crop 0.5
        --repeat shard_95=6 --spike-mode clip --val-every 1000 --save-every 1000 --resume)

student() {   # name size teachers [extra args...]
  local name=$1 size=$2 teachers=$3; shift 3
  [ -f "out/$name/student.pt" ] && { log "$name already done"; return; }
  log "$name start"
  for attempt in 1 2 3; do
    TEACHER_WEIGHTS=$teachers TEACHER_SELECT=1 $PY distill_student.py train "$size" data_mix "runs/$name" \
      "${COMMON[@]}" --seed $((40 + attempt)) "$@" > "train_$name.out" 2>&1
    grep -q "^done" "train_$name.out" && break
    log "$name attempt $attempt ended without done; retrying"
  done
  mkdir -p "out/$name"
  cp "runs/$name"/{student.pt,config.json,run.json,train.log} "out/$name/" 2>/dev/null
  cp init/v35s/fbank_prior.json "out/$name/"
  rm -f "runs/$name/checkpoint.pt"
  log "$name done: $(grep VAL "runs/$name/train.log" | tail -n 1)"
}

T45=teachers/teacher_ft4.pt,teachers/teacher_ft5.pt
student E d6h "$T45" --vowel 1 --stream 0.96,5.12 --stream-chunks 0.64,1.28
# D (teachers ft4 + ft9) dropped: ft9 tested no better than ft5.
# F: E's recipe, pruned by activity on real audio (its start 2.6x closer to v3.5) and
#    trained twice as long.
student F d6h "$T45" --vowel 1 --stream 0.96,5.12 --stream-chunks 0.64,1.28 \
  --prune-by-activity --steps 20000
log "ROUND 4B DONE"
