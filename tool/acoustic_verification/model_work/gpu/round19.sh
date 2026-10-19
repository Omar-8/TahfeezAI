#!/usr/bin/env bash
# Round 19 (2026-10-19): G10 — v3.6 (G2e) continued on the audio where it is wrong or in
# doubt against its teachers. disagree_mine.py runs the teachers (ft4 + ft5, as in
# training) and the shipped streaming student (r6g2e8, ONNX) over the learner / amateur /
# phone-like pools and lists, per clip, the sounds the teachers are sure of (>= 0.8) that
# the student doubts (< 0.5) — not only its confident errors: «لَمُنقَلِبُونَ» (43:14) was
# flagged live from three such doubts (its hidden noon, second ل, kasra); disagree_shard.py makes the worst clips shard_91NN, oversampled. The
# owner's own sessions (half of them: owner_holdout.json keeps the rest back for judging)
# come mined and sharded from the laptop as data_mined/shard_9190.npz.
#
# Needs in the kit: teachers/teacher_ft4.pt + teacher_ft5.pt, init/G2e, init/v35s,
# artifacts/r6g2e8_acc4.onnx + r6g2e8_stream.json, data_retasy, data_learn, data_real,
# data_juz30, data_mined/shard_9190.npz; data_orig is prepared here if missing (80 h).
#   tmux new -d -s round19 'bash gpu/round19.sh 2>&1 | tee -a round19.out'
set -u
cd "$(dirname "$0")/.."
PY=.venv/bin/python
log() { echo "$(date -u +%H:%M) $*" | tee -a round4.log; }
export TEACHER_WEIGHTS=teachers/teacher_ft4.pt,teachers/teacher_ft5.pt TEACHER_SELECT=1

if [ ! -f data_orig/val.npz ]; then
  log "data_orig start"
  $PY distill_student.py prepare data_orig --hours 80 > prep_orig.out 2>&1
  log "data_orig: $(ls data_orig/shard_*.npz | wc -l) shards"
fi

if [ ! -f mine_pools.done ]; then
  log "mining start"
  $PY disagree_mine.py mine_pools.json artifacts/r6g2e8_acc4.onnx artifacts/r6g2e8_stream.json \
    data_retasy/shard_95*.npz data_learn/shard_9*.npz data_real/shard_96*.npz \
    data_juz30/shard_94*.npz --sure 0.8 --ruled-out 0.5 > mine.out 2>&1 && touch mine_pools.done
  log "mining: $(tail -n 1 mine.out)"
fi
[ -f mine_pools.done ] || { log "mining FAILED: $(tail -n 1 mine.out)"; exit 1; }
$PY disagree_shard.py data_mined mine_pools.json --max-clips 3000 --first 9100 > shard.out 2>&1
log "mined shards: $(tail -n 1 shard.out)"

rm -rf data_mix && mkdir data_mix
n=0
for f in data_orig/shard_*.npz; do ln -s "../$f" "data_mix/$(printf 'shard_%04d.npz' $n)"; n=$((n + 1)); done
for f in data_mined/shard_91*.npz data_retasy/shard_95*.npz data_learn/shard_9*.npz; do
  ln -s "../$f" "data_mix/$(basename "$f")"
done
ln -s ../data_orig/val.npz data_mix/val.npz
log "G10 start ($(ls data_mix/shard_*.npz | wc -l) shards)"
PYTORCH_CUDA_ALLOC_CONF=expandable_segments:True \
$PY distill_student.py train d6h data_mix runs/G10 \
  --init init/G2e/student.pt --steps 6000 --max-audio 70 --lr 2e-5 --augment 0.6 --phone-extra --pitch 0.25 \
  --tempo 0.3 --hard 0.75 --focus 0.5 --crop 0.5 --repeat shard_91=4,shard_95=16,shard_97=2,shard_98=2,shard_99=2 \
  --trust shard_95:0.2:10 --guide init/v35s/student.pt:shard_95:0.7 \
  --spike-mode clip --val-every 1000 --save-every 1000 --resume --seed 201 --vowel 1 \
  --stream 0.96,5.12 --stream-chunks 0.64,1.28 > train_G10.out 2>&1
[ -f runs/G10/student.pt ] || { log "G10 FAILED: $(tail -n 1 train_G10.out)"; exit 1; }
mkdir -p out/G10
cp runs/G10/{student.pt,config.json,run.json,train.log} out/G10/
cp init/v35s/fbank_prior.json out/G10/
cp data_mined/mined_clips.json mine_pools.json out/G10/
rm -f runs/G10/checkpoint.pt
log "G10 done: $(grep VAL runs/G10/train.log | tail -n 1)"
