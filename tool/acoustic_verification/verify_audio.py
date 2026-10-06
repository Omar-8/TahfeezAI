"""Verify a recording against the expected Hafs pronunciation and print the
expected phoneme sequence, the forced alignment and the acoustic scores.

  python verify_audio.py <audio file> <surah> <ayah> [first_word last_word]
         [--model teacher|mini] [--error 2.0] [--letter-error 2.0]

Words are 1-based and select part of the ayah (recite just those words).
Models: `teacher` = obadx/muaalem-model-v3_2 (MIT, 606M params);
`mini` = sysofwan/hifzguide-muaalem-mini (AGPL-3.0; training data
CC BY-NC) — pass its ONNX export with MINI_ONNX=<path>.
"""
import argparse, os, sys
import numpy as np
import librosa

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from acoustic import (Aya, FRAME_S, Thresholds, VOCAB, explain, has_letter,  # noqa: E402
                      reference, unit_variants, verify_ayah)


def log_probs(model, wave):
    if model == 'teacher':
        import torch, torch.nn.functional as F
        from quran_muaalem import Muaalem
        m = Muaalem(model_name_or_path='obadx/muaalem-model-v3_2', device='cpu', dtype=torch.float32)
        f = m.processor([wave], sampling_rate=16000, return_tensors='pt')
        with torch.no_grad():
            return F.log_softmax(m.model(**f, return_dict=False)[0]['phonemes'][0], -1).numpy()
    import onnxruntime as ort
    s = ort.InferenceSession(os.environ['MINI_ONNX'])
    return s.run(None, {'waveform': wave[None].astype(np.float32)})[0][0]


def main():
    p = argparse.ArgumentParser()
    p.add_argument('audio'); p.add_argument('surah', type=int); p.add_argument('ayah', type=int)
    p.add_argument('words', type=int, nargs='*')
    p.add_argument('--model', default='teacher')
    p.add_argument('--error', type=float, default=2.0)
    p.add_argument('--letter-error', type=float, default=2.0)
    a = p.parse_args()
    uth = Aya(a.surah, a.ayah).get().uthmani
    words = [w for w in uth.split(' ') if has_letter(w)]
    toks = reference(uth)
    variants = unit_variants(uth, toks)
    open_start = open_end = False
    if a.words:
        first, last = a.words[0] - 1, (a.words[1] if len(a.words) > 1 else a.words[0]) - 1
        units = {t.unit for t in toks if first <= t.word <= last}
        open_start, open_end = min(units) > 0, max(units) < toks[-1].unit
        toks = [t for t in toks if t.unit in units]
        variants = {u: v for u, v in variants.items() if u in units}
    wave, _ = librosa.load(a.audio, sr=16000, mono=True)
    lp = log_probs(a.model, wave)
    th = Thresholds(error=a.error, letter_error=a.letter_error)
    toks, spans, verdicts = verify_ayah(lp, toks, variants, th, open_start, open_end)
    spans = spans + [None] * (len(verdicts) - len(spans))
    print('expected :', ' '.join(t.sym + ('²' if t.geminate else '') for t in toks))
    greedy, prev = [], 0
    for i in lp.argmax(-1):
        if i and i != prev:
            greedy.append(VOCAB[i])
        prev = i
    print('heard    :', ''.join(greedy), '(free decoding, for reference only)')
    print(f'audio    : {len(wave) / 16000:.1f} s, {len(lp)} frames of {FRAME_S * 1000:.0f} ms, model {a.model}')
    print(explain(toks, spans, verdicts, words))
    errs = [v for v in verdicts if v.kind not in ('CORRECT', 'PAUSE', 'SKIPPED')]
    print('\nsummary  :', 'all correct' if not errs else '')
    for v in errs:
        print(f'  word {v.token.word + 1} {words[v.token.word]}: {v.kind}'
              f"{' heard ' + v.observed if v.kind != 'UNCERTAIN' else ''} (llr {v.llr:.2f})")


if __name__ == '__main__':
    main()
