"""Distil a small student from the Muaalem teacher (GPU job).

EXPERIMENTAL / NOT YET CLEARED FOR DISTRIBUTION — see README.md (training
audio rights are not cleared).

  python distill_student.py prepare <data dir> [--hours 300]
  python distill_student.py bench   <size> <data dir> [--max-audio 320]
  python distill_student.py train   <size> <data dir> <out dir> [--steps N] [--resume]
  python distill_student.py export  <out dir>        # student.pt (EMA) + config

Student: the teacher's architecture (Wav2Vec2-BERT/Conformer, same fbank
front end, same stride-2 adapter → 40 ms frames) at a smaller width/depth,
with ONE head: the same 43 phoneme classes in the same order — a drop-in
for QuranAcousticModel.

  size   width x layers   params
  s150      640 x 16      161.4M
  s100      512 x 16      103.4M
  s75       512 x 12       79.2M
  s50       384 x 16       58.3M
  s25       256 x 16       26.1M

Loss = T² · KL(teacher_T || student_T) over every frame's full 43-class
distribution (confidence, competing vowels/consonants, blank — the margins
the verifier's likelihood ratios read)
     + λ · CTC(student, the segment's ground-truth phonemes from the dataset).

Data: obadx/muaalem-annotated-v3, every moshaf, Quran segments only, with
every segment touching a benchmark ayah (benchmark_ayahs.json, any
reciter) excluded; a held-out validation set from separate segments.
"""
import argparse, collections, glob, json, math, os, random, time
import numpy as np
import torch
import torch.nn as nn
import torch.nn.functional as F

HERE = os.path.dirname(os.path.abspath(__file__))
# Depth students keep the teacher's width and copy these of its 24 layers (plus the
# feature projection, adapter and phoneme head), so they start from its pre-training.
DEPTH = {'d6': [0, 4, 8, 13, 18, 23], 'd8': [0, 3, 6, 9, 12, 15, 19, 23]}
SIZES = {'s150': (640, 16, 10), 's100': (512, 16, 8), 's75': (512, 12, 8),
         's50': (384, 16, 6), 's25': (256, 16, 4)}
VOCAB = ['', 'ء', 'ب', 'ت', 'ث', 'ج', 'ح', 'خ', 'د', 'ذ', 'ر', 'ز', 'س', 'ش', 'ص', 'ض',
         'ط', 'ظ', 'ع', 'غ', 'ف', 'ق', 'ك', 'ل', 'م', 'ن', 'ه', 'و', 'ي', 'ا', 'ۦ', 'ۥ',
         'َ', 'ُ', 'ِ', '۪', 'ـ', 'ٲ', 'ڇ', 'ں', '۾', 'ۜ', 'ؙ']
ID = {c: i for i, c in enumerate(VOCAB) if c}
DEV = 'cuda' if torch.cuda.is_available() else 'cpu'


# ------------------------------------------------------------------ data

def prepare(data_dir, hours, shard_clips=2000, val_clips=400, seed=0, local=None):
    """Caches training audio locally as shards (int16 audio + targets)."""
    from datasets import Audio, get_dataset_config_names, load_dataset
    os.makedirs(data_dir, exist_ok=True)
    bench = {tuple(x) for x in json.load(open(os.path.join(HERE, 'benchmark_ayahs.json')))}
    configs = [] if local else [c for c in get_dataset_config_names('obadx/muaalem-annotated-v3')
                                if c.startswith('moshaf_') and c != 'moshaf_metadata']
    random.Random(seed).shuffle(configs)
    budget = hours * 3600 / max(1, len(configs))  # spread over every moshaf
    shard, n_shard, total, skipped, val, accepted = [], 0, 0.0, 0, [], 0

    def touches_benchmark(row):
        s, e = row.get('start_span') or {}, row.get('end_span') or {}
        try:
            s0, a0, s1, a1 = int(s['sura_idx']), int(s['aya_idx']), int(e['sura_idx']), int(e['aya_idx'])
        except Exception:
            return True                            # unknown position: be safe
        if s0 == s1:
            return any((s0, a) in bench for a in range(a0, a1 + 1))
        return any(b[0] in (s0, s1) for b in bench)

    def flush():
        nonlocal shard, n_shard
        if not shard:
            return
        audio = np.concatenate([x for x, _ in shard]).astype(np.int16)
        offsets = np.cumsum([0] + [len(x) for x, _ in shard])
        np.savez(os.path.join(data_dir, f'shard_{n_shard:04d}.npz'), audio=audio, offsets=offsets,
                 targets=np.array([t for _, t in shard], dtype=object))
        n_shard += 1
        shard = []

    if local:                                     # testing: one local parquet file
        configs = ['local']
        budget = hours * 3600
    for cfg in configs:
        if cfg == 'local':
            ds = load_dataset('parquet', data_files=local, split='train', streaming=True)
        else:
            ds = load_dataset('obadx/muaalem-annotated-v3', name=cfg, split='train', streaming=True)
        ds = ds.cast_column('audio', Audio(sampling_rate=16000))
        got = 0.0
        for row in ds:
            if got >= budget:
                break
            if str(row.get('has_quran')) != 'True' or touches_benchmark(row):
                skipped += 1
                continue
            phon = (row.get('phonemes') or '').replace(' ', '')
            if not phon or any(c not in ID for c in phon):
                continue
            x = np.asarray(row['audio']['array'], dtype=np.float32)
            secs = len(x) / 16000
            if secs < 1 or secs > 20:
                continue
            clip = (np.clip(x, -1, 1) * 32767).astype(np.int16)
            target = [ID[c] for c in phon]
            accepted += 1
            if len(val) < val_clips and accepted % 50 == 1:
                val.append((clip, target))
                continue
            shard.append((clip, target))
            got += secs
            total += secs
            if len(shard) == shard_clips:
                flush()
        print(f'{cfg}: {got / 3600:.1f} h (total {total / 3600:.1f} h, skipped {skipped})', flush=True)
    flush()
    np.savez(os.path.join(data_dir, 'val.npz'),
             audio=np.concatenate([x for x, _ in val]).astype(np.int16),
             offsets=np.cumsum([0] + [len(x) for x, _ in val]),
             targets=np.array([t for _, t in val], dtype=object))
    print(f'prepared {total / 3600:.1f} h in {n_shard} shards, {len(val)} validation clips')


