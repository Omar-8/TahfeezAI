"""Builds the CALIBRATION set (artifacts/calib_cases.json + calib_audio.npz), in the
format bench_run.py / evaluate.dart read, separate from the FINAL TEST benchmark
(artifacts/bench_cases.json + bench_audio.npz, 259 ayahs).

No clip, ayah or recording segment is shared with training or the final test:
- mistakes: real minimal pairs spliced (the recited word's recording put in place
  of the expected word's) for reciters NOT in the training data (muaalem-annotated-v3
  moshaf_metadata): Shuraym, Ghamdi (40 kbps), Shaatree, Maher Al-Muaiqly; context and
  source ayahs never in the final test; plus each case's unspliced control;
- correct recitation: Alafasy and Husary (in the training data) only on the 158
  ayahs excluded from training and unused by the final test; Karim Mansoori and
  Parhizgar (not in the training data) on non-test ayahs.
Word boundaries come from the teacher's forced alignment.

  ../.venv/bin/python build_calibration.py [--per-category 40]
"""
import argparse, collections, json, os, random, subprocess, urllib.request
import numpy as np

from calibration_pairs import CONS, VOWELS, calibration_ayahs, edits, words_of

HERE = os.path.dirname(os.path.abspath(__file__))
ART = os.path.join(HERE, 'artifacts')
ROOT = os.path.abspath(os.path.join(HERE, '..', '..', '..'))
CACHE = os.path.join(ART, 'calib_audio_cache')
PAIR_RECITERS = ['Saood_ash-Shuraym_128kbps', 'Ghamadi_40kbps', 'Abu_Bakr_Ash-Shaatree_128kbps',
                 'MaherAlMuaiqly128kbps']
CLEAN_SEEN = ['Alafasy_128kbps', 'Husary_128kbps']          # in training: calibration ayahs only
CLEAN_UNSEEN = ['Karim_Mansoori_40kbps', 'Parhizgar_48kbps']  # not in training
CATEGORIES = ['vowel_DAMMA_FATHA', 'vowel_DAMMA_KASRA', 'vowel_FATHA_KASRA', 'consonant',
              'shadda_missing', 'shadda_extra', 'sukun', 'missing_vowel']
HOP = 640

_REF = os.path.join(ROOT, 'assets/quran/recitation/phonetic_reference_hafs.json')
ref = json.load(open(_REF if os.path.exists(_REF) else os.path.join(HERE, 'phonetic_reference_hafs.json')))['ayahs']
VOCAB = ['', 'ء', 'ب', 'ت', 'ث', 'ج', 'ح', 'خ', 'د', 'ذ', 'ر', 'ز', 'س', 'ش', 'ص', 'ض', 'ط', 'ظ',
         'ع', 'غ', 'ف', 'ق', 'ك', 'ل', 'م', 'ن', 'ه', 'و', 'ي', 'ا', 'ۦ', 'ۥ', 'َ', 'ُ', 'ِ', '۪', 'ـ',
         'ٲ', 'ڇ', 'ں', '۾', 'ۜ', 'ؙ']
ID = {c: i for i, c in enumerate(VOCAB)}


def test_ayahs():
    return {c['ayahId'] for c in json.load(open(os.path.join(ART, 'bench_cases.json')))}


def audio(folder, aid):
    os.makedirs(CACHE, exist_ok=True)
    mp3 = os.path.join(CACHE, f'{folder}_{aid}.mp3')
    if not os.path.exists(mp3):
        url = f'https://everyayah.com/data/{folder}/{aid // 1000:03d}{aid % 1000:03d}.mp3'
        urllib.request.urlretrieve(url, mp3)
    pcm = subprocess.run(['ffmpeg', '-loglevel', 'error', '-i', mp3, '-ar', '16000', '-ac', '1',
                          '-f', 's16le', '-'], check=True, capture_output=True).stdout
    return np.frombuffer(pcm, dtype='<i2').astype(np.float32) / 32767


