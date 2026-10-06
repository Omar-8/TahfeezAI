# Quran Acoustic Verification tooling

Prototype and build tools for `docs/ARCHITECTURE.md` §31.

Setup once: `./setup.sh` creates `.venv/` here with the pinned packages in
`requirements.txt` (CPU PyTorch; ~1 GB). Run every tool with
`.venv/bin/python`. The model (~2.4 GB) downloads from Hugging Face on first use.

| Tool | What it does |
|---|---|
| `acoustic.py` | Reference implementation: expected tokens, pause forms, CTC forced alignment, verification. |
| `build_reference.py <repo>` | Builds `assets/quran/recitation/phonetic_reference_hafs.json`. |
| `verify_audio.py <audio> <surah> <ayah> [first last]` | Verifies a recording; prints expected sequence, alignment and scores. |
| `export_model.py <out> [teacher\|mini]` | ONNX export with the fbank front end in-graph, 4-bit weights. |
| `server.py [--port 8790]` | The acoustic model server the app uses (live verification). |

Try your own recitation:

    .venv/bin/python verify_audio.py my_recording.wav 1 2          # all of 1:2
    .venv/bin/python verify_audio.py my_recording.wav 2 255 1 5    # words 1–5 of 2:255

Each line shows: word, source character, expected symbol, kind, time span, the
expected symbol's posterior `p`, the strongest rival symbol, the log-likelihood
ratio of the best alternative over the expected pronunciation (`llr`; ≥ 2 is a
mistake, ≤ −1 correct, between uncertain) and the verdict.

## Live verification in the app

    ./setup.sh                                   # once
    .venv/bin/python server.py --port 8790       # model server
    flutter run -d chrome                   # the app uses http://127.0.0.1:8790 by default

Open a surah, start reciting. Words the audio heard mispronounced turn orange; the status
strip says what was heard. For another server:
`--dart-define=TAHFEEZ_ACOUSTIC_URL=https://host:port` (empty turns verification off).
