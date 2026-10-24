"""perturb_pack.py [--shift] <pack> [<pack>...]: a copy of each test pack heard a little differently —
a gentle equaliser (bass below 150 Hz down 6 dB, treble above 2.5 kHz up 3 dB, smooth) and
4 dB quieter — as artifacts/<pack>eq_{audio.npz,cases.json}: the same clips, for a second run
whose letter flags must agree with the first (a double check against a phone's own colouring).
--shift: instead, 0.48 s of the clip's own quietest audio put before it (artifacts/<pack>sh_…):
the streaming model's 1.28 s chunks then fall elsewhere in the recitation.
"""
import json, os, sys
import numpy as np

ART = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', 'artifacts')


def colour(x, sr=16000):
    n = len(x)
    f = np.fft.rfftfreq(n, 1 / sr)
    db = -6 / (1 + (f / 150) ** 4) + 3 / (1 + (2500 / np.maximum(f, 1)) ** 4) - 4
    return np.fft.irfft(np.fft.rfft(x) * 10 ** (db / 20), n).astype(np.float32)


def shift(x, n=int(0.48 * 16000)):
    # The quietest 30 ms of the clip, repeated: its own room tone.
    w = 480
    k = min(range(0, max(1, len(x) - w), w), key=lambda i: float(np.square(x[i:i + w]).mean()))
    return np.concatenate([np.tile(x[k:k + w], n // w + 1)[:n], x]).astype(np.float32)


mode = 'sh' if sys.argv[1] == '--shift' else 'eq'
for pack in [p for p in sys.argv[1:] if p != '--shift']:
    audio = np.load(os.path.join(ART, f'{pack}_audio.npz'))
    f = shift if mode == 'sh' else colour
    out = {k: f(audio[k].astype(np.float32)) for k in audio.files}
    np.savez(os.path.join(ART, f'{pack}{mode}_audio.npz'), **out)
    cases = json.load(open(os.path.join(ART, f'{pack}_cases.json')))
    json.dump(cases, open(os.path.join(ART, f'{pack}{mode}_cases.json'), 'w'), ensure_ascii=False)
    print(pack, len(cases), flush=True)
