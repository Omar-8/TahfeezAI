"""Diverse-reciter distillation data (v2.3 option 1): whole-surah recordings from
mp3quran.net, cut into ayahs by the teacher's forced alignment, written as training
shards in distill_student.py's format with EMPTY transcripts (the teacher's
probabilities are the target; these recitations have no dataset transcript).

Never used: any reciter in the training data, the calibration set (Shuraym, Ghamdi,
Shaatree, Maher) or the final test (Alafasy, Husary, Mansoori, Parhizgar); any ayah in
blocked_ayahs.json (the 417 benchmark-excluded ayahs + every calibration ayah, 873),
for every reciter.

  python diverse_data.py <out dir> --hours-per-reciter 3
"""
import argparse, json, os, random, subprocess, tempfile, urllib.request
import numpy as np
import torch, torch.nn.functional as F
import torchaudio

import distill_student as ds

HERE = os.path.dirname(os.path.abspath(__file__))
NON_NATIVE = ['Muamar (From Indonesia)', 'Mohammad Saleh Alim Shah', 'Akhil Abdulhayy Rawa', 'Ustaz Zamri',
              'Rodziah Abdulrahman', 'Rogayah Sulong', 'Sapinah Mamat', 'Saidin Abdulrahman',
              'Abdullah Fahmi', 'Muhammad Al-Hafiz', 'Mohammed Hafas Ali', 'Muhammed Khairul Anuar',
              'Mohammed Osman Khan', 'Haroon Baqai', 'Abdulhadi Kanakeri', 'Abdulwadood Haneef',
              'Alijon Qori', 'Mohammad Dibirov', 'Zaki Daghistani', 'Shirazad Taher',
              'Peshawa Qadr Al-Kurdi', 'Raad Al Kurdi', 'Wishear Hayder Arbili', 'Sayed Ahmad Hashemi',
              'Khalid Mohammadi', 'Issa Omar Sanankoua', 'Junaid Adam Abdullah', 'Yousef Bin Noah Ahmad']
NATIVE = ['Abdullah Basfer', 'Abdullah Al-Mattrod', 'Abdullah Al-Johany', 'Ahmad Al-Ajmy', 'Ali Jaber',
          'Fares Abbad', 'Hani Arrifai', 'Khaled Al-Qahtani', 'Mohammed Jibreel', 'Nasser Alqatami',
          # v2.4: more native reciters, none in the training data / calibration / test
          'Akram Alalaqmi', 'Majed Al-Enezi', 'Mohammed Al-Lohaidan', 'Mohammed Al-Muhasny',
          'Idrees Abkr', 'Mustafa Al-Lahoni', 'Muftah Alsaltany', 'Hatem Fareed Alwaer',
          'Ibrahim Aldosari', 'Tawfeeq As-Sayegh', 'Khalid Almohana', 'Adel Al-Khalbany',
          'Mousa Bilal', 'Ahmed Al-trabulsi', 'Mohammad Rashad Alshareef', 'Abdulbadi Ghailan',
          'Muhammad Burhaji', 'Hassan Aldaghriri', 'Khalid Alziyadi', 'Mohammed Al-Zubaidi',
          'Sahl Yassin', 'Slaah Bukhatir', 'Salah Albudair', 'Yasser Al-Dosari',
          'Mohammad Al-Tablaway', 'Abdulmohsen Al-Qasim', 'Alzain Mohammad Ahmad', 'Ibrahim Aljormy']
MAX_SURAH_S = 12 * 60     # one forced alignment up to this; longer surahs in windows
WINDOW_FRAMES = 6000      # 4 min: long surahs are aligned window by window
MAX_COST = 0.6


def reciters():
    api = json.load(urllib.request.urlopen('https://www.mp3quran.net/api/v3/reciters?language=eng'))
    out = {}
    for r in api['reciters']:
        for m in r['moshaf']:
            if r['name'] in NON_NATIVE + NATIVE and "Hafs A'n Assem - Murattal" in m['name']:
                out[r['name']] = (m['server'], [int(s) for s in m['surah_list'].split(',')])
    return out


def fetch(url):
    with tempfile.NamedTemporaryFile(suffix='.mp3') as f:
        subprocess.run(['curl', '-sL', '--max-time', '300', '-o', f.name, url], check=True)
        pcm = subprocess.run(['ffmpeg', '-loglevel', 'error', '-i', f.name, '-ar', '16000', '-ac', '1',
                              '-f', 's16le', '-'], check=True, capture_output=True).stdout
    return np.frombuffer(pcm, dtype='<i2').astype(np.float32) / 32767