def clips(path):
    z = np.load(path, allow_pickle=True)
    a, o, t = z['audio'], z['offsets'], z['targets']
    return [(a[o[i]:o[i + 1]].astype(np.float32) / 32767, list(t[i])) for i in range(len(t))]


REPEAT = ('', 1)   # (shard name prefix, times): oversampled shards (set by --repeat)


def batches(data_dir, max_audio_s, seed):
    """Endless batches with at most max_audio_s seconds of (padded) audio."""
    rng = random.Random(seed)
    shards = sorted(glob.glob(os.path.join(data_dir, 'shard_[0-9][0-9][0-9][0-9].npz')))
    if REPEAT[0]:
        shards += [sh for sh in shards if os.path.basename(sh).startswith(REPEAT[0])] * (REPEAT[1] - 1)
    while True:
        rng.shuffle(shards)
        for sh in shards:
            items = clips(sh)
            items.sort(key=lambda c: len(c[0]))
            groups, cur = [], []
            for c in items:                       # length-bucketed batches
                if cur and len(c[0]) * (len(cur) + 1) / 16000 > max_audio_s:
                    groups.append(cur); cur = []
                cur.append(c)
            if cur:
                groups.append(cur)
            rng.shuffle(groups)
            yield from groups


def _pool_shard(args):
    sh, share, seed = args
    import codec
    out = sh.replace('.npz', '.codec.npz')
    if os.path.exists(out):
        return out, 'kept'
    rng = random.Random(f'{seed}:{os.path.basename(sh)}')
    table = codec.delays()
    names = sorted(codec.CONFIGS)
    items = clips(sh)
    chosen = collections.defaultdict(list)
    for i in range(len(items)):
        if rng.random() < share:
            chosen[rng.randrange(len(names))].append(i)
    got, rejected = {}, 0
    for k, ids in chosen.items():
        for j in range(0, len(ids), 200):        # one ffmpeg round trip per 200 clips
            batch = ids[j:j + 200]
            for i, y in zip(batch, codec.degrade_many([items[i][0] for i in batch], names[k], table)):
                if y is None:
                    rejected += 1
                else:
                    got[i] = (k, y)
    idx = sorted(got)
    cfg = [got[i][0] for i in idx]
    parts = [(np.clip(got[i][1], -1, 1) * 32767).astype(np.int16) for i in idx]
    np.savez(out + '.tmp.npz', idx=np.array(idx, np.int32), cfg=np.array(cfg, np.int16),
             names=np.array(names), audio=np.concatenate(parts) if parts else np.zeros(0, np.int16),
             offsets=np.cumsum([0] + [len(p) for p in parts]))
    os.replace(out + '.tmp.npz', out)
    return out, f'{len(idx)} coded, {rejected} rejected'


def prepare_codec(data_dir, share, seed=0, workers=2):
    """Codec pool: for [share] of each shard's clips, one codec-degraded copy (MP3 /
    Opus / AAC, codec.py: delay-corrected, the clean clip's exact length), stored
    beside the shard as shard_XXXX.codec.npz. Built once, on the CPU."""
    from multiprocessing import Pool
    shards = sorted(glob.glob(os.path.join(data_dir, 'shard_[0-9][0-9][0-9][0-9].npz')))
    with Pool(workers) as pool:
        for out, msg in pool.imap_unordered(_pool_shard, [(sh, share, seed) for sh in shards]):
            print(os.path.basename(out), msg, flush=True)


def pool_batches(data_dir, max_audio_s, seed):
    """batches(), each with its clips' codec copies (or None) from the pool."""
    rng = random.Random(seed)
    shards = sorted(glob.glob(os.path.join(data_dir, 'shard_[0-9][0-9][0-9][0-9].npz')))
    while True:
        rng.shuffle(shards)
        for sh in shards:
            items = clips(sh)
            coded = [None] * len(items)
            cp = sh.replace('.npz', '.codec.npz')
            if os.path.exists(cp):
                z = np.load(cp)
                a, o = z['audio'], z['offsets']
                for j, i in enumerate(z['idx']):
                    coded[i] = a[o[j]:o[j + 1]].astype(np.float32) / 32767
            pairs = sorted(zip(items, coded), key=lambda c: len(c[0][0]))
            groups, cur = [], []
            for c in pairs:
                if cur and len(c[0][0]) * (len(cur) + 1) / 16000 > max_audio_s:
                    groups.append(cur); cur = []
                cur.append(c)
            if cur:
                groups.append(cur)
            rng.shuffle(groups)
            for g in groups:
                yield [c[0] for c in g], [c[1] for c in g]


