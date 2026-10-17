#!/usr/bin/env bash
# A candidate's key measures beside another's (default v35ss: v3.5 as shipped), from
# the packs eval_candidate.sh wrote:
#   bash compare_candidate.sh <tag> [base tag=v35ss]
# - mine / amateur / spliced mistakes (tune_sound_margins.dart: words flagged on the
#   user's correct recitation and amateurs', mistakes found)
# - QuranMB: clips with a real mistake flagged, correct words flagged (evaluate.dart)
# - case endings: word-final vowel swaps caught (final_vowels.dart)
# - QDAT held-out: ikhfa / ghunnah / separate madd (qdat_rules.dart)
# - Al-Ikhlas held-out: qalqala caught against correct qalqala flagged
set -uo pipefail
cd "$(dirname "$0")/../../.."
tag=$1 base=${2:-v35ss}
R=tool/acoustic_verification/model_work/artifacts/results
T=tool/acoustic_verification
for t in "$base" "$tag"; do
  echo "================ $t"
  dart run $T/tune_sound_margins.dart "$t" --error 4 --minor 2 2>/dev/null | grep -A1 '^setting' | tail -n 1 \
    | sed 's/^/ mine|amateur|calib: /'
  dart run $T/evaluate.dart "$R/quranmb_$t.json" "$R/quranmb_$t.f32" 2>/dev/null \
    | grep -E 'quranmb_mistake|clean all' | sed 's/^/ QuranMB: /'
  dart run $T/final_vowels.dart "$t" 2>/dev/null | grep -E '(a|i|u)→(a|i|u):' | sed 's/^/ case ending: /'
  dart run $T/qdat_rules.dart "$t" --pack qdath 2>/dev/null | grep -E 'missed|applied' | sed 's/^/ QDAT: /'
  dart run $T/qalqala_threshold.dart "$t" ikhlash 2>/dev/null | sed 's/^/ qalqala thr caught false: /'
done
