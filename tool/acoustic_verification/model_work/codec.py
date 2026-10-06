"""Codec degradation for the student's audio (the teacher always hears the clean clip).

clean 16 kHz mono PCM -> ffmpeg encode (MP3 / Opus / AAC) -> decode -> 16 kHz mono PCM,
then a DETERMINISTIC delay correction: each codec configuration adds a fixed delay
(encoder priming + decoder), measured once by measure_delays() and stored in
codec_delays.json. The output always has the clean clip's exact sample count and time
origin; degrade() also cross-checks each clip against the stored delay and rejects
(returns None) any clip that does not line up, rather than training on a shifted copy.

Validation: python codec.py measure   (writes codec_delays.json)
            python test_codec_alignment.py
"""
import json, os, subprocess, sys, tempfile
import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
DELAYS = os.path.join(HERE, 'codec_delays.json')
RATE = 16000

# (name, ffmpeg encoder args, container extension)
CONFIGS = {
    'mp3_32': (['-c:a', 'libmp3lame', '-b:a', '32k'], 'mp3'),
    'mp3_48': (['-c:a', 'libmp3lame', '-b:a', '48k'], 'mp3'),
    'mp3_64': (['-c:a', 'libmp3lame', '-b:a', '64k'], 'mp3'),
    'mp3_96': (['-c:a', 'libmp3lame', '-b:a', '96k'], 'mp3'),
    'opus_12': (['-c:a', 'libopus', '-b:a', '12k', '-application', 'voip'], 'ogg'),
    'opus_16': (['-c:a', 'libopus', '-b:a', '16k', '-application', 'voip'], 'ogg'),
    'opus_24': (['-c:a', 'libopus', '-b:a', '24k', '-application', 'voip'], 'ogg'),
    'opus_32': (['-c:a', 'libopus', '-b:a', '32k'], 'ogg'),
    'aac_32': (['-c:a', 'aac', '-b:a', '32k'], 'adts'),
    'aac_48': (['-c:a', 'aac', '-b:a', '48k'], 'adts'),
    'aac_64': (['-c:a', 'aac', '-b:a', '64k'], 'adts'),
}
MAX_LAG = 4000          # samples searched (250 ms)


def roundtrip(x, name):
    """Encode/decode only (no correction): the raw decoded 16 kHz mono samples."""
    args, ext = CONFIGS[name]
    pcm = (np.clip(np.asarray(x, dtype=np.float32), -1, 1) * 32767).astype('<i2')
    with tempfile.TemporaryDirectory(dir='/dev/shm' if os.path.isdir('/dev/shm') else None) as d:
        raw, enc = os.path.join(d, 'a.raw'), os.path.join(d, 'a.' + ext)
        pcm.tofile(raw)
        fmt = ['-f', 'adts'] if ext == 'adts' else []
        subprocess.run(['ffmpeg', '-loglevel', 'error', '-y', '-f', 's16le', '-ar', str(RATE),
                        '-ac', '1', '-i', raw, *args, *fmt, enc], check=True, timeout=120)
        out = subprocess.run(['ffmpeg', '-loglevel', 'error', '-i', enc, '-ar', str(RATE),
                              '-ac', '1', '-f', 's16le', '-'], check=True, capture_output=True,
                             timeout=120).stdout
    return np.frombuffer(out, dtype='<i2').astype(np.float32) / 32767


def lag(clean, decoded, max_lag=MAX_LAG):
    """Samples by which [decoded] is late relative to [clean] (-max_lag..max_lag),
    by cross-correlation over the whole clip."""
    n = len(clean)
    m = 1 << (n + len(decoded) + max_lag).bit_length()
    xc = np.fft.irfft(np.fft.rfft(decoded, m) * np.conj(np.fft.rfft(clean, m)), m)
    lags = np.r_[np.arange(0, max_lag + 1), np.arange(-max_lag, 0)]
    vals = np.r_[xc[:max_lag + 1], xc[-max_lag:]]
    return int(lags[np.argmax(vals)])


def delays():
    return json.load(open(DELAYS))


def degrade(x, name, table=None, tolerance=2):
    """[x] through codec [name], shifted by its fixed delay, cut/padded to len(x).
    None if this clip's own cross-correlation disagrees with the fixed delay by more
    than [tolerance] samples (it is then not used)."""
    table = table or delays()
    d = table[name]
    y = roundtrip(x, name)
    if abs(lag(x, y) - d) > tolerance:
        return None
    y = y[d:] if d >= 0 else np.pad(y, (-d, 0))
    y = y[:len(x)]
    if len(y) < len(x):
        y = np.pad(y, (0, len(x) - len(y)))
    return y.astype(np.float32)


def degrade_many(xs, name, table=None, gap=8000, tolerance=2):
    """degrade() for many clips in one encode/decode (joined with [gap] samples of
    silence, cut back apart at their own positions after the fixed delay); each clip
    is still checked against its clean original and None where it does not line up."""
    table = table or delays()
    d = table[name]
    starts, parts, pos = [], [], 0
    for x in xs:
        starts.append(pos)
        parts += [np.asarray(x, dtype=np.float32), np.zeros(gap, np.float32)]
        pos += len(x) + gap
    y = roundtrip(np.concatenate(parts), name)
    y = y[d:] if d >= 0 else np.pad(y, (-d, 0))
    out = []
    for x, s0 in zip(xs, starts):
        seg = y[s0:s0 + len(x)]
        if len(seg) < len(x):
            seg = np.pad(seg, (0, len(x) - len(seg)))
        out.append(seg.astype(np.float32) if abs(lag(x, seg, 400)) <= tolerance else None)
    return out


def measure_delays(clips):
    """Per codec config: the delay on every clip; must be one constant."""
    out, report = {}, {}
    for name in CONFIGS:
        ls, lens = [], []
        for x in clips:
            y = roundtrip(x, name)
            ls.append(lag(x, y)); lens.append((len(x), len(y)))
        vals, counts = np.unique(ls, return_counts=True)
        out[name] = int(vals[np.argmax(counts)])
        report[name] = dict(lags=sorted(set(ls)), lengths=lens[:6])
    return out, report


if __name__ == '__main__' and sys.argv[1:] == ['measure']:
    sys.path.insert(0, HERE)
    import distill_student as ds
    clips = [x for x, _ in ds.clips(os.path.join(HERE, 'data', 'val.npz'))]
    pick = sorted(clips, key=len)
    pick = pick[::max(1, len(pick) // 24)][:24]          # short to long
    out, report = measure_delays(pick)
    for k, v in report.items():
        print(f'{k:8s} lags over {len(pick)} clips: {v["lags"]}  (clean, decoded) samples: {v["lengths"]}')
    json.dump(out, open(DELAYS, 'w'), indent=1)
    print('fixed delays:', out)