def teacher_frames(t, fe, w, chunk=16000 * 20, overlap=16000 * 2, hop=640):
    parts, start = [], 0
    while True:
        seg = w[start:start + chunk]
        x, mask = ds.featurize(fe, [(seg, [])])
        with torch.no_grad():
            lp = F.log_softmax(t.model(input_features=x.to(t.model.dtype), attention_mask=mask,
                                       return_dict=False)[0]['phonemes'].float(), -1)[0]
        end = start + chunk >= len(w)
        a = 0 if start == 0 else (overlap // 2) // hop
        b = lp.shape[0] if end else lp.shape[0] - (overlap // 2) // hop
        parts.append(lp[a:b])
        if end:
            return torch.cat(parts)
        start += chunk - overlap


def surah_tokens(ref, surah, n_ayahs):
    """Token ids and, per token, its ayah (0 = the basmala before the surah)."""
    toks, owner = [], []
    ayahs = ([(1001, 0)] if surah not in (1, 9) else []) + [(surah * 1000 + a, a) for a in range(1, n_ayahs + 1)]
    for aid, a in ayahs:
        row = ref[str(aid)]
        seq = [(c, (ord(f) - 64)) for c, f in zip(row['t'], row['f']) if not (ord(f) - 64) & 8]
        if seq and seq[-1][1] & 32:                 # ayah-final vowel: dropped at the pause
            seq = seq[:-1]
        for c, _ in seq:
            toks.append(ds.ID[c]); owner.append(a)
    return toks, owner


def viterbi_prefix(lp, toks, ends):
    """CTC Viterbi of lp (frames x classes, torch) against a PREFIX of toks that ends
    at a token in [ends] (ayah boundaries): the best path through all frames ending
    after any of those tokens. Per frame, the token index (or -1 for blank)."""
    lab = [0]
    for t in toks:
        lab += [t, 0]
    lab_t = torch.tensor(lab, device=lp.device)
    S, T = len(lab), lp.shape[0]
    skip = torch.zeros(S, dtype=torch.bool, device=lp.device)
    for i in range(2, S):
        skip[i] = lab[i] != 0 and lab[i] != lab[i - 2]
    neg = torch.tensor(-1e30, device=lp.device)
    dp = torch.full((S,), -1e30, device=lp.device)
    emit = lp[:, lab_t]
    dp[0], dp[1] = emit[0, 0], emit[0, 1]
    back = torch.empty((T, S), dtype=torch.uint8, device=lp.device)
    back[0] = 0
    for f in range(1, T):
        a = dp
        b = torch.cat([neg[None], dp[:-1]])
        c = torch.where(skip, torch.cat([neg[None], neg[None], dp[:-2]]), neg)
        stack = torch.stack([a, b, c])
        best, arg = stack.max(0)
        back[f] = arg.to(torch.uint8)
        dp = best + emit[f]
    cand = torch.tensor(sorted({2 * k + 1 for k in ends} | {2 * k + 2 for k in ends}), device=lp.device)
    state = int(cand[dp[cand].argmax()])
    back = back.cpu().numpy()
    path = np.full(T, -1)
    for f in range(T - 1, -1, -1):
        if state % 2 == 1:
            path[f] = state // 2
        state -= int(back[f, state])
    return path


def spans_long(lp, toks, owner):
    """Ayah spans for a long recording: windows of WINDOW_FRAMES, each aligned to the
    next ayahs ending at an ayah boundary; the window's last ayah is dropped (it may be
    cut) and the next window starts at its first frame."""
    lpn = lp.cpu().numpy()
    first_tok = {}
    for k, o in enumerate(owner):
        first_tok.setdefault(o, k)
    order = sorted(first_tok)
    spans, f0, i = {}, 0, 0
    while i < len(order) and f0 < lp.shape[0] - 25:
        f1 = min(lp.shape[0], f0 + WINDOW_FRAMES)
        last_window = f1 == lp.shape[0]
        k0 = first_tok[order[i]]
        budget = int((f1 - f0) * 0.6)              # more tokens than the window can hold
        k1 = min(len(toks), k0 + budget)
        ends = [first_tok[o] - 1 - k0 for o in order[i + 1:] if first_tok[o] <= k1] + [k1 - k0 - 1]
        ends = [e for e in ends if e >= 0]
        path = viterbi_prefix(lp[f0:f1], toks[k0:k1], ends)
        got = {}
        for f, k in enumerate(path):
            if k < 0:
                continue
            o = owner[k0 + k]
            lo, hi, cost, n = got.get(o, (f0 + f, f0 + f, 0.0, 0))
            lab = toks[k0 + k]
            got[o] = (lo, f0 + f, cost + float(lpn[f0 + f].max() - lpn[f0 + f, lab]), n + 1)
        done = sorted(got)
        if not done:
            break
        keep = done if last_window else done[:-1]
        for o in keep:
            spans[o] = got[o]
        if last_window or not keep:
            break
        nxt = done[-1]                              # restart at the dropped ayah
        i = order.index(nxt)
        f0 = got[nxt][0]
    return spans


def main():
    p = argparse.ArgumentParser()
    p.add_argument('out')
    p.add_argument('--hours-per-reciter', type=float, default=3.0)
    p.add_argument('--hours-non-native', type=float, default=None,
                   help='hours per non-native reciter (default: --hours-per-reciter)')
    p.add_argument('--part', type=int, default=0)
    p.add_argument('--parts', type=int, default=1, help='split the reciters over parallel builders')
    p.add_argument('--shard-clips', type=int, default=2000)
    p.add_argument('--first-shard', type=int, default=0,
                   help='number of this part\'s first shard (continuing a run)')
    p.add_argument('--skip-done', action='store_true',
                   help='skip the reciters already in this part\'s log (continuing a run)')
    a = p.parse_args()
    os.makedirs(a.out, exist_ok=True)
    ref = json.load(open(os.path.join(HERE, 'phonetic_reference_hafs.json')))['ayahs']
    blocked = {tuple(x) for x in json.load(open(os.path.join(HERE, 'blocked_ayahs.json')))}
    counts = {s: sum(1 for k in ref if int(k) // 1000 == s) for s in range(1, 115)}
    t = ds.load_teacher()
    fe = getattr(t.processor, 'feature_extractor', t.processor)
    shard, n_shard, stats = [], a.first_shard, {}
    log = open(os.path.join(a.out, f'diverse_{a.part}.log'), 'a')

    def flush():
        nonlocal shard, n_shard
        if not shard:
            return
        np.savez(os.path.join(a.out, f'shard_{9000 + 100 * a.part + n_shard:04d}.npz'),
                 audio=np.concatenate([x for x, _, _ in shard]).astype(np.int16),
                 offsets=np.cumsum([0] + [len(x) for x, _, _ in shard]),
                 targets=np.array([[] for _ in shard] + [None], dtype=object)[:-1],
                 ayahs=np.array([aid for _, _, aid in shard], np.int32))
        n_shard += 1; shard = []

    rng = random.Random(0)
    todo = sorted(reciters().items())[a.part::a.parts]
    if a.skip_done:
        logp = os.path.join(a.out, f'diverse_{a.part}.log')
        done = {l.split(' {')[0] for l in open(logp)} if os.path.exists(logp) else set()
        todo = [r for r in todo if r[0] not in done]
    for name, (server, surahs) in todo:
        limit = (a.hours_non_native or a.hours_per_reciter) if name in NON_NATIVE else a.hours_per_reciter
        got, kept = 0.0, 0
        why = {'basmala': 0, 'blocked': 0, 'poor fit': 0, 'length': 0}
        order = surahs[:]; rng.shuffle(order)
        for s in order:
            if got >= limit * 3600:
                break
            try:
                w = fetch(f'{server}{s:03d}.mp3')
            except Exception:
                continue
            if len(w) < 16000 or len(w) > 3 * 3600 * 16000:
                continue
            lp = teacher_frames(t, fe, w)
            toks, owner = surah_tokens(ref, s, counts[s])
            if len(w) > MAX_SURAH_S * 16000:
                try:
                    span = spans_long(lp, toks, owner)
                except Exception:
                    continue
            else:
                if len(toks) * 2 >= lp.shape[0]:
                    continue
                try:
                    labels, _ = torchaudio.functional.forced_align(
                        lp[None], torch.tensor([toks], device=lp.device), blank=0)
                except Exception:
                    continue
                path = labels[0].cpu().numpy()
                lpn = lp.cpu().numpy()
                # token index per frame (CTC path -> token position)
                span = {}
                k, prev = -1, 0
                for f, lab in enumerate(path):
                    if lab != 0 and (lab != prev or k < 0):
                        k += 1
                    if lab != 0:
                        o = owner[k]
                        lo, hi, cost, n = span.get(o, (f, f, 0.0, 0))
                        span[o] = (lo, f, cost + float(lpn[f].max() - lpn[f, lab]), n + 1)
                    prev = lab
            ayahs = sorted(span)
            for i, o in enumerate(ayahs):
                lo, hi, cost, n = span[o]
                if o == 0:
                    why['basmala'] += 1; continue
                if (s, o) in blocked:
                    why['blocked'] += 1; continue
                if cost / max(1, n) > MAX_COST:
                    why['poor fit'] += 1; continue
                # The ayah's speech plus up to 0.32 s each side (never into the
                # neighbours: some recordings leave long pauses between ayahs).
                prev_hi = span[ayahs[i - 1]][1] if i > 0 else -1
                next_lo = span[ayahs[i + 1]][0] if i + 1 < len(ayahs) else lp.shape[0]
                a0 = max(lo - 8, (prev_hi + lo) // 2 if i > 0 else 0)
                a1 = min(hi + 8, (hi + next_lo) // 2 if i + 1 < len(ayahs) else lp.shape[0] - 1)
                clip = w[a0 * 640:(a1 + 1) * 640]
                if not 1 <= len(clip) / 16000 <= 20:
                    why['length'] += 1; continue
                shard.append(((np.clip(clip, -1, 1) * 32767).astype(np.int16), [], s * 1000 + o))
                got += len(clip) / 16000; kept += 1
                if len(shard) == a.shard_clips:
                    flush()
        stats[name] = dict(hours=round(got / 3600, 2), kept=kept, **why)
        print(name, stats[name], flush=True); log.write(f'{name} {stats[name]}\n'); log.flush()
    flush()
    json.dump(stats, open(os.path.join(a.out, f'diverse_stats_{a.part}_{a.first_shard}.json'), 'w'), indent=1)
    print('done', round(sum(v['hours'] for v in stats.values()), 2), 'h')


if __name__ == '__main__':
    main()
