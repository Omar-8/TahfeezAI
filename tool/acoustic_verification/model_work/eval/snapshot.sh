#!/usr/bin/env bash
# snapshot.sh <run dir> <tag> [baseline tag=g19a]: one candidate (student.pt, config.json,
# fbank_prior.json) exported as the app ships it (streaming 1.28 s, 4-bit b128 with 8-bit FFN,
# accuracy level 4), run over the test packs, then every G-round measure against the baseline
# (v3.7, results tagged g19a), all at the app's settings on branch model-v3.7: threshold 3,
# similar letters +4, phone-weak pairs +2, v3.7's vowel margins.
#   PACKS="..." to run fewer packs; QUICK=1: the phone tests, RetaSy and QuranMB only.
set -u
run=$1 tag=$2 base=${3:-g19a}
cd "$(dirname "$0")/.."
PY=../.venv/bin/python
if [ ! -f artifacts/${tag}_b128_acc4.onnx ]; then
  rm -rf artifacts/fp32_$tag
  $PY stream_model.py $run --export artifacts/fp32_$tag --chunk 1.28 --left 5.12 2>&1 | grep -E 'Error|lacks'
  $PY export_candidates.py quant ${tag}_b128 4 128 --src fp32_$tag --group 'ffn=8:128' >/dev/null 2>&1
  $PY set_accuracy_level.py artifacts/${tag}_b128.onnx artifacts/${tag}_b128_acc4.onnx --level 4 >/dev/null
  cp artifacts/fp32_$tag/stream.json artifacts/${tag}_stream.json
  rm -rf artifacts/fp32_$tag artifacts/${tag}_b128.onnx
fi
QUICK_PACKS="tlog phone phone2 phone3 phone4 phone6 phone7 juz30h retasy quranmbh"
FULL_PACKS="$QUICK_PACKS ikhlash calib calibdeg quranmb sessions errors"
[ -f artifacts/tlogdev_cases.json ] && FULL_PACKS="$FULL_PACKS tlogdev" && QUICK_PACKS="$QUICK_PACKS tlogdev"
PACKS=${PACKS:-$([ "${QUICK:-0}" = 1 ] && echo "$QUICK_PACKS" || echo "$FULL_PACKS")}
for p in $(echo $PACKS); do
  [ -f artifacts/results/${p}_$tag.json ] && continue
  STREAM_CFG=artifacts/${tag}_stream.json $PY bench_run.py artifacts/${tag}_b128_acc4.onnx ${p}_$tag --pack $p >/dev/null 2>&1 \
    || echo "FAILED $p"
done
cd ../../..
T=tool/acoustic_verification; R=$T/model_work/artifacts/results
APP="shadda=0/2,qalqala=2/4,nasal=0/2,hiddenNasal=-1/0,throat=0/2,stopInFlow=1/0,reducedVowel=0/2,finalVowel=1/2,wordFinalVowel=-2/0,similarLetter=4/0,phoneWeak=2/2"
letters() { dart run $T/letter_confusions.dart $1 v36+s4+w2 $(echo $2) 2>&1 | grep -o '[0-9]* heard as another' | grep -o '^[0-9]*'; }
caught() { dart run $T/real_mistakes.dart $R/$2_$1.json $R/$2_$1.f32 --minor 3 --error 3 --margins "$APP" 2>/dev/null \
  | grep -oE "wrong word [0-9.]+%|flagged [0-9.]+%" | grep -oE "[0-9.]+" | tr '\n' '/'; }
for t in $base $tag; do
  dev=$([ -f $R/tlogdev_$t.json ] && letters $t tlogdev || echo -)
  echo "== $t | false letters: owner $(letters $t 'phone phone2 phone3 phone4 phone6 phone7') | Tarteel-200 $(letters $t tlog) | Juz30 unseen $(letters $t juz30h) | TLOG held-out $dev"
  echo "   QuranMB caught/flagged $(caught $t quranmbh)"
  if [ "${QUICK:-0}" != 1 ]; then
    echo "   Al-Ikhlas caught/flagged $(caught $t ikhlash) | errors set $(caught $t errors)"
    row=$(dart run $T/tune_sound_margins.dart $t --error 3 --minor 3 --pause 4 --margins "$APP" 2>/dev/null | grep -A1 "^setting" | tail -n 1 | sed "s/as given *//")
    echo "   correct flagged: owner sessions ${row%%/*}% | amateurs $(echo "$row" | awk '{print $3}' | tr -d /)% | pros $(echo "$row" | awk '{print $8}' | tr -d /)%; spliced caught $(echo "$row" | awk '{print $7}')% | degraded $(echo "$row" | awk '{print $10}')%"
    echo "   case endings (u→a, at the app's word-final threshold 1): $(dart run $T/final_vowels.dart $t 2>/dev/null | grep -E 'u→a:' | head -1 | grep -oE 'at 1 [0-9.]+% \([0-9]+/[0-9]+\)')"
  fi
done
dart run $T/bootstrap.dart r6g2e8=v36+s2 $base=v36+s2 $tag=v36+s2 --n 1000 2>&1 | grep -E "^(measure|amateur|juz30|tlog|qmb )"
echo SNAPSHOT_DONE $tag
