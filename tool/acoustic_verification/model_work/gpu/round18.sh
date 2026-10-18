#!/usr/bin/env bash
# Round 18 (2026-10-18): G9 — v3.6 (G2e) continued with 3,000 cut-ghunnah pairs
# (ghunnah_cut_data.py: professional clips, each also copied with one ghunnah cut to
# about one count; targets «نننن» / «نن»), their transcripts trusted over the teachers
# (KL x0.3, CTC x8), so the student learns a held ghunnah's length apart from a cut one.
#   tmux new -d -s round18 'bash gpu/round18.sh 2>&1 | tee -a round18.out'
set -u
cd "$(dirname "$0")/.."
log() { echo "$(date -u +%H:%M) $*" | tee -a round4.log; }
if [ ! -f data_gcut/ghunnah_cut.json ]; then
  log "ghunnah pairs start"
  .venv/bin/python ghunnah_cut_data.py data_gcut --clips 3000 > gcut.out 2>&1
  log "ghunnah pairs: $(tail -n 1 gcut.out)"
fi
rm -rf data_mix && mkdir data_mix
n=0
for f in data_orig/shard_*.npz; do ln -s "../$f" "data_mix/$(printf 'shard_%04d.npz' $n)"; n=$((n + 1)); done
for f in data_gcut/shard_93*.npz data_retasy/shard_95*.npz data_learn/shard_9*.npz; do ln -s "../$f" "data_mix/$(basename "$f")"; done
ln -s ../data_orig/val.npz data_mix/val.npz
log "G9 start ($(ls data_mix/shard_*.npz | wc -l) shards)"
PYTORCH_CUDA_ALLOC_CONF=expandable_segments:True \
TEACHER_WEIGHTS=teachers/teacher_ft4.pt,teachers/teacher_ft5.pt TEACHER_SELECT=1 .venv/bin/python distill_student.py train d6h data_mix runs/G9 \
  --init init/G2e/student.pt --steps 6000 --max-audio 70 --lr 2e-5 --augment 0.6 --phone-extra --pitch 0.25 \
  --tempo 0.3 --hard 0.75 --focus 0.5 --crop 0.5 --repeat shard_93=3,shard_95=16,shard_97=2,shard_98=2,shard_99=2 \
  --trust shard_93+shard_95:0.3:8 --guide init/v35s/student.pt:shard_95:0.7 \
  --spike-mode clip --val-every 1000 --save-every 1000 --resume --seed 191 --vowel 1 \
  --stream 0.96,5.12 --stream-chunks 0.64,1.28 > train_G9.out 2>&1
[ -f runs/G9/student.pt ] || { log "G9 FAILED: $(tail -n 1 train_G9.out)"; exit 1; }
mkdir -p out/G9
cp runs/G9/{student.pt,config.json,run.json,train.log} out/G9/
cp init/v35s/fbank_prior.json out/G9/
rm -f runs/G9/checkpoint.pt
log "G9 done: $(grep VAL runs/G9/train.log | tail -n 1)"