# ---------------------------------------------------------------- models

def load_teacher():
    from quran_muaalem import Muaalem
    m = Muaalem(model_name_or_path='obadx/muaalem-model-v3_2', device=DEV,
                dtype=torch.bfloat16 if DEV == 'cuda' else torch.float32)
    # TEACHER_WEIGHTS: a fine-tuned teacher (finetune_teacher.py) instead.
    if os.environ.get('TEACHER_WEIGHTS'):
        sd = torch.load(os.environ['TEACHER_WEIGHTS'], map_location='cpu')
        m.model.load_state_dict(sd)
        m.model.to(device=DEV, dtype=torch.bfloat16 if DEV == 'cuda' else torch.float32)
        print('teacher weights:', os.environ['TEACHER_WEIGHTS'], flush=True)
    m.model.eval()
    for p in m.model.parameters():
        p.requires_grad_(False)
    return m


def student_config(teacher_model, size):
    cfg = teacher_model.config.__class__.from_dict(teacher_model.config.to_dict())
    if size in DEPTH:
        cfg.num_hidden_layers = len(DEPTH[size])
        cfg.level_to_vocab_size = {'phonemes': 43}
        cfg.level_to_loss_weight = {'phonemes': 1.0}
        return cfg
    width, layers, heads = SIZES[size]
    cfg.hidden_size = cfg.output_hidden_size = width
    cfg.num_hidden_layers, cfg.num_attention_heads = layers, heads
    cfg.intermediate_size = 4 * width
    cfg.level_to_vocab_size = {'phonemes': 43}
    cfg.level_to_loss_weight = {'phonemes': 1.0}
    return cfg


def make_student(teacher_model, size):
    s = teacher_model.__class__(student_config(teacher_model, size))
    if size in DEPTH:
        # Start from the teacher: its layers DEPTH[size], renumbered, and everything else.
        keep = DEPTH[size]
        src = teacher_model.state_dict()
        out = {}
        for k, v in s.state_dict().items():
            name = k
            if '.encoder.layers.' in k:
                pre, rest = k.split('.encoder.layers.', 1)
                i, tail = rest.split('.', 1)
                name = f'{pre}.encoder.layers.{keep[int(i)]}.{tail}'
            out[k] = src[name].to(v.dtype)
        s.load_state_dict(out)
    print(f'student {size}: {sum(p.numel() for p in s.parameters()) / 1e6:.1f}M parameters')
    return s


_gpu_fbank = None


def featurize(fe, items):
    # On a GPU the features are computed there (gpu_fbank.py, checked against the
    # extractor): on one CPU core they took most of each step and left the GPU idle.
    global _gpu_fbank
    if DEV == 'cuda':
        if _gpu_fbank is None:
            from gpu_fbank import GpuFbank
            _gpu_fbank = GpuFbank(fe, DEV)
        return _gpu_fbank.batch([x for x, _ in items])
    f = fe([x for x, _ in items], sampling_rate=16000, return_tensors='pt', padding=True)
    return f['input_features'].to(DEV), f['attention_mask'].to(DEV)


def mp3(x, kbps):
    """[x] through a real MP3 encoder at [kbps] and back (ffmpeg / LAME), aligned to
    the original sample for sample (the codec's delay is measured and removed), so
    the teacher's frames still line up. None if ffmpeg fails."""
    import subprocess, tempfile
    pcm = (np.clip(np.asarray(x, dtype=np.float32), -1, 1) * 32767).astype('<i2')
    with tempfile.TemporaryDirectory(dir='/dev/shm' if os.path.isdir('/dev/shm') else None) as d:
        raw, enc = os.path.join(d, 'a.raw'), os.path.join(d, 'a.mp3')
        pcm.tofile(raw)
        try:
            subprocess.run(['ffmpeg', '-loglevel', 'error', '-y', '-f', 's16le', '-ar', '16000',
                            '-ac', '1', '-i', raw, '-c:a', 'libmp3lame', '-b:a', f'{kbps}k', enc],
                           check=True, timeout=60)
            out = subprocess.run(['ffmpeg', '-loglevel', 'error', '-i', enc, '-ar', '16000',
                                  '-ac', '1', '-f', 's16le', '-'], check=True, capture_output=True,
                                 timeout=60).stdout
        except Exception:
            return None
    y = np.frombuffer(out, dtype='<i2').astype(np.float32) / 32767
    a = pcm.astype(np.float32) / 32767
    n = min(len(a), 32000)
    if len(y) < n:
        return None
    # Codec delay: the lag (0..4000 samples) where y best matches x.
    m = 1 << (n + 4000).bit_length()
    xc = np.fft.irfft(np.fft.rfft(y[:n + 4000], m) * np.conj(np.fft.rfft(a[:n], m)), m)[:4001]
    lag = int(np.argmax(xc))
    y = y[lag:lag + len(a)]
    if len(y) < len(a):
        y = np.pad(y, (0, len(a) - len(y)))
    return y


def codec_prefetch(it, prob, rng=None):
    """Batches from [it] with, for some clips, a low-bitrate MP3 copy for the student
    (24-64 kbps), made on the CPU in a background thread while the GPU trains."""
    import queue, threading
    rng = rng or random.Random(1)
    q = queue.Queue(maxsize=3)

    def work():
        for items in it:
            q.put((items, [mp3(x, rng.choice([24, 32, 40, 48, 64])) if rng.random() < prob else None
                           for x, _ in items]))
    threading.Thread(target=work, daemon=True).start()
    while True:
        yield q.get()


