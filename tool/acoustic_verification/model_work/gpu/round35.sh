#!/usr/bin/env bash
# Round 35 (2026-10-24): G26 — G25 (v3.7 + TLOG, round34.sh's pools, reused) with the teacher's
# layers held as well (--hidden 0.5, on cropped views as in G17/G18). G15/G17/G18 held them only
# on the simulated phone bank; G25 copied the teacher's answers on TLOG but at matched mistake
# detection was no better than v3.7 at threshold 3.4. G26 asks whether the teacher's inner
# picture of real phone audio carries what its answers do not.
#   tmux new -d -s round35 'bash gpu/round35.sh 2>&1 | tee -a round.out'
set -u
cd "$(dirname "$0")/.."
PY=.venv/bin/python
log() { echo "$(date -u +%H:%M) $*" | tee -a round4.log; }
export TEACHER_WEIGHTS=teachers/teacher_ft5.pt MAX_CLIP_S=20
unset TEACHER_SELECT
[ -f data_tlog/select.json ] || { log "G26: no TLOG pools (round34.sh first)"; exit 1; }
STEPS=${STEPS:-3000}
rm -rf data_mix && mkdir data_mix
n=0
for f in data_orig/shard_*.npz; do ln -s "../$f" "data_mix/$(printf 'shard_%04d.npz' $n)"; n=$((n + 1)); done
for f in data_retasy/shard_95*.npz data_learn/shard_9*.npz data_tlog/shard_7*.npz; do ln -s "../$f" "data_mix/$(basename "$f")"; done
ln -s ../data_orig/val.npz data_mix/val.npz
# Repeats for ~70 / 15 / 15 from the hours (existing 171 h with v3.6's repeats).
read R70 R71 <<< "$($PY - <<'EOF'
import glob, numpy as np
h = lambda pat: sum(float(np.diff(np.load(f, allow_pickle=True)['offsets']).sum()) / 16000 / 3600
                    for f in glob.glob(pat))
want = 171.3 / 0.70 * 0.15
print(max(1, round(want / h('data_tlog/shard_70*.npz'))), max(1, round(want / h('data_tlog/shard_71*.npz'))))
EOF
)"
name=${NAME:-G26}
log "$name start from v3.7 ($(ls data_mix/shard_*.npz | wc -l) shards; random TLOG x$R70, hard x$R71)"
for ma in 44 36 30 24 20 16; do       # 24 teacher layers kept: smaller batches
  PYTORCH_CUDA_ALLOC_CONF=expandable_segments:True \
  $PY distill_student.py train d6h data_mix runs/$name --max-audio $ma --seed 351 \
    --init init/v37/student.pt --steps $STEPS --lr 1e-5 --keep-ema --hidden 0.5 \
    --augment 0.6 --phone-extra --pitch 0.25 --tempo 0.3 --hard 0.75 --focus 0.5 --crop 0.5 \
    --repeat shard_95=16,shard_97=2,shard_98=2,shard_99=2,shard_70=$R70,shard_71=$R71 \
    --real-phone shard_70+shard_71 --ctc-scale shard_70=0.3,shard_71=0.3 \
    --trust shard_95:0.2:10 --guide init/v35s/student.pt:shard_95:0.7 \
    --spike-mode clip --val-every 1000 --save-every 1000 --resume --vowel 1 \
    --stream 0.96,5.12 --stream-chunks 0.64,1.28 >> train_$name.out 2>&1
  [ -f runs/$name/student.pt ] && break
  log "$name stopped at max-audio $ma: $(grep -E 'Error|error' train_$name.out | tail -n 1 | cut -c1-100)"
done
[ -f runs/$name/student.pt ] || { log "$name FAILED"; exit 1; }
for st in $(seq 1000 1000 $STEPS); do
  mkdir -p out/${name}_$st; cp runs/$name/ema_$st.pt out/${name}_$st/student.pt
  cp runs/$name/config.json out/${name}_$st/; cp init/v35s/fbank_prior.json out/${name}_$st/
done
log "$name done: $(grep VAL runs/$name/train.log | tr '\n' ' ' | sed 's/ema kl(T=1) //g')"
