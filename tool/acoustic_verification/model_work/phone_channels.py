"""Real phone channels for training (2026-10-20): a bank of microphone + room responses
and background noise measured on crowd recordings, for distill_student.py --channels.

On Tarteel users' own phones (the `tlog` pack) v3.6 hears 1.7x as many correct letters
as another as the teacher (227 / 132); on studio audio with the training's simulated
phone effects (`calibdeg`) only 1.25x (427 / 342). The simulation is too kind: the
students learn to hear through it, not through real phones.

  python phone_channels.py <out.npz> --crowd DIR|FILE... --studio DIR|FILE...
  python phone_channels.py --pack <bank.npz> <src pack> <dst pack>   (a test pack heard
                                                                 through real phones)

- Responses: per crowd clip (>= 3 s), its long-term average spectrum over its speech
  frames (the loudest half), in dB, smoothed over ~1/6 octave, minus the mean over the
  studio clips: that phone's microphone, room and processing (and some of its speaker's
  voice, which a shrink at use keeps small). Clipped to +-25 dB, mean level removed.
- Noise: each crowd clip's quiet stretches (frames 15+ dB below its speech level, runs
  of >= 0.3 s, not digital silence): its room, hiss and codec noise, as it was recorded.

Sources: shard dirs / .npz files in distill_student.py's format (audio int16 +
offsets) or a bench pack (`<pack>_audio.npz`, one float32 array per case), or .wav files.
"""
import argparse, glob, os, wave
import numpy as np

SR, NFFT, HOP = 16000, 512, 160
BINS = NFFT // 2 + 1