PITCH = 0.0   # share of degraded clips pitch-shifted up (set by --pitch)
TEMPO = 0.0   # share of clips sped up / slowed down, for teacher and student (--tempo)
# Hard frames (--hard / --focus): frames whose teacher class is a sound the student gets
# wrong on amateurs (nun / ghunna, qalqala letters, dhal and its neighbours, the sukun
# marker), and frames where student and teacher disagree most, weigh more in the KL.
HARD_W, FOCUS_W = 0.0, 0.0
HARD_SYMBOLS = 'ن ں م ق ط ب ج د ذ ز ظ ث ض ص س ڇ'.split()
VOCAB = ['', 'ء', 'ب', 'ت', 'ث', 'ج', 'ح', 'خ', 'د', 'ذ', 'ر', 'ز', 'س', 'ش', 'ص', 'ض', 'ط', 'ظ',
         'ع', 'غ', 'ف', 'ق', 'ك', 'ل', 'م', 'ن', 'ه', 'و', 'ي', 'ا', 'ۦ', 'ۥ', 'َ', 'ُ', 'ِ', '۪', 'ـ',
         'ٲ', 'ڇ', 'ں', '۾', 'ۜ', 'ؙ']   # the 43 phoneme classes (the app's own order)
EXTRA = False # more phone conditions: coloured noise, background voices, hum, dropouts,
              # larger rooms (--phone-extra)


def tempo(items, coded, rng=random):
    """Faster and slower reciters: with [TEMPO], a clip resampled to 0.88-1.12x speed.
    Applied before the teacher hears it, so its targets follow the new timing; such a
    clip's codec-pool copy (aligned to the original) is not used."""
    if TEMPO <= 0:
        return items, coded
    out, cod = [], []
    for i, (x, t) in enumerate(items):
        if rng.random() >= TEMPO:
            out.append((x, t)); cod.append(coded[i] if coded else None); continue
        f = rng.uniform(0.88, 1.12)                 # speed: f > 1 is faster (shorter)
        w = torch.as_tensor(np.asarray(x, dtype=np.float32))[None, None]
        y = F.interpolate(w, size=max(1, int(round(w.shape[-1] / f))), mode='linear',
                          align_corners=False)[0, 0]
        out.append((y.numpy(), t)); cod.append(None)
    return out, (cod if coded else None)


