# Acoustic model v3.7

**v3.7** checks pronunciation on the device: a 6-layer streaming student
distilled from the Muaalem teacher. It is v3.6 fine-tuned on real users' phone
recordings, with its vowel margins recalibrated. It was named v3.7 by the owner
on 2026-10-21.

**Status, 2026-10-21:** on trial on the owner's phone. It is not yet in a
release; v3.6 is still `model-v3.6`.

| | |
|---|---|
| Manifest id | `tahfeez-d6h-v3.7-stream1.28-int4ffn8-b128-acc4` |
| File | `assets/models/quran_acoustic.onnx`, 91,426,529 bytes, SHA-256 `7cbe486f61e693aa1ed028e696186ac675f0a009e88f2f9fd264439efa5f0157` |
| Architecture | Unchanged from v3.6: d6h (6 encoder layers, FFN 2048, 115.9M parameters), streaming with 1.28 s chunks and 5.12 s of past context, 43 classes, 40 ms frames |
| Quantization | Unchanged: 4-bit weights in blocks of 128, feed-forward layers 8-bit, accuracy_level 4 |
| Size and speed on the phone | The same as v3.6 |
| Built as | G19 at step 2,000 (round 28, `gpu/round28.sh`) |
| Teacher | `teacher_ft5.pt`, Muaalem `obadx/muaalem-model-v3_2` (MIT) fine-tuned |

Checkpoints and files are not in git: `artifacts/v37/` (`student.pt`, `config.json`,
`fbank_prior.json`), `artifacts/v37_b128_acc4.onnx` and `artifacts/v37_stream.json`.
Results packs are tagged `g19a`.

## Why

v3.6 flagged correctly pronounced letters on phone recordings far more often than
its teacher did:

| False letter flags in correct recitation | Teacher | v3.6 |
|---|---:|---:|
| Owner's six phone sets | 22 | 40 |
| Tarteel-200: other users' phones (Quran-Lab `tlog_holdout`) | 132 | 227 |

The gap is about phones in general, not one voice. Bigger students (G12, G13)
and simulated phone sound (G14–G18) did not close it. Real phone recordings did.

## What changed from v3.6

### 1. Fine-tuned on real phone recordings

**Data.** `greentechapps/user_recited_verses_full` (CC BY 4.0): 8,950 recordings
of single ayahs by Tarteel users, 23 h. `phone_mine.py` processed every recording:

- **Overlap with the test set.** Each recording was compared against the
  Tarteel-200 test clips by ayah, length and waveform correlation (≥ 0.8). 20
  of the 200 test clips were in the dataset and were removed from training.
- **Benchmark ayahs.** Ayahs used by the spliced-mistake benchmark were skipped
  (`blocked_ayahs.json`): 1,473 recordings.
- **Alignment.** The teacher was force-aligned to the ayah's expected Hafs
  sounds. Recordings with a mean cost above 0.6 per frame were dropped: 445
  (another ayah, noise, a broken file).
- **Hard letters.** For each expected letter the teacher is sure of
  (probability ≥ 0.8), the miner checks whether v3.6, run as it streams in the
  app, prefers another letter over that letter's span.

7,012 recordings (18.3 h) were kept. `phone_select.py` split them into:

- **Hard:** 1,966 clips (6.1 h) with a confusion of margin ≥ 0.2, or one of the
  tracked pairs (ذ→ل خ→ف ث→ت ص→س ض→د ط→ت ظ→ذ ق→ك ح→ه). Shards `shard_61xx`.
- **Random real phone:** the other 5,046 clips (12.2 h). Shards `shard_60xx`.

**Mix per pass** (hours × repeat):

| Part | Hours × repeat | Share |
|---|---|---:|
| v3.6's own data (80 h studio, RetaSy ×16, learners ×2) | 171 h | 66.7% |
| Random real phone | 12.2 h × 4 | 19.0% |
| Hard real phone | 6.1 h × 6 | 14.3% |

**Training.** `gpu/round28.sh` started from v3.6 (`init/G2e/student.pt`):

