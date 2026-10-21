---
license: cc-by-4.0
language:
- ar
tags:
- audio
- asr
- quran
- arabic
- speech
- recitation
pretty_name: User Recited Verses Full
---

# User Recited Verses Full

Complete Quranic ayahs, all recordings where BOTH cer_nemo<0.3 AND cer_wav<0.3 (~23h). Highest confidence subset — NeMo and Wav2Vec2 independently agree on the transcription.

## Source

This audio has been cleaned and tested from an old Tarteel audio dataset released publicly.
Audio recordings are from real users reciting Quranic verses, originally collected by the Tarteel project.

The cleaning pipeline applied:
- **Duration filter**: 1.5s–20s trainable window (set 1–3), relaxed for OOD/partial sets
- **Completeness check**: human transcript length ratio vs canonical ayah text (0.85–1.15 for full ayah)
- **ASR quality filter**: two independent models — NeMo FastConformer (Arabic PCD) and Wav2Vec2 (Quran fine-tuned)
- **Corruption check**: every file validated with soundfile before inclusion

## Columns

| Column | Description |
|--------|-------------|
| `audio` | Audio file (16kHz WAV) |
| `text` | Canonical Arabic text of the ayah. |
| `sura` | Surah number (1–114) |
| `ayah` | Ayah number within the surah |
| `duration` | Audio duration in seconds |
| `cer_nemo` | Character error rate vs human transcript (NeMo model) |
| `cer_wav` | Character error rate vs human transcript (Wav2Vec2 model) |
| `completeness` | Ratio of human transcript length to canonical ayah length |

## Dataset Stats

- **Recordings**: 8,950
- **Total audio**: 23.1h
- **Approx size**: 10.74GB
- **Unique ayahs**: 4,491 / 6,236 (72.0% of Quran)
- **Median duration**: 8.4s
- **Median cer_nemo**: 0.092
- **Median cer_wav**: 0.176

## Related Datasets

- [`greentechapps/user_recited_verses_1x`](https://huggingface.co/datasets/greentechapps/user_recited_verses_1x) — 1 recording/ayah, ~3GB
- [`greentechapps/user_recited_verses_2x`](https://huggingface.co/datasets/greentechapps/user_recited_verses_2x) — 2 recordings/ayah
- [`greentechapps/user_recited_verses_full`](https://huggingface.co/datasets/greentechapps/user_recited_verses_full) — both models agree, ~23h
- [`greentechapps/user_recited_verses_partial`](https://huggingface.co/datasets/greentechapps/user_recited_verses_partial) — partial recitations
- [`greentechapps/user_recited_verses_ood`](https://huggingface.co/datasets/greentechapps/user_recited_verses_ood) — out-of-domain/testing