def augment(items, prob, rng=random, coded=None, pool_share=0.7, others=None):
    """The student's view of the audio; the teacher hears the clean clip, so the
    student learns to hear through degradation. Each clip is degraded with [prob]:
    - from its codec-pool copy ([pool_share] of the time, when one exists: a real MP3 /
      Opus / AAC round trip, aligned), plus at most light noise and a level change;
    - otherwise by phone-like effects, each with a moderate probability so they rarely
      all stack: low-pass / bass cut, microphone tilt, room echo, noise (10-30 dB),
      AGC-like compression, rare mild clipping, level. All on the GPU; no effect
      shifts the audio in time (an echo keeps its direct sound at 0)."""
    if DEV == 'cuda':
        # Each FFT size caches a plan with its own workspace; bounded, beside training.
        torch.backends.cuda.cufft_plan_cache.max_size = 32
    out = []
    for i, (x, t) in enumerate(items):
        if rng.random() >= prob:
            out.append((x, t)); continue
        c = coded[i] if coded else None
        use_pool = c is not None and rng.random() < pool_share
        w = torch.as_tensor(np.asarray(c if use_pool else x, dtype=np.float32), device=DEV)
        n = w.shape[0]
        if use_pool:
            if rng.random() < 0.3:                  # light background noise
                snr = rng.uniform(15, 35)
                p = w.pow(2).mean().clamp_min(1e-8)
                w = w + torch.randn_like(w) * torch.sqrt(p / 10 ** (snr / 10))
            w = w * rng.uniform(0.4, 1.0)
            out.append((w.clamp(-1, 1).cpu().numpy(), t))
            continue
        if PITCH > 0 and rng.random() < PITCH:
            # Higher voice (women / children): pitch and formants up 3-7 semitones,
            # same duration (phase vocoder), so frames stay aligned with the teacher's.
            import torchaudio
            w = torchaudio.functional.pitch_shift(w[None], 16000, rng.uniform(3, 7))[0][:n]
            if w.shape[0] < n:
                w = F.pad(w, (0, n - w.shape[0]))
        # FFT lengths are powers of two: cuFFT failed (CUFFT_INTERNAL_ERROR) on some
        # odd clip lengths.
        lowpass, tilt = rng.random() < 0.6, rng.random() < 0.4
        if lowpass or tilt:
            m = 1 << (n - 1).bit_length()
            spec = torch.fft.rfft(w, m)
            f = torch.fft.rfftfreq(m, 1 / 16000).to(DEV)
            if lowpass:                             # narrowband: low-pass, maybe bass cut
                spec = spec * torch.clamp(1 - (f - rng.uniform(3000, 7000)) / 500, 0, 1)
                if rng.random() < 0.5:
                    spec = spec * torch.clamp((f - rng.uniform(100, 400)) / 100, 0, 1)
            if tilt:                                # microphone response: gentle tilt + bump
                db = rng.uniform(-4, 4) * torch.log2((f + 100) / 1000)
                fc, g = rng.uniform(1500, 5000), rng.uniform(-4, 6)
                db = db + g * torch.exp(-0.5 * ((f - fc) / (fc * 0.3)) ** 2)
                spec = spec * torch.pow(10.0, db / 20)
            w = torch.fft.irfft(spec, m)[:n]
        if rng.random() < 0.3:                      # room: decaying-noise impulse response
            rt = rng.uniform(0.15, 0.6 if EXTRA else 0.35)
            k = int(16000 * rt)
            ir = torch.randn(k, device=DEV) * torch.exp(-6.9 * torch.arange(k, device=DEV) / k)
            # Direct sound dominant (every reflection >= 10 dB below it), so the echo
            # never moves the speech in time.
            ir = ir / ir.abs().max() * rng.uniform(0.05, 0.3)
            ir[0] = 1.0
            ir = ir / ir.norm()
            m = 1 << (n + k - 2).bit_length()
            w = torch.fft.irfft(torch.fft.rfft(w, m) * torch.fft.rfft(ir, m), m)[:n]
        if rng.random() < 0.5:                      # background noise at 10-30 dB SNR
            snr = rng.uniform(10, 30)
            p = w.pow(2).mean().clamp_min(1e-8)
            noise = torch.randn_like(w)
            if EXTRA and rng.random() < 0.5:        # coloured: pink (1/f) or brown (1/f^2)
                m = 1 << (n - 1).bit_length()
                f = torch.fft.rfftfreq(m, 1 / 16000).to(DEV).clamp_min(20)
                noise = torch.fft.irfft(torch.fft.rfft(noise, m) / f.pow(rng.choice([0.5, 1.0])), m)[:n]
                noise = noise / noise.std().clamp_min(1e-8)
            w = w + noise * torch.sqrt(p / 10 ** (snr / 10))
        if EXTRA and others and rng.random() < 0.2:  # someone talking nearby, 12-25 dB down
            o = others[rng.randrange(len(others))][0]
            o = torch.as_tensor(np.asarray(o, dtype=np.float32), device=DEV)
            if o.shape[0] > 1600:
                o = o.roll(rng.randrange(o.shape[0]))
                o = o.repeat(n // o.shape[0] + 1)[:n]
                p = w.pow(2).mean().clamp_min(1e-8)
                q = o.pow(2).mean().clamp_min(1e-8)
                w = w + o * torch.sqrt(p / q / 10 ** (rng.uniform(12, 25) / 10))
        if EXTRA and rng.random() < 0.1:            # mains hum (50/60 Hz and harmonics)
            tt = torch.arange(n, device=DEV) / 16000
            base = rng.choice([50.0, 60.0])
            hum = sum(torch.sin(2 * math.pi * base * k * tt + rng.uniform(0, 6.28)) / k
                      for k in (1, 2, 3))
            w = w + hum * w.abs().max() * 10 ** (-rng.uniform(30, 45) / 20)
        if EXTRA and rng.random() < 0.1:            # dropouts (Bluetooth / network): 20-60 ms
            for _ in range(rng.randint(1, 3)):
                a0 = rng.randrange(max(1, n - 960)); w[a0:a0 + rng.randint(320, 960)] = 0
        if rng.random() < 0.3:                      # AGC-like compression (20 ms envelope)
            frames = n // 320
            if frames > 2:
                env = w[:frames * 320].reshape(frames, 320).pow(2).mean(1).sqrt().clamp_min(1e-4)
                target = env.mean()
                gain = torch.pow(env / target, -rng.uniform(0.3, 0.6)).clamp(0.25, 4.0)
                gain = torch.repeat_interleave(gain, 320)
                gain = torch.cat([gain, gain[-1:].expand(n - gain.shape[0])])
                w = w * gain
        if rng.random() < 0.1:                      # mild clipping (~0.5-2% of samples)
            lim = torch.quantile(w.abs()[::8], rng.uniform(0.98, 0.995))
            w = w.clamp(-lim, lim) / lim.clamp_min(1e-4) * 0.9
        w = w / w.abs().max().clamp_min(1e-4) * min(1.0, float(w.abs().max())) * rng.uniform(0.3, 1.0)
        out.append((w.clamp(-1, 1).cpu().numpy(), t))
    return out


def crop_views(items, prob, rng=random, hop=640):
    """The student's input for short-context training: with [prob], a window of the
    clip (1.5-6 s, on 40 ms frame boundaries) instead of the whole clip, so its edge
    frames — like the app's short streaming windows' — have little or no context,
    while their targets still come from the teacher run on the whole clip.
    Returns (student items, first teacher frame of each, cropped?)."""
    out, starts, cropped = [], [], []
    for x, t in items:
        n = len(x) // hop
        w = int(rng.uniform(1.5, 6.0) * 16000 / hop)
        if rng.random() >= prob or n <= w + 2:
            out.append((x, t)); starts.append(0); cropped.append(False); continue
        s0 = rng.randrange(0, n - w + 1)
        out.append((x[s0 * hop:(s0 + w) * hop], [])); starts.append(s0); cropped.append(True)
    return out, starts, cropped


def losses(teacher, student, fe, items, T, ctc_w, aug=0.0, coded=None, layers=None,
           rng=random, pool_share=0.7, crop=0.0):
    """KL to the teacher, CTC to the transcript and — with [layers] (a depth student's
    teacher layers) — 1 - cosine between each student layer's output and its teacher
    layer's, on real frames (the teacher's internal representations, kept)."""
    items, coded = tempo(items, coded, rng)
    x, mask = featurize(fe, items)
    if crop > 0:
        # Short-context training: the student hears windows, the teacher whole clips.
        s_items, starts, cropped = crop_views(items, crop, rng)
        xs, smask = featurize(fe, augment(s_items, aug, rng, None, pool_share, items) if aug > 0 else s_items)
    else:
        xs = featurize(fe, augment(items, aug, rng, coded, pool_share, items))[0] if aug > 0 else x
        smask, starts, cropped = mask, None, None
    hid = layers is not None and crop == 0
    with torch.no_grad():
        to = teacher.model(input_features=x.to(teacher.model.dtype), attention_mask=mask,
                           output_hidden_states=hid, return_dict=True)
        tl = to.logits['phonemes'].float()
    with torch.autocast(DEV, dtype=torch.bfloat16, enabled=DEV == 'cuda'):
        so = student(input_features=xs, attention_mask=smask, output_hidden_states=hid,
                     return_dict=True)
        sl = so.logits['phonemes']
    sl = sl.float()
    loss_hid = torch.zeros((), device=sl.device)
    if hid:
        hm = mask.float()
        for i, k in enumerate(layers):
            cos = F.cosine_similarity(so.hidden_states[i + 1].float(),
                                      to.hidden_states[k + 1].float(), dim=-1)
            loss_hid = loss_hid + ((1 - cos) * hm).sum() / hm.sum()
        loss_hid = loss_hid / len(layers)
    if starts is not None:
        # Each student frame j matches teacher frame starts[i] + j of the whole clip.
        tvalid = mask[:, ::2].sum(1)
        n = sl.shape[1]
        idx = torch.arange(n, device=sl.device)[None, :] + torch.tensor(starts, device=sl.device)[:, None]
        ok = idx < tvalid[:, None]
        tl = torch.gather(tl, 1, idx.clamp(max=tl.shape[1] - 1)[:, :, None].expand(-1, -1, tl.shape[2]))
        fm = (smask[:, ::2][:, :n].bool() & ok).float()
    else:
        n = min(tl.shape[1], sl.shape[1])
        tl, sl = tl[:, :n], sl[:, :n]
        fm = mask[:, ::2][:, :n].float()
    kl = F.kl_div(F.log_softmax(sl / T, -1), F.log_softmax(tl / T, -1), log_target=True,
                  reduction='none').sum(-1)
    if HARD_W > 0 or FOCUS_W > 0:
        w = torch.ones_like(kl)
        if HARD_W > 0:
            hard = torch.zeros(tl.shape[-1], device=tl.device)
            for c in HARD_SYMBOLS:
                hard[VOCAB.index(c)] = 1.0
            w = w + HARD_W * hard[tl.argmax(-1)]
        if FOCUS_W > 0:
            mean = (kl * fm).sum() / fm.sum().clamp_min(1)
            w = w + FOCUS_W * (kl.detach() / mean.detach().clamp_min(1e-6)).clamp(0, 3) / 3
        w = w / ((w * fm).sum() / fm.sum().clamp_min(1))   # same overall scale
        loss_kl = (kl * w * fm).sum() / fm.sum() * T * T
    else:
        loss_kl = (kl * fm).sum() / fm.sum() * T * T
    # CTC only for clips with a transcript (diverse_data.py clips have none: there the
    # teacher's distribution is the whole target).
    keep = [j for j, (_, t) in enumerate(items)
            if len(t) > 0 and not (cropped and cropped[j])]
    if keep:
        targets = torch.tensor([i for j in keep for i in items[j][1]], device=DEV)
        lengths = torch.tensor([len(items[j][1]) for j in keep], device=DEV)
        loss_ctc = F.ctc_loss(F.log_softmax(sl[keep], -1).transpose(0, 1), targets,
                              fm[keep].sum(1).long(), lengths, blank=0, zero_infinity=True,
                              reduction='mean')
    else:
        loss_ctc = torch.zeros((), device=sl.device)
    return loss_kl, loss_ctc, loss_hid


# ----------------------------------------------------------------- stages

def bench(a):
    t = load_teacher()
    fe = getattr(t.processor, 'feature_extractor', t.processor)
    s = make_student(t.model, a.size).to(DEV).train()
    opt = torch.optim.AdamW(s.parameters(), lr=1e-4)
    it = codec_prefetch(batches(a.data, a.max_audio, 0), a.codec)
    if DEV == 'cuda':
        torch.cuda.reset_peak_memory_stats()
    times, audio = [], []
    for step in range(a.bench_steps):
        items, coded = next(it)
        t0 = time.time()
        kl, ctc, hid = losses(t, s, fe, items, a.temperature, a.ctc_weight, a.augment, coded,
                              DEPTH.get(a.size) if a.hidden > 0 else None)
        (kl + a.ctc_weight * ctc + a.hidden * hid).backward()
        opt.step(); opt.zero_grad()
        if DEV == 'cuda':
            torch.cuda.synchronize()
        if step >= 3:
            times.append(time.time() - t0)
            audio.append(sum(len(x) for x, _ in items) / 16000)
    sps = np.mean(times)
    print(json.dumps(dict(
        device=torch.cuda.get_device_name(0) if DEV == 'cuda' else 'cpu',
        vram_gb=round(torch.cuda.get_device_properties(0).total_memory / 1e9, 1) if DEV == 'cuda' else None,
        peak_vram_gb=round(torch.cuda.max_memory_allocated() / 1e9, 1) if DEV == 'cuda' else None,
        max_audio_s_per_batch=a.max_audio, mean_audio_s_per_batch=round(float(np.mean(audio)), 1),
        sec_per_step=round(float(sps), 3), audio_hours_per_hour=round(float(np.mean(audio)) / sps, 1),
        est_hours_for_steps={n: round(n * sps / 3600, 1) for n in (10000, 20000, 30000, 40000)})))


def train(a):
    t = load_teacher()
    fe = getattr(t.processor, 'feature_extractor', t.processor)
    s = make_student(t.model, a.size).to(DEV).train()
    ema = make_student(t.model, a.size).to(DEV).eval()
    ema.load_state_dict(s.state_dict())
    for p in ema.parameters():
        p.requires_grad_(False)
    opt = torch.optim.AdamW(s.parameters(), lr=a.lr, betas=(0.9, 0.98), weight_decay=0.01)
    warm = max(1, a.steps // 25)
    sched = torch.optim.lr_scheduler.LambdaLR(
        opt, lambda i: min(1.0, (i + 1) / warm) * 0.5 * (1 + math.cos(math.pi * min(i, a.steps) / a.steps)))
    os.makedirs(a.out, exist_ok=True)
    ck = os.path.join(a.out, 'checkpoint.pt')
    step = 0
    if a.init and not (a.resume and os.path.exists(ck)):
        # Continue from an earlier student of the same size (its EMA weights).
        w = torch.load(a.init, map_location=DEV)
        s.load_state_dict(w); ema.load_state_dict(w)
        print(f'initialised from {a.init}')
    if a.resume and os.path.exists(ck):
        state = torch.load(ck, map_location=DEV, weights_only=False)
        s.load_state_dict(state['student']); ema.load_state_dict(state['ema'])
        opt.load_state_dict(state['opt']); sched.load_state_dict(state['sched'])
        step = state['step']
        print(f'resumed at step {step}')
    json.dump(dict(vars(a)), open(os.path.join(a.out, 'run.json'), 'w'), indent=1)
    val = clips(os.path.join(a.data, 'val.npz'))
    global PITCH, REPEAT, TEMPO, EXTRA, HARD_W, FOCUS_W
    PITCH = a.pitch
    TEMPO, EXTRA = a.tempo, a.phone_extra
    HARD_W, FOCUS_W = a.hard, a.focus
    if a.repeat:
        pre, times = a.repeat.split('=')
        REPEAT = (pre, int(times))
    # A fixed seed per run: screening runs see the same batches and draws.
    rng = random.Random(a.seed * 1000003 + step)
    torch.manual_seed(a.seed * 1000003 + step)
    if a.pool:
        it = pool_batches(a.data, a.max_audio, seed=a.seed * 1000003 + step)
    else:
        it = codec_prefetch(batches(a.data, a.max_audio, seed=step), a.codec)
    t0, log = time.time(), open(os.path.join(a.out, 'train.log'), 'a')
    recent = collections.deque(maxlen=200)
    skipped = run_of_skips = clipped = 0
    best_path = os.path.join(a.out, 'best.pt')
    best = state.get('best', float('inf')) if a.resume and os.path.exists(ck) else float('inf')
    while step < a.steps:
        items, coded = next(it)
        kl, ctc, hid = losses(t, s, fe, items, a.temperature, a.ctc_weight, a.augment, coded,
                              DEPTH.get(a.size) if a.hidden > 0 else None, rng, a.pool_share,
                              a.crop)
        loss = kl + a.ctc_weight * ctc + a.hidden * hid
        # Clip mode: an unusually hard batch is learned from, scaled down to the cap,
        # rather than skipped (the skip mode left two whole shards unlearned).
        if a.spike_mode == 'clip' and len(recent) >= 50 and math.isfinite(loss.item()):
            cap = a.spike * float(np.mean(recent))
            if loss.item() > cap:
                clipped += 1
                loss = loss * (cap / loss.item())
        # Spike guard: a non-finite loss, or one far above the recent average,
        # is not learned from (one such step diverged a run at step ~5,450).
        lv = loss.item()
        # (Clip mode has already scaled a hard batch down to the cap; only a non-finite
        # loss is skipped then — comparing the capped loss to the cap again skipped it.)
        spike = a.spike_mode == 'skip' and len(recent) >= 50 and lv > a.spike * np.mean(recent)
        if not math.isfinite(lv) or spike:
            skipped += 1
            run_of_skips += 1
            opt.zero_grad(set_to_none=True); sched.step(); step += 1
            print(f'skipped step {step}: loss {lv:.3f} vs mean {np.mean(recent):.3f}', flush=True)
            log.write(f'skipped step {step} loss {lv:.3f}\n'); log.flush()
            # One unusual shard (~150 batches) gets skipped in a run; a broken model never
            # recovers, so only a much longer unbroken run of skips stops training.
            if run_of_skips > 600:
                raise SystemExit('600 steps skipped in a row: training is unstable')
            del kl, ctc, loss  # free this step's graph before the next forward pass
            continue
        recent.append(lv)
        run_of_skips = 0
        loss.backward()
        torch.nn.utils.clip_grad_norm_(s.parameters(), 1.0)
        opt.step(); opt.zero_grad(set_to_none=True); sched.step()
        with torch.no_grad():
            for pe, ps in zip(ema.parameters(), s.parameters()):
                pe.lerp_(ps, 1 - a.ema)
        step += 1
        if step % 50 == 0:
            line = (f'step {step} kl {kl.item():.4f} ctc {ctc.item():.3f} hid {hid.item():.4f} clipped {clipped} '
                    f'lr {sched.get_last_lr()[0]:.2e} {(time.time() - t0) / 3600:.2f} h')
            print(line, flush=True); log.write(line + '\n'); log.flush()
        if step % a.val_every == 0 or step == a.steps:
            with torch.no_grad():
                vk, vc, nb = 0.0, 0.0, 0
                for i in range(0, len(val), 16):
                    k, c, _ = losses(t, ema, fe, val[i:i + 16], 1.0, 1.0)
                    vk += k.item(); vc += c.item(); nb += 1
            line = f'VAL step {step} ema kl(T=1) {vk / nb:.4f} ctc {vc / nb:.3f}'
            if vk / nb < best:
                best = vk / nb
                torch.save(ema.state_dict(), best_path)
                line += ' (best, saved)'
            print(line, flush=True); log.write(line + '\n'); log.flush()
        if step % a.save_every == 0 or step == a.steps:
            torch.save(dict(student=s.state_dict(), ema=ema.state_dict(), opt=opt.state_dict(),
                            sched=sched.state_dict(), step=step, best=best), ck + '.tmp')
            os.replace(ck + '.tmp', ck)
    torch.save(ema.state_dict(), os.path.join(a.out, 'student.pt'))
    student_config(t.model, a.size).save_pretrained(a.out)
    print('done', a.out)


def main():
    p = argparse.ArgumentParser()
    p.add_argument('stage', choices=['prepare', 'pool', 'bench', 'train'])
    p.add_argument('args', nargs='*')
    p.add_argument('--hours', type=float, default=300)
    p.add_argument('--steps', type=int, default=30000)
    p.add_argument('--max-audio', type=float, default=320, help='seconds of audio per batch')
    p.add_argument('--lr', type=float, default=5e-4)
    p.add_argument('--temperature', type=float, default=1.0)
    p.add_argument('--ctc-weight', type=float, default=0.1)
    p.add_argument('--ema', type=float, default=0.999)
    p.add_argument('--codec', type=float, default=0.0,
                   help='share of clips the student hears through a real low-bitrate MP3 codec')
    p.add_argument('--hidden', type=float, default=0.0,
                   help="weight of matching the teacher's layer outputs (depth students)")
    p.add_argument('--init', help='start from these student weights (a best.pt / student.pt)')
    p.add_argument('--augment', type=float, default=0.0,
                   help="share of clips the student hears degraded (the teacher hears them clean)")
    p.add_argument('--spike-mode', choices=['skip', 'clip'], default='skip')
    p.add_argument('--spike', type=float, default=4.0,
                   help='skip a step whose loss exceeds this multiple of the recent mean')
    p.add_argument('--val-every', type=int, default=2000)
    p.add_argument('--save-every', type=int, default=1000)
    p.add_argument('--bench-steps', type=int, default=20)
    p.add_argument('--resume', action='store_true')
    p.add_argument('--seed', type=int, default=0)
    p.add_argument('--hard', type=float, default=0.0,
                   help='extra KL weight on frames of the hard sounds (HARD_SYMBOLS)')
    p.add_argument('--focus', type=float, default=0.0,
                   help='extra KL weight (up to this) on frames the student gets most wrong')
    p.add_argument('--tempo', type=float, default=0.0,
                   help='share of clips resampled to 0.88-1.12x speed (teacher and student)')
    p.add_argument('--phone-extra', action='store_true',
                   help='more phone conditions: coloured noise, nearby voices, hum, dropouts, '
                        'larger rooms')
    p.add_argument('--pitch', type=float, default=0.0,
                   help='share of degraded clips pitch-shifted up (higher voices)')
    p.add_argument('--repeat', default='',
                   help='shard name prefix to repeat, and how often: e.g. shard_99=8')
    p.add_argument('--crop', type=float, default=0.0,
                   help='share of clips the student hears as a short window (short-context training)')
    p.add_argument('--pool', action='store_true',
                   help="use the codec pool (stage 'pool') for degraded clips")
    p.add_argument('--pool-share', type=float, default=0.7,
                   help='share of degraded clips taken from their codec-pool copy')
    p.add_argument('--pool-clips', type=float, default=0.7,
                   help="stage 'pool': share of each shard's clips given a codec copy")
    p.add_argument('--local-parquet', help='prepare from a local parquet file (testing)')
    p.add_argument('--shard-clips', type=int, default=2000)
    p.add_argument('--val-clips', type=int, default=400)
    a = p.parse_args()
    if a.stage == 'prepare':
        prepare(a.args[0], a.hours, a.shard_clips, a.val_clips, local=a.local_parquet)
    elif a.stage == 'pool':
        prepare_codec(a.args[0], a.pool_clips, a.seed)
    elif a.stage == 'bench':
        a.size, a.data = a.args
        bench(a)
    else:
        a.size, a.data, a.out = a.args
        train(a)


if __name__ == '__main__':
    main()