class Teacher:
    def __init__(self, path):
        import onnxruntime as ort
        so = ort.SessionOptions(); so.intra_op_num_threads = os.cpu_count()
        self.s = ort.InferenceSession(path, so)

    def frames(self, w, chunk=16000 * 20, overlap=16000 * 2):
        run = lambda x: self.s.run(None, {'waveform': x[None]})[0][0]
        if len(w) <= chunk:
            return run(w)
        parts, start = [], 0
        while True:
            lp = run(w[start:start + chunk]); end = start + chunk >= len(w)
            a = 0 if start == 0 else (overlap // 2) // HOP
            b = len(lp) if end else len(lp) - (overlap // 2) // HOP
            parts.append(lp[a:b])
            if end:
                return np.concatenate(parts)
            start += chunk - overlap


def tokens(aid):
    """(class, word, optional) per sound of the ayah, in order."""
    r = ref[str(aid)]
    return [(ID[t], ord(w) - 48, bool((ord(f) - 64) & (8 | 32)))
            for t, w, f in zip(r['t'], r['w'], r['f'])]


def align(lp, toks):
    """CTC Viterbi of the expected sounds (optional ones may be skipped): per word,
    (first frame, last frame), and the mean cost per frame vs the best path."""
    lab = [0]
    for c, _, _ in toks:
        lab += [c, 0]
    S, T = len(lab), len(lp)
    preds = [[i] for i in range(S)]
    for i in range(1, S):
        preds[i].append(i - 1)
        if i >= 2 and lab[i] != 0 and lab[i] != lab[i - 2]:
            preds[i].append(i - 2)
    for k, (_, _, opt) in enumerate(toks):
        if opt:
            i = 2 * k + 1
            preds[i + 1].append(i - 1)
            if i + 2 < S:
                preds[i + 2] += [i - 1] + ([i - 2] if i >= 2 and lab[i + 2] != lab[i - 2] else [])
    P = max(len(p) for p in preds)
    pidx = np.array([p + [p[0]] * (P - len(p)) for p in preds])
    emit = lp[:, lab]
    dp = np.full(S, -1e30); dp[0] = emit[0, 0]; dp[1] = emit[0, 1]
    back = np.zeros((T, S), dtype=np.int32)
    for t in range(1, T):
        cand = dp[pidx]
        a = cand.argmax(1)
        back[t] = pidx[np.arange(S), a]
        dp = cand[np.arange(S), a] + emit[t]
    s = S - 1 if dp[S - 1] >= dp[S - 2] else S - 2
    score = dp[s]
    spans = {}
    for t in range(T - 1, -1, -1):
        if s % 2 == 1:
            w = toks[s // 2][1]
            a, b = spans.get(w, (t, t))
            spans[w] = (t, max(b, t))
        s = back[t, s]
    cost = (lp.max(1).sum() - score) / T
    return spans, cost


def cut_points(spans, n_words, n_samples):
    """Per word, (start, end) samples: halfway into the gaps around it."""
    out = {}
    for w in range(n_words):
        if w not in spans:
            continue
        a, b = spans[w]
        prev = spans.get(w - 1, (a - 6, a - 6))[1]
        nxt = spans.get(w + 1, (b + 6, b + 6))[0]
        out[w] = (min(max(0, int((a + prev + 1) / 2 * HOP)), n_samples),
                  min(max(0, int((b + nxt + 1) / 2 * HOP)), n_samples))
    return out


def splice(ctx, cpos, src, spos, fade=160):
    a0, a1 = cpos; b0, b1 = spos
    seg = src[b0:b1].copy()
    r_ctx = np.sqrt(np.mean(ctx[a0:a1] ** 2) + 1e-9); r_seg = np.sqrt(np.mean(seg ** 2) + 1e-9)
    seg *= r_ctx / r_seg
    head, tail = ctx[:a0].copy(), ctx[a1:].copy()
    ramp = np.linspace(0, 1, fade, dtype=np.float32)
    if len(head) >= fade and len(seg) >= 2 * fade:
        seg[:fade] = seg[:fade] * ramp + head[-fade:] * (1 - ramp); head = head[:-fade]
    if len(tail) >= fade and len(seg) >= 2 * fade:
        seg[-fade:] = seg[-fade:] * (1 - ramp) + tail[:fade] * ramp; tail = tail[fade:]
    return np.concatenate([head, seg, tail]).astype(np.float32)


def main():
    p = argparse.ArgumentParser()
    p.add_argument('--per-category', type=int, default=40)
    p.add_argument('--clean-per-reciter', type=int, default=60)
    p.add_argument('--teacher', default=os.path.join(ART, 'optimized_int4_b32.onnx'))
    p.add_argument('--max-cost', type=float, default=0.6)
    a = p.parse_args()
    rng = random.Random(0)
    test = test_ayahs()
    teacher = Teacher(a.teacher)
    # ---- candidate pairs over every non-test ayah (interior words, short ayahs)
    pool, words, nwords = collections.defaultdict(list), {}, {}
    for key, row in ref.items():
        aid = int(key)
        if aid in test:
            continue
        ws = words_of(row)
        nwords[aid] = max(ws) + 1
        if nwords[aid] > 30:
            continue
        for w, snd in ws.items():
            words[(aid, w)] = snd
            if 0 < w < nwords[aid] - 1:
                pool[snd].append((aid, w))
    by_cat = collections.defaultdict(list)
    for snd, places in pool.items():
        for cat, r in edits(snd):
            if r in pool:
                by_cat[cat].append((snd, r))
    cache, cases, blobs = {}, [], []

    def get(folder, aid):
        k = (folder, aid)
        if k not in cache:
            w = audio(folder, aid)
            spans, cost = align(teacher.frames(w), tokens(aid))
            cache[k] = (w, cut_points(spans, nwords.get(aid) or (max(spans) + 1), len(w)), cost)
        return cache[k]

    def add(meta, w):
        cases.append(dict(meta, n=len(cases))); blobs.append(w)

    stats = collections.Counter()
    for cat in CATEGORIES:
        cand = by_cat[cat][:]
        rng.shuffle(cand)
        used_words, made = set(), 0
        for e, r in cand:
            if made >= a.per_category:
                break
            if e in used_words:
                continue
            ctx_aid, ctx_w = rng.choice(pool[e])
            src_aid, src_w = rng.choice(pool[r])
            if src_aid == ctx_aid:
                continue
            folder = PAIR_RECITERS[made % len(PAIR_RECITERS)]
            try:
                cw, cpos, ccost = get(folder, ctx_aid)
                sw, spos, scost = get(folder, src_aid)
            except Exception as ex:
                stats['download/decode failed'] += 1
                continue
            if ccost > a.max_cost or scost > a.max_cost or ctx_w not in cpos or src_w not in spos:
                stats['poor alignment'] += 1
                continue
            first, last = max(0, ctx_w - 3), min(nwords[ctx_aid] - 1, ctx_w + 3)
            if first not in cpos or last not in cpos:
                stats['poor alignment'] += 1
                continue
            w0, w1 = cpos[first][0], cpos[last][1]
            if w1 - w0 < 16000:
                stats['too short'] += 1
                continue
            used_words.add(e)
            spliced = splice(cw, cpos[ctx_w], sw, spos[src_w])
            shift = len(spliced) - len(cw)
            meta = dict(set='pairs', category=cat, ayahId=ctx_aid, firstWord=first, lastWord=last,
                        targetWords=[ctx_w], openStart=first > 0, openEnd=last < nwords[ctx_aid] - 1,
                        reciter=folder, expected=e, recited=r, srcAyahId=src_aid, srcWord=src_w)
            add(dict(meta, kind='spliced', name=f'{cat}_{made}'), spliced[w0:w1 + shift])
            add(dict(meta, kind='control', name=f'{cat}_{made}_control'), cw[w0:w1])
            made += 1
        stats[f'{cat} made'] = made
        print(cat, made, flush=True)
    # ---- correct recitation
    calib = [s * 1000 + x for s, x in calibration_ayahs()]
    others = [aid for aid in nwords if aid not in test and nwords[aid] <= 30]
    rng.shuffle(calib); rng.shuffle(others)
    for folder, ayahs in [(f, calib) for f in CLEAN_SEEN] + [(f, others) for f in CLEAN_UNSEEN]:
        made = 0
        for aid in ayahs:
            if made >= a.clean_per_reciter:
                break
            try:
                w, cpos, cost = get(folder, aid)
            except Exception:
                stats['download/decode failed'] += 1
                continue
            if cost > a.max_cost:
                stats['poor alignment'] += 1
                continue
            add(dict(set='clean', category='audio' if folder.startswith('Alafasy') else folder,
                     kind='clean', name=f'{folder}_{aid}', ayahId=aid, firstWord=0,
                     lastWord=nwords.get(aid, 1) - 1, targetWords=[], openStart=False,
                     openEnd=False, reciter=folder), w)
            made += 1
        stats[f'clean {folder}'] = made
        print('clean', folder, made, flush=True)
    for c in cases:
        c['screen'] = True
    json.dump(cases, open(os.path.join(ART, 'calib_cases.json'), 'w'), ensure_ascii=False)
    np.savez(os.path.join(ART, 'calib_audio.npz'), **{f'c{i}': b for i, b in enumerate(blobs)})
    # leakage check
    used = {c['ayahId'] for c in cases} | {c.get('srcAyahId') for c in cases if c.get('srcAyahId')}
    assert not (used & test), 'calibration ayah in the final test'
    seen = [c for c in cases if c.get('reciter') in CLEAN_SEEN]
    excluded = {s * 1000 + x for s, x in calibration_ayahs()}
    assert all(c['ayahId'] in excluded for c in seen), 'trained-on recording in calibration'
    print(json.dumps(stats, indent=1))


if __name__ == '__main__':
    main()