- **Teacher:** ft5 alone.
- **Learning rate and steps:** 2e-5 on a 5,000-step cosine schedule, paused at
  step 2,000 (`--pause-at`). v3.7 is that step's EMA weights.
- **Recipe otherwise:** v3.6's (crops, streaming chunks, trust and guide on
  RetaSy, vowel and hard-sound weighting).
- **Real phone clips are never augmented** (`--real-phone shard_60+shard_61`):
  no simulated phone effects, tempo or pitch. Teacher and student hear the same
  real waveform.
- **No CTC on the phone clips.** They carry no transcript, because the users
  may have made real mistakes, so the teacher's KL is the only target there.
- **No simulated phone bank** (`--channels` off).

Training on to 5,000 steps made it worse (owner 45, amateurs 5.1%), so step
2,000 was kept.

### 2. Vowel margins recalibrated

The fine-tune hears vowels slightly more leniently. Recovering the mistakes this
missed needed **only the vowel margins** to change (`learnerSounds` in
`lib/features/recitation/application/acoustic_verification_controller.dart`):

| Sound group | v3.6 | v3.7 |
|---|---:|---:|
| reducedVowel (error margin) | +1 | **0** |
| finalVowel (a unit's last vowel) | +2 | **+1** |
| wordFinalVowel (a case ending) | −1 | **−2.4** (−2 until the 3.4 threshold) |
| similarLetter (letters that sound alike), ayah and quick check | +2 | **+4** |
| phoneWeak (new: ح→ه ض→د ق→ك ء→ي ن→ي ك→ق خ→ف ظ→ض ل→ذ, one direction each), ayah and quick check | — | **+2** |
| Letters, vowels, shadda (threshold) | 3 | **3.4** (2026-10-24) |
| Sukun, missing vowel (threshold 3), hiddenNasal −1 | unchanged | unchanged |

**Similar letters at +4** (added 2026-10-21): false letter flags on phones drop further
(the owner's sets 31 → 30, Tarteel-200 205 → 200, Juz 30 unseen reciters 1,759 → 1,678,
71% of the gap to the teacher closed there) and no real mistake was lost on any test:
sobolev's reviewed letter mistakes caught 16 → 16 (ص→س, ق→ك, ح→خ among them), QuranMB,
Al-Ikhlas, the spliced pairs, amateurs' and the owner's correct words unchanged. A
similar-letter mistake said only slightly wrong could still slip through; the phone trial
checks that.

**Phone-weak pairs at +2** (owner's decision, 2026-10-21): the letters v3.7 most often
hears wrongly on phones while said right, each in one direction. False letter flags on
phones: owner's sets 30 → 29, Tarteel-200 200 → 187, Juz 30 unseen 1,678 → 1,576 (below the
teacher's 1,606 there). Cost: QuranMB real mistakes caught 66.7 → 66.4%, Al-Ikhlas 12.7 →
12.4%; sobolev's reviewed mistakes, the spliced pairs and phone-degraded pairs unchanged.
Several of these pairs (ق→ك, ض→د, ح→ه) are classic real learner mistakes, so a learner who
says them only slightly wrong is now less likely to be flagged. (+4 would give Tarteel-200
180 and QuranMB 66.2%.)

**Pronunciation strictness** (Hifz settings, 2026-10-23; owner's request): one choice shifts every
threshold together, tajweed included — lenient +1 (qalqala +1, madd short below 55%, ghunnah
hold x1.25), balanced as above, precise -0.5 (madd 72%, ghunnah x0.85); the sound-group
margins stay on top (`AcousticVerificationController.withStrictness`):

| v3.7 | Owner / Tarteel-200 / Juz 30 false letters | QuranMB caught | Al-Ikhlas caught | Amateurs flagged | Spliced caught |
|---|---|---:|---:|---:|---:|
| Lenient | 19 / 130 / 1,020 | 59.8% | 9.9% | 2.5% | 83.5% |
| Balanced | 25 / 165 / 1,404 | 65.5% | 12.0% | 3.8% | 88.7% |
| Precise | 30 / 194 / 1,631 | 67.2% | 13.1% | 5.1% | 89.5% |

At the threshold 3 (2026-10-23 to 2026-10-24): lenient 19 / 141 / 1,157, 61.7%; balanced
29 / 187 / 1,576, 66.4%, Al-Ikhlas 12.4%, amateurs 4.2%; precise 35 / 217 / 1,837, 68.4%.

**Threshold 3.4** (owner's decision, 2026-10-24): letters, vowels and shadda at 3.4 instead of
3; case endings kept at 1 (wordFinalVowel −2.4: u→a caught 17 of 21 as before). False letter
flags owner 29 → 25, Tarteel-200 187 → 165, Juz 30 unseen 1,576 → 1,404, TLOG held-out
speakers 451 → 390; correct words flagged, owner's sessions 4.5 → 4.0%, amateurs 4.2 →
3.8%, professionals 1.7 → 1.5%. Cost: QuranMB 66.4 → 65.5%, Al-Ikhlas 12.4 → 12.0%,
sobolev's reviewed 42.1% unchanged, spliced 89.5 → 88.7%, degraded 89.1 → 87.9%. G25 (v3.7
trained further on 120 files of TLOG) reached 26 / 170 / 1,416 at QuranMB 64.7%: this
threshold alone does as well or better on every test.

Lowering the overall threshold instead (2.75) gave back the whole phone gain
(owner 37, Tarteel 226). Stronger vowel margins (−0.5 / +0.5 / −2.5) caught
QuranMB 67.2% but flagged amateurs 5.1%.

## Results

Every model was run as shipped (4-bit FFN-8, streaming) and judged at its own app
settings.

| | Teacher | v3.6 | **v3.7** |
|---|---:|---:|---:|
| **Phone robustness** | | | |
| Owner's six phone sets: false letter flags | 22 | 40 | **31** |
| Tarteel-200: false letter flags | 132 | 227 | **205** |
| Tarteel-200: words flagged, speaker bootstrap ¹ | | 15.6% | **14.1%** (−2.3 to −0.5, real) |
| **Correct words flagged** | | | |
| Owner's sessions | | 5.2% | **4.6%** |
| Amateurs (RetaSy) | | 4.2% | **4.2%** |
| Professionals | | 2.0% | **1.8%** |
| QuranMB held-out | | 30.0% | **29.7%** |
| Al-Ikhlas held-out | | 2.4% | **2.6%** |
| **Mistakes caught** | | | |
| QuranMB held-out, real mistakes | | **68.1%** | 66.7% |
| Al-Ikhlas held-out, real mistakes | | 12.7% | **12.7%** |
| Spliced minimal pairs, clean | | 88.7% | **89.5%** |
| Spliced minimal pairs, phone-degraded | | 87.9% | **89.1%** |
| **Case endings** (word-final vowels, at the app's effective threshold) | | | |
| -u said as -a, caught | | 13/21 | **17/21** |
| Every word-final vowel swap, caught | | 84.1% (69/82) | **92.7% (76/82)** |
| Owner's correct word-final vowels flagged | | 6/13 | **3/12** |

¹ Measured before the vowel recalibration, which does not change letters.

**Letter confusions** (owner's sets plus Tarteel-200; teacher: fp32 on the
owner's sets, 4-bit on Tarteel-200):

| Confusion | Teacher | v3.6 | v3.7 |
|---|---:|---:|---:|
| ذ→ل | 1 | 0 | 0 |
| خ→ف | 0 | 2 | 0 |
| ث→ت | 1 | 1 | 0 |
| ص→س | 2 | 0 | 1 |
| ض→د | 1 | 3 | 3 |
| ط→ت | 5 | 3 | 3 |
| ق→ك | 1 | 5 | 2 |
| ح→ه | 4 | 6 | 6 |
| ظ→ض | 2 | 4 | 1 |
| ء→ي | 1 | 11 | 9 |
| ل→ن | 1 | 5 | 3 |
| ل→ذ | 1 | 4 | 2 |
| ں→ن (hidden noon heard as clear) | 17 | 17 | 15 |
| ن→ي | 0 | 4 | 5 |
| **All letters** | **154** | **267** | **236** |

**Known weaknesses**

- **Still well above the teacher on other people's phones:** 205 against 132.
- **ح→ه and ض→د are unchanged.** ن→ي is slightly worse.
- **The hidden noon heard as a clear ن** remains the most common flag. The
  teacher has it too.
- **QuranMB real mistakes are 1.4 points below v3.6.** Bootstrap over its 9
  speakers: −4.2 to −0.5 before the recalibration.

## What did not work (2026-10-19 to 2026-10-21)

| Run | Idea | Outcome |
|---|---|---|
| G10, G11 | Hard-clip mining; 8 layers | No real gain |
| G12, G13 | 12 layers (fresh cut; v3.6 grown with ft5's layers) | Owner letters 40 → 29, but amateurs flagged more, fewer mistakes caught, no gain on Tarteel-200, half the speed |
| M1 | mHuBERT-147 base | Same failure |
| G14, G15 | Simulated real phones: a bank of 2,025 crowd microphone/room responses plus real noise (`phone_channels.py`, `--channels`); G15 added `--hidden` | Level with v3.6 within noise |
| G16–G18 | The bank, stronger dose / two teachers / crops with `--hidden` | Worse on Tarteel-200 with more training: the bank's few hundred phones were learned, not phones in general |
| G19 @5k | v3.7's run continued | Owner 45, amateurs 5.1%: overfitting |
| G20 | From v3.7's weights: lr 8e-6, top 3 layers only (`--train-top 3`), balanced hard pairs re-mined with G19@2k (`phone_select.py --balanced`) | Identical to G19@2k at step 500; stopped there by the owner's rule (QuranMB 66.2 → 65.9) |

**Lesson:** real recordings of real people on real phones moved the gap.
Simulated phone sound, size, and more training on the same few phones did not.
More real phone audio (e.g. Tarteel's TLOG, CC BY 4.0, gated) is the next lever.

## Reproduce

On a GPU machine (`gpu/setup.sh`), with v3.6's kit (`init/G2e`, `init/v35s`,
`teachers/teacher_ft5.pt`, `data_mix` as in `gpu/round24.sh`):

```sh
TEACHER_WEIGHTS=teachers/teacher_ft5.pt python phone_mine.py data_phone_cand \
    --student init/G2e/student.pt --test tlog_audio.npz tlog_cases.json
python phone_select.py data_phone_cand data_phone
PAUSE=2000 bash gpu/round28.sh          # -> out/G19_2000/student.pt (v3.7's weights)
```

On the laptop, export as shipped, write the manifest, and evaluate:

```sh
python stream_model.py artifacts/v37 --export artifacts/fp32_v37 --chunk 1.28 --left 5.12
python export_candidates.py quant v37_b128 4 128 --src fp32_v37 --group 'ffn=8:128'
python set_accuracy_level.py artifacts/v37_b128.onnx artifacts/v37_b128_acc4.onnx --level 4
python3 ../model_manifest.py artifacts/v37_b128_acc4.onnx \
    --id tahfeez-d6h-v3.7-stream1.28-int4ffn8-b128-acc4 \
    --stream artifacts/fp32_v37/stream.json --out ../../../assets/models
bash eval_candidate.sh artifacts/v37 v37 1.28        # every test pack
dart run tool/acoustic_verification/letter_confusions.dart v37 v36+s2 tlog --all
dart run tool/acoustic_verification/bootstrap.dart r6g2e8=v36+s2 v37=v36+s2
dart run tool/acoustic_verification/final_vowels.dart v37
```

## Licensing

The training audio added for v3.7 is CC BY 4.0, credited to greentechapps and,
as the original collector, the Tarteel project. See
`docs/THIRD_PARTY_RESOURCES.md` → "v3.7" and the saved card in
`docs/licensing-evidence/model/`. The model stays **experimental**: some of
v3.6's training audio has unresolved rights, as recorded there.
