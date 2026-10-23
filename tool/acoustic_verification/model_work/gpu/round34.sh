#!/usr/bin/env bash
# Round 34 (2026-10-23): G25 — v3.7 trained with TLOG (tarteel-ai/tlog, CC BY 4.0, gated: HF_TOKEN
# of an account that accepted it). Tarteel app users' phone recordings of single ayahs.
#   1. tlog_mine.py: FILES random files of the 411 (0: all), v3.7 as the student; never a clip of
#      the test packs (Tarteel-200 `tlog`, Juz 30 unseen `juz30h`); ECAPA voices (--embed).
#   2. tlog_select.py: test speakers' clips out (TLOG has no user ids: by voice), a held-out
#      validation pack by speaker (tlogdev), a random pool (shard_70) and a pair-balanced hard
#      pool (shard_71: teacher sure, v3.7 wrong; ح→ه ض→د ق→ك ك→ق ء→ي ن→ي خ→ف ث→ت x3).
#   3. Mix per pass: v3.7's own data 171 h ~70%, random TLOG ~15%, hard TLOG ~15% (repeats from
#      the pools' hours). TLOG heard raw (--real-phone: teacher and student the same waveform);
#      the teacher's KL leads, the inferred transcripts only a weak CTC (--ctc-scale 0.3).
#   4. From v3.7, ft5 at T=1, lr 1e-5, up to 3,000 steps; the EMA kept at 1,000 / 2,000 / 3,000
#      (--keep-ema) and judged in order by the stop rules on the laptop.
#   FILES=120 tmux new -d -s round34 'bash gpu/round34.sh 2>&1 | tee -a round34.out'
set -u
cd "$(dirname "$0")/.."
PY=.venv/bin/python
log() { echo "$(date -u +%H:%M) $*" | tee -a round4.log; }
export TEACHER_WEIGHTS=teachers/teacher_ft5.pt MAX_CLIP_S=20
unset TEACHER_SELECT
[ -n "${HF_TOKEN:-}" ] || export HF_TOKEN=$(cat ~/.cache/huggingface/token 2>/dev/null)
[ -n "$HF_TOKEN" ] || { log "G25: no HF_TOKEN"; exit 1; }
until [ -f teachers/teacher_ft5.pt ] && [ -f init/v37/student.pt ] && [ -f init/v35s/student.pt ] \
      && [ "$(ls data_learn/shard_9*.npz 2>/dev/null | wc -l)" -ge 8 ] && [ -f juz30h_cases.json ]; do sleep 30; done
$PY -c "import speechbrain" 2>/dev/null || .venv/bin/pip install -q speechbrain
if [ ! -f data_orig/val.npz ]; then
  log "data_orig start"
  $PY distill_student.py prepare data_orig --hours 80 > prep_orig.out 2>&1
  grep -q '^prepared' prep_orig.out || { log "data_orig FAILED: $(tail -n 1 prep_orig.out)"; exit 1; }
fi
FILES=${FILES:-120}
if ! grep -q '^done' tlog_mine.out 2>/dev/null; then
  log "TLOG mining: $FILES files"
  $PY tlog_mine.py data_tlog_cand --student init/v37/student.pt --test-packs tlog juz30h \
    --files $FILES --embed >> tlog_mine.out 2>&1
  grep -q '^done' tlog_mine.out || { log "TLOG mining FAILED: $(tail -n 1 tlog_mine.out)"; exit 1; }
  log "mined: $(grep '^done' tlog_mine.out)"
fi
if [ ! -f data_tlog/select.json ]; then
  $PY tlog_select.py data_tlog_cand data_tlog 2>&1 | tee -a round4.log
fi
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
name=${NAME:-G25}
log "$name start from v3.7 ($(ls data_mix/shard_*.npz | wc -l) shards; random TLOG x$R70, hard x$R71)"
for ma in 70 56 44 36 30 30; do
  PYTORCH_CUDA_ALLOC_CONF=expandable_segments:True \
  $PY distill_student.py train d6h data_mix runs/$name --max-audio $ma --seed 341 \
    --init init/v37/student.pt --steps 3000 --lr 1e-5 --keep-ema \
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
for st in 1000 2000 3000; do
  mkdir -p out/${name}_$st; cp runs/$name/ema_$st.pt out/${name}_$st/student.pt
  cp runs/$name/config.json out/${name}_$st/; cp init/v35s/fbank_prior.json out/${name}_$st/
done
cp data_tlog/tlogdev_audio.npz data_tlog/tlogdev_cases.json data_tlog/select.json out/ 2>/dev/null
log "$name done: $(grep VAL runs/$name/train.log | tr '\n' ' ' | sed 's/ema kl(T=1) //g')"
