#!/usr/bin/env bash
# Round 36 (2026-10-24): M2 — mHuBERT-147 (94M, its own pretrained ear intact;
# mhubert_student.py) distilled from ft5 with real phone audio. M1 (round 21, 2026-10-20)
# had no real phone data and matched the cut-down students on the owner's phone (37 letter
# flags, v3.6 40, ft5 22); since then real phone recordings were the one thing that helped
# (v3.7), and every distillation from v3.7 (G25 TLOG, G26 / G26b held layers) only moved along
# its trade-off. M2 asks whether a student that keeps its pretraining does better with them.
#   v3.7's data (orig + RetaSy + learners) + round34.sh's TLOG pools (random x2, hard x1, as
#   G25), TLOG heard raw (--real-phone) with a weak CTC (0.3); ft5 at T=1; offline (whole
#   clips): a test of the student before any streaming / export work.
#   Snapshots at 4k / 8k / 12k; each benched on the test packs here (artifacts/).
#   tmux new -d -s round36 'HF_HOME=/workspace/hf_home bash gpu/round36.sh 2>&1 | tee -a round.out'
set -u
cd "$(dirname "$0")/.."
PY=.venv/bin/python
log() { echo "$(date -u +%H:%M) $*" | tee -a round4.log; }
export TEACHER_WEIGHTS=teachers/teacher_ft5.pt MAX_CLIP_S=20
unset TEACHER_SELECT
[ -f data_tlog/select.json ] || { log "M2: no TLOG pools (round34.sh first)"; exit 1; }
STEPS=${STEPS:-12000}
rm -rf data_mix && mkdir data_mix
n=0
for f in data_orig/shard_*.npz; do ln -s "../$f" "data_mix/$(printf 'shard_%04d.npz' $n)"; n=$((n + 1)); done
for f in data_retasy/shard_95*.npz data_learn/shard_9*.npz data_tlog/shard_7*.npz; do ln -s "../$f" "data_mix/$(basename "$f")"; done
ln -s ../data_orig/val.npz data_mix/val.npz
name=${NAME:-M2}
log "$name start (mHuBERT-147, $(ls data_mix/shard_*.npz | wc -l) shards)"
for attempt in 1 2 3 4 5; do
  PYTORCH_CUDA_ALLOC_CONF=expandable_segments:True \
  $PY mhubert_student.py train data_mix runs/$name --steps $STEPS --max-audio ${MAX_AUDIO:-100} \
    --lr 5e-5 --augment 0.6 --seed 361 --save-every 4000 \
    --repeat shard_95=16,shard_97=2,shard_98=2,shard_99=2,shard_70=2,shard_71=1 \
    --trust shard_95 --real-phone shard_70+shard_71 --ctc-scale shard_70=0.3,shard_71=0.3 \
    >> train_$name.out 2>&1
  [ -f runs/$name/student.pt ] && break
  log "$name attempt $attempt stopped: $(grep -E 'Error|error' train_$name.out | tail -n 1 | cut -c1-120)"
done
[ -f runs/$name/student.pt ] || { log "$name FAILED"; exit 1; }
log "$name trained: $(grep VAL runs/$name/train.log | tail -n 3 | tr '\n' ' ')"
PACKS="tlog phone phone2 phone3 phone4 phone6 phone7 juz30h retasy quranmbh tlogdev ikhlash calib calibdeg errors sessions quranmb"
mkdir -p artifacts/results
for st in $(seq 4000 4000 $STEPS); do
  w=student_$st.pt; [ -f runs/$name/$w ] || w=student.pt
  $PY mhubert_student.py bench runs/$name ${name,,}_$st $(for p in $PACKS; do [ -f artifacts/${p}_cases.json ] && echo $p; done) \
    --weights $w >> bench_$name.out 2>&1 || log "$name bench $st FAILED"
done
log "$name done"
