#!/usr/bin/env bash
# Round 4 (2026-10-17): a smaller, faster-answering student, case endings, and a
# rule-local teacher. EXPERIMENTAL / NOT YET CLEARED FOR DISTRIBUTION (training
# audio rights: docs/THIRD_PARTY_RESOURCES.md).
#
# Runs on the rented GPU from the kit directory (model_work's scripts, plus
# teachers/teacher_ft4.pt + teacher_ft5.pt, init/v35s, data_real, data_retasy),
# after these were started (they run beside it):
#   distill_student.py prepare data_orig --hours 80
#   diverse_data.py data_diverse --part 0..3 --parts 4 --hours-per-reciter 1.4
# Every student starts from v3.5 (init/v35s) with its recipe (seed aside) and is
# trained with chunks drawn from 0.48-0.96 s (validated at 0.64 s):
#   A  d6h (feed-forward 4096 -> 2048, pruned from v3.5), teachers ft4 + ft5
#   B  A + --vowel 1 (short-vowel frames weigh more: case endings)
#   C  B at full size (d6): what the pruning costs
#   D  B with teachers ft4 + ft9 (ft9: rule-local, finetune_teacher.py --rule-local)
# Each result goes to out/<name> (student.pt, config.json, run.json, train.log);
# the laptop exports, quantizes and judges them against v3.5.
#   tmux new -d -s round4 'bash gpu/round4.sh 2>&1 | tee -a round4.out'
set -u
cd "$(dirname "$0")/.."
PY=.venv/bin/python
log() { echo "$(date -u +%H:%M) $*" | tee -a round4.log; }

wait_for() {   # a file's last line matching a pattern
  until grep -q "$2" "$1" 2>/dev/null; do sleep 60; done
}

# 1. Data: the 80 h of muaalem, the extra reciters, then v3.5's mix (no learner clips).
wait_for prep_orig.out '^prepared'
log "data_orig ready: $(ls data_orig/shard_*.npz | wc -l) shards"

# 2. The rule-local teacher, while the extra reciters are still being aligned.
if [ ! -f teachers/teacher_ft9.pt ]; then
  log "ft9 start (rule-local)"
  # (Half ft5's audio per step: the reciter builders share the GPU meanwhile.)
  PYTORCH_CUDA_ALLOC_CONF=expandable_segments:True \
  $PY finetune_teacher.py teachers/teacher_ft9.pt.tmp --data data_orig --amateur data_retasy \
    --no-nasal --real data_real --anchor teachers/teacher_ft4.pt --rule-local --steps 4000 \
    --max-audio 60 > ft9.log 2>&1 && mv teachers/teacher_ft9.pt.tmp teachers/teacher_ft9.pt
  log "ft9: $(tail -n 1 ft9.log)"
fi

# (Four builders, 1.4 h per reciter: diverse_data.py --part 0-3 --parts 4.)
until [ "$(grep -l '^done' prep_div0.out prep_div1.out prep_div2.out prep_div3.out 2>/dev/null | wc -l)" -eq 4 ]; do
  sleep 60
done
log "data_diverse ready: $(ls data_diverse/shard_*.npz | wc -l) shards"

rm -rf data_mix && mkdir data_mix
n=0
for f in data_orig/shard_*.npz; do ln -s "../$f" "data_mix/$(printf 'shard_%04d.npz' $n)"; n=$((n + 1)); done
n=200
for f in data_diverse/shard_*.npz; do ln -s "../$f" "data_mix/$(printf 'shard_%04d.npz' $n)"; n=$((n + 1)); done
for f in data_retasy/shard_95*.npz; do ln -s "../$f" "data_mix/$(basename "$f")"; done
ln -s ../data_orig/val.npz data_mix/val.npz
log "mix: $(ls data_mix/shard_*.npz | wc -l) shards"

# 3. Students, one after another.
COMMON=(--init init/v35s/student.pt --steps 10000 --max-audio 100 --lr 3e-5 --augment 0.6
        --phone-extra --pitch 0.25 --tempo 0.3 --hard 0.5 --focus 0.5 --crop 0.5
        --repeat shard_95=6 --stream 0.64,5.12 --stream-chunks 0.48,0.96 --spike-mode clip
        --val-every 1000 --save-every 1000 --resume)

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
student A d6h "$T45"
student B d6h "$T45" --vowel 1
student C d6 "$T45" --vowel 1
if [ -f teachers/teacher_ft9.pt ]; then
  student D d6h teachers/teacher_ft4.pt,teachers/teacher_ft9.pt --vowel 1
fi
log "ALL DONE"
