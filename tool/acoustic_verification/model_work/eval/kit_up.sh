#!/usr/bin/env bash
# kit_up.sh <port> <host> <round script> [ENV=VAL ...]: a fresh GPU box ready for a round —
# code, setup (gpu/setup.sh), v3.7 / v3.5 / ft5, the crowd shards, the test packs a round
# needs (Tarteel-200, Juz 30 unseen) and the Hugging Face token (never printed); the round
# queued to start once setup and uploads are done.
set -eu
P=$1 H=$2 ROUND=$3; shift 3
cd "$(dirname "$0")/.."
TMP=$(mktemp -d)
tar czf $TMP/kit_code.tgz --exclude=__pycache__ *.py *.json gpu eval
SSH="ssh -p $P -o StrictHostKeyChecking=accept-new root@$H"
$SSH 'mkdir -p /workspace/kit/{teachers,init/v37,init/v35s,data_retasy,data_learn} ~/.cache/huggingface'
scp -P $P -q $TMP/kit_code.tgz ../../../assets/quran/recitation/phonetic_reference_hafs.json \
    artifacts/tlog_audio.npz artifacts/tlog_cases.json artifacts/juz30h_audio.npz artifacts/juz30h_cases.json \
    root@$H:/workspace/kit/
scp -P $P -q ~/.cache/huggingface/token root@$H:/root/.cache/huggingface/token
$SSH 'chmod 600 ~/.cache/huggingface/token; cd /workspace/kit && tar xzf kit_code.tgz &&
      tmux new -d -s setup "bash gpu/setup.sh > setup.out 2>&1; echo SETUP_DONE >> setup.out"'
$SSH "cd /workspace/kit && tmux new -d -s round 'until grep -q SETUP_DONE setup.out; do sleep 20; done; $* HF_HOME=/workspace/hf_home bash gpu/$ROUND 2>&1 | tee -a round.out'"
for src in artifacts/v37/:init/v37/ artifacts/v35s/:init/v35s/ data_retasy/:data_retasy/ data_learn/:data_learn/ \
           artifacts/teachers/teacher_ft5.pt:teachers/; do
  rsync -a --partial -e "ssh -p $P" "${src%%:*}" "root@$H:/workspace/kit/${src#*:}"
done
rm -rf $TMP
echo KIT_UPLOADED
