"""Automated check: codec-degraded student audio is aligned with the clean audio.

For every codec configuration and clips from 1 s to 20 s:
- exactly the clean sample count;
- the cross-correlation lag after correction is within 2 samples (0.125 ms);
- on a synthetic click train, each click is reproduced within +-1 ms (16 samples);
- 40 ms frame energy envelopes of clean and degraded audio peak in the same frames.
Run on the machine that builds the pool (its ffmpeg):  python test_codec_alignment.py
"""
import os, sys
import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import codec  # noqa: E402

RATE, FRAME = 16000, 640


def speechlike(seconds, seed):
    rng = np.random.default_rng(seed)
    n = int(seconds * RATE)
    t = np.arange(n) / RATE
    x = np.zeros(n, np.float32)
    pos = 0
    while pos < n:                           # syllables: voiced bursts with pauses
        dur = rng.integers(1600, 4800)
        f0 = rng.uniform(100, 220)
        seg = np.arange(min(dur, n - pos))
        env = np.sin(np.pi * seg / max(1, len(seg))) ** 2
        tone = sum(np.sin(2 * np.pi * f0 * h * (pos + seg) / RATE) / h for h in range(1, 12))
        x[pos:pos + len(seg)] = 0.15 * env * tone
        pos += dur + rng.integers(400, 3200)
    return x + 0.002 * rng.standard_normal(n).astype(np.float32)


def clicks(seconds):
    n = int(seconds * RATE)
    x = np.zeros(n, np.float32)
    at = np.arange(4000, n - 4000, 5000)
    for a in at:                              # short windowed tone bursts as "clicks"
        k = np.arange(-80, 80)
        x[a + k] += 0.6 * np.hanning(160) * np.sin(2 * np.pi * 1000 * k / RATE)
    return x, at


def frame_energy(x):
    n = len(x) // FRAME
    return (x[:n * FRAME].reshape(n, FRAME) ** 2).mean(1)


def main():
    table = codec.delays()
    failures = 0
    for name in codec.CONFIGS:
        worst_lag, worst_click, frame_ok = 0, 0, True
        for i, sec in enumerate([1.0, 2.5, 5.0, 9.3, 14.0, 20.0]):
            x = speechlike(sec, i)
            y = codec.degrade(x, name, table)
            assert y is not None, f'{name}: clip rejected ({sec} s)'
            assert len(y) == len(x), f'{name}: {len(y)} != {len(x)} samples'
            worst_lag = max(worst_lag, abs(codec.lag(x, y, 400)))
            # 40 ms frames: the frame shift that best aligns the energy envelopes is 0.
            ex, ey = np.log(frame_energy(x) + 1e-8), np.log(frame_energy(y) + 1e-8)
            ex, ey = ex - ex.mean(), ey - ey.mean()
            best = max(range(-3, 4), key=lambda k: float(np.dot(ex[3 + k:len(ex) - 3 + k], ey[3:len(ey) - 3])))
            if best != 0:
                frame_ok = False
        c, at = clicks(12.0)
        yc = codec.degrade(c, name, table, tolerance=4000)
        for a in at:
            w = np.abs(yc[a - 400:a + 400])
            worst_click = max(worst_click, abs(int(np.argmax(w)) - 400 + 0))
        ok = worst_lag <= 2 and worst_click <= 16 and frame_ok
        failures += not ok
        print(f'{"PASS" if ok else "FAIL"} {name:8s} delay {table[name]:5d} samples | residual lag '
              f'{worst_lag} | click error {worst_click} samples | 40 ms frames aligned {frame_ok}')
    print('ALL PASS' if failures == 0 else f'{failures} FAILED')
    sys.exit(1 if failures else 0)


if __name__ == '__main__':
    main()
