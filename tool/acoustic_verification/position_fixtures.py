"""Builds the position-tracking fixtures (test/fixtures/acoustic/position/).

Scenarios are composed from real recitation (the clean ayahs of the model
benchmark, 4 reciters) and run through the acoustic model exactly as the
app streams it: elastic windows, 2 s hop, 1 s context each side
(lib/ai/acoustic/acoustic_frame_stream.dart). Stored per scenario: the
stream's frames (float16, gzip) and where each window's kept frames end,
so a test replays the same chunks the device would deliver.

  .venv/bin/python position_fixtures.py <model.onnx> <bench dir> [--rotate N --out DIR]
      [--only NAME]

--only NAME regenerates one scenario, keeping the others in scenarios.json.

--rotate N gives every scenario another reciter (a held-out set, for
checking tuning made on the stored fixtures).
"""
import gzip, json, sys
from pathlib import Path

import numpy as np
import onnxruntime as ort

RATE, FRAME = 16000, 640
MIN_HOP, MAX_HOP, CTX = 2 * RATE, 6 * RATE, 1 * RATE   # the app's windowing (--hop/--ctx override)
OUT = Path(__file__).resolve().parents[2] / 'test/fixtures/acoustic/position'

def silence(s): return np.zeros(int(s * RATE), np.float32)

def main(model, bench, rotate=0, out=None, only=None):
    global OUT
    if out:
        OUT = Path(out); OUT.mkdir(parents=True, exist_ok=True)
    cases = json.load(open(Path(bench) / 'bench_cases.json'))
    audio = np.load(Path(bench) / 'bench_audio.npz')
    clips = {}
    for i, c in enumerate(cases):
        if c['set'] == 'clean':
            clips.setdefault(c['ayahId'], []).append(i)

    def ayah(a, r, cut=(0.0, 1.0)):
        x = audio['c%d' % clips[a][(r + rotate) % 4]]
        return x[int(len(x) * cut[0]):int(len(x) * cut[1])]

    def seq(r, *ayahs, gap=0.3):
        parts = []
        for a in ayahs:
            parts += [ayah(a, r), silence(gap)]
        return parts

    rng = np.random.default_rng(7)
    scenarios = {
        # name: (parts, focus ayahs, anchor ayah, trust anchor, recited ayahs, note)
        'page_start': (seq(0, *range(36001, 36009)), (36001, 36012), 36001, False,
                       list(range(36001, 36009)), 'start of the visible page'),
        'mid_ayah': ([ayah(36003, 1, (0.4, 1.0)), silence(0.3)] + seq(1, 36004, 36005, 36006),
                     (36001, 36012), 36001, False, [36003, 36004, 36005, 36006],
                     'starts mid-ayah (36:3 from 40%)'),
        'ayahs_away': (seq(2, 36009, 36010, 36011, 36012), (36001, 36012), 36001, False,
                       [36009, 36010, 36011, 36012], 'starts 8 ayahs below the page start'),
        'wrong_page': (seq(3, *range(18001, 18006)), (36001, 36012), 36001, False,
                       list(range(18001, 18006)), 'recites Al-Kahf with Ya-Sin on screen'),
        'repeated_then_context': (seq(0, 55013, 55014, 55015, 55016), (55001, 55016), 55001, False,
                                  [55013, 55014, 55015, 55016],
                                  '55:13 = 55:16 word for word; the next ayah decides'),
        'repeated_alone': (seq(1, 55016), (55001, 55016), 55001, False, [55016],
                           'only 55:16, identical to 55:13 on the same page: must not guess'),
        'skip': (seq(1, 36001, 36002, 36004, 36005), (36001, 36012), 36001, True,
                 [36001, 36002, 36004, 36005], 'skips 36:3'),
        'repeat': (seq(2, 36001, 36002, 36003, 36003, 36004), (36001, 36012), 36001, True,
                   [36001, 36002, 36003, 36003, 36004], 'repeats 36:3'),
        'restart': (seq(3, 1001, 1002, 1003, 1004) + seq(3, *range(1001, 1008)), (1001, 1007),
                    1001, True, [1001, 1002, 1003, 1004] + list(range(1001, 1008)),
                    'restarts Al-Fatiha after 1:4'),
        'self_correction': (seq(0, 36001, 36002, 36003) + [ayah(36005, 0, (0, 0.45)), silence(0.4)]
                            + seq(0, 36004, 36005), (36001, 36012), 36001, True,
                            [36001, 36002, 36003, 36004, 36005],
                            'starts 36:5 by mistake after 36:3, then says 36:4'),
        'hesitation': ([ayah(112001, 2), silence(2.0), ayah(112002, 2, (0, 0.35)), silence(0.8)]
                       + seq(2, 112002, 112003, 112004, gap=1.5), (112001, 112004), 112001, True,
                       [112001, 112002, 112003, 112004], 'long pauses and a false start'),
        'page_transition': (seq(1, 1005, 1006, 1007, 2001, 2002, 2003), (1001, 1007), 1005, True,
                            [1005, 1006, 1007, 2001, 2002, 2003],
                            'Al-Fatiha into Al-Baqarah: next page, next surah'),
        'surah_basmala': (seq(1, *range(112001, 112005), 1001, *range(113001, 113006)),
                          (112001, 114006), 112001, True,
                          list(range(112001, 112005)) + list(range(113001, 113006)),
                          'Al-Ikhlas, the basmala, then Al-Falaq'),
        'not_quran': ([(rng.standard_normal(10 * RATE) * 0.02).astype(np.float32)],
                      (36001, 36012), 36001, False, [], 'noise only: nothing may be placed'),
    }

    so = ort.SessionOptions(); so.intra_op_num_threads = 8
    session = ort.InferenceSession(model, so, providers=['CPUExecutionProvider'])
    manifest = {'model': Path(model).name, 'windowing': {'min_hop_s': MIN_HOP / RATE, 'max_hop_s': MAX_HOP / RATE,
                                                       'context_s': CTX / RATE},
                'scenarios': {}}
    if only:
        manifest = json.load(open(OUT / 'scenarios.json'))
        scenarios = {only: scenarios[only]}
    for name, (parts, focus, anchor, trust, recited, note) in scenarios.items():
        x = np.concatenate(parts).astype(np.float32)
        frames, ends = stream(session, x)
        with gzip.open(OUT / f'{name}.f16.gz', 'wb') as f:
            f.write(frames.astype('<f2').tobytes())
        manifest['scenarios'][name] = {
            'note': note, 'seconds': round(len(x) / RATE, 2), 'frames': int(frames.shape[0]),
            'chunk_ends': ends, 'focus': focus, 'anchor': anchor, 'trust_anchor': trust,
            'recited': recited,
        }
        print(name, len(x) / RATE, frames.shape, flush=True)
    json.dump(manifest, open(OUT / 'scenarios.json', 'w'), indent=1)

