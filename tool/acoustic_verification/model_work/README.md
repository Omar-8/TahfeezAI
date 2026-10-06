# Acoustic model shrinking — experiments

Research workspace for shrinking the Quran acoustic model (`obadx/muaalem-model-v3_2`). Nothing
here is wired into the app. Large outputs go to `artifacts/` (gitignored).

## Tools

| Script | Purpose |
|---|---|
| `bench_pack.py <eval workspace>` | Packs the fixed benchmark: 744 clips (240 spliced real mistakes + 240 controls, Alafasy; 264 clean ayahs from 4 reciters), 124.5 min. Also marks a 292-clip screening subset. |
| `bench_run.py <model.onnx\|torch> <tag> [--screen]` | Runs a candidate over the benchmark and records load time, peak RAM, RTF and the 8 s timing. |
| `../evaluate.dart <tag>.json <tag>.f32 [--compare ref.json ref.f32] [--screen\|--heldout]` | Scores with the app's own Dart verifier: per-type detection, clean false alarms, and agreement with a reference model. |
| `export_candidates.py fp32 [--drop L,L]` | FP32 ONNX export. 1×1 and stride-2 convolutions are rewritten as MatMul, so they can be quantized too; the 10 unused attribute heads are dropped. |
| `export_candidates.py quant <name> <bits> <block> [--group REGEX=BITS:BLOCK]... [--src dir]` | Weight-only MatMulNBits quantization, optionally mixed per group. The fbank front end always stays FP32. |
| `sensitivity.py` | Per-layer probes: layer skipping, and 2-bit fake quantization per weight group. |
| `distill_student.py <s150\|s100\|s75\|s50\|s25> <out> [--smoke]` | Teacher→student distillation (KL on frame posteriors + CTC on teacher greedy). Needs a GPU. |

Python: the scratch environment used here had `torch` 2.14 CPU, `transformers` 4.57, `quran-muaalem`,
`onnx`, `onnxruntime` 1.30, `onnxscript` and `datasets<4`.

Note: in onnxruntime 1.30, `MatMulNBitsQuantizer(nodes_to_include=…)` is OR-ed with "every MatMul",
so it quantizes everything. Select nodes with `nodes_to_exclude` instead.

## Experiment table (full benchmark, prototype thresholds 2.0)

| Candidate | Params | Precision | Size MB | RTF (16 thr) | 8 s audio | Peak RAM | Clean FP % | Uncertain % | F↔D | D↔K | F↔K | Shadda miss/extra | Consonant | Sukun | Missing vowel | Verdict agreement vs 504 MB |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| teacher FP32 (torch) | 605.8M | FP32 | 2425 (ONNX) | — | — | — | 2.4 | 4.8 | 100 | 90 | 73 | 93/93 | 97 | 23 | 7 | 99.1 |
| **baseline_int4** (current) | 605.8M | 4-bit b32 + FP16 convs | **504.5** | 0.337 | 2.68 s | 2.1 GB | 2.8 | 4.9 | 100 | 93 | 77 | 97/93 | 90 | 17 | 17 | 100 |
| **optimized_int4_b32** | 605.8M | 4-bit b32 everywhere, fbank FP32 | **385.7** | 0.321 | 2.70 s | 2.0 GB | **2.6** | 4.7 | 100 | 93 | 77 | 97/93 | 93 | 20 | 17 | 99.4 |
| **mixed_int2_tolerant** | 605.8M | 2-bit on tolerant groups, else 4-bit b32 | **322.8** | 0.321 | 2.56 s | 1.9 GB | 2.9 | 5.7 | 100 | 90 | 77 | 97/93 | 93 | 17 | 37 | 98.3 |
| optimized_int4_b128 † | 605.8M | 4-bit b128 | 329.1 | 0.333 | 2.61 s | 2.0 GB | 3.2 | 4.5 | — | — | — | — | — | — | — | 99.0 (vs FP32) |
| pruned_mixed_b128 † | 555.5M | 22 layers, b128 + tolerant 2-bit | 264.8 | 0.307 | 2.34 s | 1.8 GB | 3.5 | 5.5 | — | — | — | — | — | — | — | 97.6 (vs FP32) |
| ffn_int2_rest_int4 † | 605.8M | all FFN 2-bit | 259.9 | 0.325 | 2.14 s | 1.8 GB | 4.8 | **18.6** ✗ | — | — | — | — | — | — | — | 95.7 (vs FP32) |
| mini_agpl_int4 (EXPERIMENTAL, AGPL/CC BY-NC) | 116.3M | 4-bit | 98.9 | 0.042 | 0.25 s | 0.5 GB | **9.0** ✗ | 18.0 | 100 | 93 | 83 | 93/87 | 83 | 77 | 63 | 94.0 |
| same, thresholds 5/5, correct −2 | 116.3M | 4-bit | 98.9 | 0.042 | 0.25 s | 0.5 GB | 2.9 | 6.1 | 73 | 77 | 73 | 90/60 | 80 | 60 | 40 | — |

† screened on the 292-clip subset only; there, the 504 MB baseline scored FP 3.1%, uncertain 4.6%.
Agreement is phoneme-verdict agreement (the Dart verifier on both models' outputs). Speeds were
measured on a Ryzen 9 5900HS with ONNX Runtime 1.30, 16 threads, on a shared machine.

ZIP-compressed sizes: 504.5 → 467.2, 385.0 → 357.3, 328.4 → 289.2, 98.9 → 90.7 MB (quantized
weights barely compress).

## Sensitivity (`artifacts/sensitivity.json`)

Top-1 frame agreement with the unmodified model on a 24-clip probe. Harmless changes score ~97–98%.

- **Skipping one layer.** Least important: 7 (98.2), 6 (97.2), 18 (97.0), 5 (97.0). Critical: 8 (85.6),
  0 (88.4), 13–15 (~91), 22 (92.0).
- **2-bit by group.**
  - Tolerant: convolution pointwise projections (all quarters, 96.7–98.7), FFN 18–23 (96.4), attention 6–11 (96.3).
  - Sensitive: attention 0–5 (83.5), FFN 12–17 (88.5), FFN 0–5 (91.8).

## Training data licence (distillation)

| Dataset | Source | Licence tag | Commercial / redistribution / derived models |
|---|---|---|---|
| `obadx/muaalem-annotated-v3` (~850 h) | published recitations from everyayah.com / mp3quran.net, segmented by the Muaalem pipeline | MIT | Recording rights rest with the reciters and publishers and are not established by the tag: **unverified** |
| `obadx/qdat` (1,505 clips) | contributor recordings | MIT | Plausible, but small; provenance not independently verified |
| `FaisaI/tadabur` (used by the mini) | mixed | **CC BY-NC 4.0** | **Non-commercial**: not usable for a shipped model |

Any student trained on these is an **EXPERIMENTAL** result until the audio rights are cleared. The
teacher itself was trained on `muaalem-annotated-v3`, so the same question applies to the model
used today.