def clips(paths, limit, rng):
    """float32 16 kHz clips from shard / pack / wav paths, at most [limit], shuffled."""
    files = []
    for p in paths:
        files += sorted(glob.glob(os.path.join(p, '*.npz')) + glob.glob(os.path.join(p, '*.wav'))) \
            if os.path.isdir(p) else [p]
    rng.shuffle(files)
    out = []
    for f in files:
        if f.endswith('.wav'):
            with wave.open(f) as w:
                if w.getframerate() != SR or w.getnchannels() != 1:
                    continue
                a = np.frombuffer(w.readframes(w.getnframes()), '<i2').astype(np.float32) / 32767
            # A long session: cut in 10 s pieces, each its own clip.
            out += [a[i:i + 10 * SR] for i in range(0, max(1, len(a) - 3 * SR), 10 * SR)]
        else:
            z = np.load(f, allow_pickle=True)
            if 'offsets' in z.files:
                off, au = z['offsets'], z['audio']
                for i in rng.permutation(len(off) - 1)[:max(1, limit // 4)]:
                    out.append(au[off[i]:off[i + 1]].astype(np.float32) / 32767)
            else:
                out += [z[k].astype(np.float32) for k in z.files]
        if len(out) >= limit:
            break
    return [c for c in out[:limit] if len(c) >= 3 * SR]


def power(x):
    """Frames x bins power spectrum (Hann, 32 ms, 10 ms hop)."""
    n = 1 + (len(x) - NFFT) // HOP
    idx = np.arange(NFFT)[None, :] + HOP * np.arange(n)[:, None]
    return np.abs(np.fft.rfft(x[idx] * np.hanning(NFFT), axis=1)) ** 2 + 1e-12


def smooth(db):
    """~1/6-octave smoothing: each bin the mean of the bins within +-6% of its frequency."""
    f = np.arange(BINS) * SR / NFFT
    out = np.empty_like(db)
    for k in range(BINS):
        lo, hi = np.searchsorted(f, f[k] * 0.94 - 40), np.searchsorted(f, f[k] * 1.06 + 40)
        out[k] = db[lo:max(hi, lo + 1)].mean()
    return out


def ltas(x):
    """dB long-term spectrum over the loudest half of the frames; None if too little."""
    p = power(x)
    e = p.sum(1)
    speech = p[e >= np.median(e)]
    if len(speech) < 100:
        return None
    return smooth(10 * np.log10(speech.mean(0)))


def quiet(x, min_s=0.3):
    """The clip's background: runs of frames 15+ dB below its speech level."""
    e = 10 * np.log10(power(x).sum(1))
    level = np.percentile(e, 90)
    q = (e < level - 15) & (e > level - 80)
    out, start = [], None
    for i, v in enumerate(np.append(q, False)):
        if v and start is None:
            start = i
        elif not v and start is not None:
            if (i - start) * HOP >= min_s * SR:
                seg = x[start * HOP + NFFT // 2:i * HOP]
                if np.abs(seg).max() > 1e-4:          # not digital silence
                    out.append(seg)
            start = None
    return out


def speech_power(x, frame=320):
    """Mean power of the louder half of the clip's 20 ms frames (its speech, not pauses)."""
    k = len(x) // frame
    if k < 2:
        return max(float(np.mean(x ** 2)), 1e-10)
    e = (x[:k * frame].reshape(k, frame) ** 2).mean(1)
    return max(float(e[e >= np.median(e)].mean()), 1e-10)


class Bank:
    """A built bank: [apply] gives a clip as heard through a random real phone."""

    def __init__(self, path):
        z = np.load(path)
        self.resp, self.noise, self.off = z['resp'], z['noise'], z['noise_off']

    def apply(self, x, rng, shrink=(0.5, 1.0), noise_p=0.8, snr=(5, 25)):
        """The response of a random crowd phone (scaled by [shrink], zero phase: nothing
        moves in time) and, with [noise_p], a random stretch of real background noise at
        [snr] dB below the clip's speech, looped to its length."""
        n = len(x)
        m = 1 << (n - 1).bit_length()
        r = self.resp[rng.integers(len(self.resp))] * rng.uniform(*shrink)
        f = np.fft.rfftfreq(m, 1 / SR)
        gain = 10 ** (np.interp(f, np.arange(BINS) * SR / NFFT, r) / 20)
        y = np.fft.irfft(np.fft.rfft(x, m) * gain, m)[:n]
        if len(self.off) > 1 and rng.random() < noise_p:
            k = rng.integers(len(self.off) - 1)
            seg = self.noise[self.off[k]:self.off[k + 1]].astype(np.float32) / 32767
            seg = np.tile(seg, n // len(seg) + 1)[:n]
            y = y + seg * np.sqrt(speech_power(y) / max(np.mean(seg ** 2), 1e-12)
                                  / 10 ** (rng.uniform(*snr) / 10))
        peak = np.abs(y).max()
        return (y / peak * min(1.0, peak) if peak > 0 else y).astype(np.float32)


def pack(bank_path, src, dst, seed=0):
    """A bench pack heard through real phones: <src>_audio.npz -> <dst>_audio.npz (same
    cases, each clip through its own random phone)."""
    import json, shutil
    art = os.path.join(os.path.dirname(os.path.abspath(__file__)), 'artifacts')
    bank, rng = Bank(bank_path), np.random.default_rng(seed)
    z = np.load(os.path.join(art, f'{src}_audio.npz'))
    np.savez(os.path.join(art, f'{dst}_audio.npz'), **{k: bank.apply(z[k], rng) for k in z.files})
    shutil.copy(os.path.join(art, f'{src}_cases.json'), os.path.join(art, f'{dst}_cases.json'))


def main():
    p = argparse.ArgumentParser()
    p.add_argument('out')
    p.add_argument('--crowd', nargs='+', required=True)
    p.add_argument('--studio', nargs='+', required=True)
    p.add_argument('--clips', type=int, default=4000, help='crowd clips measured')
    p.add_argument('--studio-clips', type=int, default=600)
    p.add_argument('--seed', type=int, default=0)
    a = p.parse_args()
    rng = np.random.default_rng(a.seed)

    ref = [s for s in (ltas(c) for c in clips(a.studio, a.studio_clips, rng)) if s is not None]
    ref = np.mean(ref, 0)
    resp, noise = [], []
    crowd = clips(a.crowd, a.clips, rng)
    for c in crowd:
        s = ltas(c)
        if s is None:
            continue
        r = np.clip(s - ref, -25, 25)
        # Level is not the channel: remove the speech band's mean (300-3400 Hz).
        f = np.arange(BINS) * SR / NFFT
        r -= r[(f >= 300) & (f <= 3400)].mean()
        # Below 300 Hz the studio reference is itself filtered (the reciters' MP3s have
        # their bass cut), so every crowd clip looked +10 dB boomier than it is: with that
        # boost v3.6 heard ن in place of م ت ب ه ء ل, which real phones do not do. Capped
        # at +6 dB there.
        r = np.where(f < 300, np.minimum(r, 6.0), r)
        resp.append(np.clip(r, -25, 25))
        noise += quiet(c)
    resp = np.array(resp, np.float32)
    lens = [len(n) for n in noise]
    np.savez(a.out, resp=resp, ref=ref.astype(np.float32),
             noise=(np.concatenate(noise) * 32767).astype(np.int16) if noise else np.zeros(0, np.int16),
             noise_off=np.cumsum([0] + lens))
    f = np.arange(BINS) * SR / NFFT
    band = lambda lo, hi: resp[:, (f >= lo) & (f < hi)].mean(1)
    print(f'{len(resp)} responses from {len(crowd)} crowd clips; {len(noise)} noise pieces, '
          f'{sum(lens) / SR / 60:.1f} min')
    for lo, hi in ((60, 200), (200, 1000), (1000, 3000), (3000, 5000), (5000, 8000)):
        b = band(lo, hi)
        print(f'  {lo:>4}-{hi:<4} Hz: median {np.median(b):+.1f} dB, 10-90% {np.percentile(b, 10):+.1f}..{np.percentile(b, 90):+.1f}')


if __name__ == '__main__':
    import sys
    if sys.argv[1] == '--pack':
        pack(*sys.argv[2:5])
    else:
        main()