def stream(session, x):
    """The app's windowing (AcousticWindowing.next) over a finished stream:
    windows as audio arrives in 100 ms pieces, then a flush at the end."""
    done, out, ends, written = 0, [], [], 0
    def window(flush):
        nonlocal done
        keep_start = done * FRAME
        available = written - keep_start - (0 if flush else CTX)
        if available < (FRAME if flush else MIN_HOP):
            return False
        keep_end = keep_start + min(available, MAX_HOP)
        frm = max(0, keep_start - CTX)
        to = min(written, keep_end + CTX)
        f = session.run(None, {'waveform': x[frm:to][None]})[0][0]
        lo, hi = done - frm // FRAME, keep_end // FRAME - frm // FRAME
        out.append(f[lo:hi]); done = keep_end // FRAME; ends.append(done)
        return True
    while written < len(x):
        written = min(len(x), written + RATE // 10)
        window(False)
    while window(True):
        pass
    return np.concatenate(out), ends

if __name__ == '__main__':
    import argparse
    p = argparse.ArgumentParser()
    p.add_argument('model'); p.add_argument('bench')
    p.add_argument('--rotate', type=int, default=0); p.add_argument('--out')
    p.add_argument('--hop', type=float, default=2.0); p.add_argument('--ctx', type=float, default=1.0)
    p.add_argument('--max-hop', type=float, default=6.0)
    p.add_argument('--only')
    a = p.parse_args()
    MIN_HOP, MAX_HOP, CTX = int(a.hop * RATE), int(a.max_hop * RATE), int(a.ctx * RATE)
    main(a.model, a.bench, a.rotate, a.out, a.only)
