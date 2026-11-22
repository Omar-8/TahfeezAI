"""Ayah timings for a reciter recorded by whole surahs (owner, 2026-11-21:
Islam Sobhi, mp3quran.net): where each ayah starts and ends in its surah's
file, found with the app's own acoustic model (CTC forced alignment of the
expected Hafs phonemes, acoustic.reference) — so the app can play it ayah by
ayah, cut from the surah.

  .venv/bin/python align_surah_audio.py <folder of 001.mp3 …> <out.json>
        [--surahs 1,112] [--threads 16]

The model runs over each file in 20 s windows (its longest), each streamed
as the app does (1.28 s chunks). Then ayah by ayah: a window from the last ayah's end,
long enough for this ayah and the next one's start, aligned with free
"anything" frames before (a pause, the istiʿādhah) and after; the ayah's
first and last sounds give its span. A surah's Bismillah (not at-Tawbah's)
is aligned first and kept as the start of its first ayah.

Writes {"<surah>": [[start_ms, end_ms], …], "noBasmala": [3, …]} (each ayah
in order; a surah's first span starting at its Bismillah — "noBasmala": the
files that open without one, heard by the model) with a per-surah check: the mean
log-likelihood per frame of each ayah against the best class, the worst
ones listed (a low one: a misaligned ayah, worth a listen).
"""
import argparse, json, os, subprocess, sys, time

import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
from acoustic import BLANK, reference  # noqa: E402
from quran_transcript import Aya  # noqa: E402

ROOT = os.path.abspath(os.path.join(HERE, '..', '..'))
MODEL = os.path.join(ROOT, 'assets/models/quran_acoustic.onnx')
CFG = os.path.join(ROOT, 'assets/models/quran_acoustic.json')
FRAME_MS = 40
COUNTS = [7, 286, 200, 176, 120, 165, 206, 75, 129, 109, 123, 111, 43, 52, 99, 128, 111, 110, 98, 135, 112, 78, 118, 64, 77, 227, 93, 88, 69, 60, 34, 30, 73, 54, 45, 83, 182, 88, 75, 85, 54, 53, 89, 59, 37, 35, 38, 29, 18, 45, 60, 49, 62, 55, 78, 96, 29, 22, 24, 13, 14, 11, 11, 18, 12, 12, 30, 52, 52, 44, 28, 28, 20, 56, 40, 31, 50, 40, 46, 42, 29, 19, 36, 25, 22, 17, 19, 26, 30, 20, 15, 21, 11, 8, 8, 19, 5, 8, 8, 11, 11, 8, 3, 9, 5, 4, 7, 3, 6, 3, 5, 4, 5, 6]
STRETCH = set()  # filled below: madd / ghunnah labels a token may repeat
NEXT_TOKENS = 30   # the next ayah's first sounds, aligned with this one
GARBAGE_PENALTY = 1.0  # per frame, "anything" against the best class
MAX_LEAD = 250     # frames (10 s): the longest pause before an ayah
WHOLE_LIMIT = 1_500_000_000  # bytes of back-pointers: whole-surah alignment


def decode(path):
    raw = subprocess.run(['ffmpeg', '-v', 'error', '-i', path, '-ac', '1', '-ar', '16000',
                          '-f', 'f32le', '-'], capture_output=True, check=True).stdout
    return np.frombuffer(raw, np.float32)


class Model:
    names = ['sums', 'count', 'kv', 'conv', 'akv', 'aconv', 'valid']

    def __init__(self, threads):
        import onnxruntime as ort
        so = ort.SessionOptions()
        so.intra_op_num_threads = threads
        self.s = ort.InferenceSession(MODEL, so)
        meta = json.load(open(CFG))
        self.cfg = meta['stream']
        vocab = meta['vocabulary']
        for c in ('ا', 'ۦ', 'ۥ', 'ں'):
            STRETCH.add(vocab.index(c))

    def logprobs(self, w):
        """The whole file in 20 s windows (the model's longest), each from a
        fresh state, overlapping 4 s, the middle of each kept — twice, the
        second run's windows 10 s later, the two averaged: a window's
        start can leave the model deaf to a stretch (1:2's "al-ḥamdu
        lillāh", heard from 8 s on, missed from 0 s), rarely in both."""
        a = self._windows(w, 0)
        b = self._windows(w, 10 * 16000)
        n = min(len(a), len(b))
        return np.logaddexp(a[:n], b[:n]) - np.log(2)

    def _windows(self, w, phase):
        win, ov = 20 * 16000, 4 * 16000
        cut = (ov // 2) // 640
        parts = []
        if phase:
            # the first stretch alone, then windows from [phase]
            head = self._stream(w[:phase + ov // 2])
            parts.append(head[:phase // 640])
            start = phase - ov // 2
        else:
            start = 0
        if len(w) - start <= win:
            lp = self._stream(w[start:])
            parts.append(lp[cut if start else 0:])
            return np.concatenate(parts)
        while True:
            lp = self._stream(w[start:start + win])
            end = start + win >= len(w)
            first = 0 if start == 0 else cut
            # (Counted from the window's start: its last frame, wanting
            # audio past its end, never comes — no drift, window by window.)
            last = len(lp) if end else win // 640 - cut
            parts.append(lp[first:last])
            if end:
                return np.concatenate(parts)
            start += win - ov

    def _stream(self, w):
        cfg = self.cfg
        st = {k: np.zeros(cfg['state'][k], np.float32) for k in self.names}
        st['sums'] = np.array(cfg['initial']['sums'], np.float32)
        st['count'] = np.array(cfg['initial']['count'], np.float32)
        hop, outs, start = cfg['chunk_samples'], [], 0
        while start + 400 <= len(w):
            seg = w[start:start + hop + cfg['overlap_samples']]
            n = ((len(seg) - 400) // 160 + 1) // 4 * 4
            if n == 0:
                break
            res = self.s.run(None, dict(samples=seg[:160 * (n - 1) + 400][None], **st))
            outs.append(res[0][0])
            st = dict(zip(self.names, res[1:]))
            start += hop
        return np.concatenate(outs)


def greedy(lp):
    """The model's best reading of [lp], a sound held or repeated as one."""
    out, prev = [], None
    for i in lp.argmax(1):
        if i != prev and i != BLANK:
            out.append(int(i))
        prev = i
    return squeeze(out)


def squeeze(seq):
    return [x for k, x in enumerate(seq) if k == 0 or seq[k - 1] != x]


def dist(a, b):
    """Edit distance."""
    d = list(range(len(b) + 1))
    for i, x in enumerate(a, 1):
        prev, d[0] = d[0], i
        for j, y in enumerate(b, 1):
            prev, d[j] = d[j], min(d[j] + 1, d[j - 1] + 1, prev + (x != y))
    return d[-1]


def labels_of(uthmani):
    """The ayah's expected sounds (optional markers left out)."""
    return [t.label for t in reference(uthmani) if not t.optional]


def align(lp, segments, max_lead=None):
    """Viterbi over: anything, segment 0's sounds, segment 1's …, anything.
    Returns each segment's (first frame, last frame). [max_lead]: frames the
    "anything" before may last at most (an ayah follows the last one within
    a pause — not, skipping on, at a later repetition of the same words:
    Ar-Raḥmān's refrain)."""
    labs, seg_of = [], []
    for i, seg in enumerate(segments):
        for l in seg:
            labs += [BLANK, l]
            seg_of += [-1, i]
    labs.append(BLANK)
    seg_of.append(-1)
    lab = np.array(labs)
    S = len(lab) + 2   # 0: anything before, S-1: anything after
    T = len(lp)
    NEG = -1e30
    garbage = lp.max(1) - GARBAGE_PENALTY
    # skip over a blank: a sound after another, different one
    skip = np.zeros(S, bool)
    for s in range(3, S - 1):
        k = s - 1
        skip[s] = lab[k] != BLANK and k >= 2 and lab[k] != lab[k - 2]
    back_ok = np.zeros(S, bool)  # a stretchable sound again after its blank
    for s in range(1, S - 2):
        k = s - 1
        if lab[k] != BLANK and lab[k] in STRETCH:
            back_ok[s] = True
    dp = np.full(S, NEG)
    dp[0] = garbage[0]
    dp[1] = lp[0, lab[0]]
    dp[2] = lp[0, lab[1]]
    back = np.zeros((T, S), np.int8)  # 0 stay, 1 from s-1, 2 from s-2, 3 from s+1
    emit_idx = np.concatenate([[0], lab, [0]])
    for t in range(1, T):
        e = lp[t, emit_idx]
        e[0] = garbage[t] if max_lead is None or t < max_lead else NEG
        e[-1] = garbage[t]
        c0 = dp
        c1 = np.concatenate([[NEG], dp[:-1]])
        c2 = np.where(skip, np.concatenate([[NEG, NEG], dp[:-2]]), NEG)
        c3 = np.where(back_ok, np.concatenate([dp[1:], [NEG]]), NEG)
        # anything before → first blank or first sound
        c2[2] = max(c2[2], dp[0])
        # last blank or last sound → anything after
        c2[-1] = max(c2[-1], dp[-3])
        stack = np.stack([c0, c1, c2, c3])
        arg = stack.argmax(0)
        dp = stack[arg, np.arange(S)] + e
        back[t] = arg
    end = S - 1 if dp[S - 1] >= max(dp[S - 2], dp[S - 3]) else (S - 2 if dp[S - 2] >= dp[S - 3] else S - 3)
    s = end
    first = [None] * len(segments)
    last = [None] * len(segments)
    for t in range(T - 1, -1, -1):
        k = s - 1
        if 0 <= k < len(seg_of) and seg_of[k] >= 0:
            i = seg_of[k]
            first[i] = t
            if last[i] is None:
                last[i] = t
        if t == 0:
            break
        a = back[t, s]
        if s == 2 and a == 2:
            s = 0
        elif s == S - 1 and a == 2:
            s = S - 3
        else:
            s = s - (1, 1, 2, -1)[a] if a else s
    return list(zip(first, last))


def loudness(w):
    """Each 40 ms frame's level (dB), and the level below which it is a
    pause: 30 dB under the loud speech (the 95th percentile)."""
    n = len(w) // 640
    fr = w[:n * 640].reshape(n, 640)
    db = 10 * np.log10(np.mean(fr * fr, 1) + 1e-10)
    return db, np.percentile(db, 95) - 30


# The istiʿādhah ("aʿūdhu billāhi mina sh-shayṭāni r-rajīm"), recited before
# many surahs: its sounds as the model spells them (no Quran text — not an
# ayah — so written out here).
ISTIADHA_SOUNDS = 'ءَعُۥذُبِللَاهِمِنَششَيطَانِررَجِۦم'


def istiadha_labels():
    vocab = json.load(open(CFG))['vocabulary']
    return [vocab.index(c) for c in ISTIADHA_SOUNDS]


def heard_as(lp, span, labels, limit=0.45):
    """Whether the model's reading of [span] is [labels]'s."""
    if span[0] is None:
        return False
    want = squeeze(labels)
    return dist(greedy(lp[span[0]:span[1] + 1]), want) / len(want) < limit


def surah_spans(lp, surah, texts, db=None, quiet=None, n=None):
    n = n or COUNTS[surah - 1]
    ayah_labels = [labels_of(texts[a]) for a in range(1, n + 1)]
    basmala = labels_of(Aya(1, 1).get().uthmani) if surah not in (1, 9) else None
    rate = 2.6   # frames per sound, refined as it goes
    pos = 0
    spans, scores = [], []
    first_start = None
    has_basmala = False
    # The opening: the istiʿādhah, if said (42 — its ayah 1, "Ḥā Mīm", had
    # been matched to it), then the Bismillah, if recited (not in 3, 112…).
    isti = istiadha_labels()
    head = lp[:int((len(isti) + (len(basmala) if basmala else 0)) * rate * 3 + 900)]
    first = ayah_labels[0][:NEXT_TOKENS]
    r = align(head, [isti] + ([basmala] if basmala else []) + [first])
    if heard_as(lp, r[0], isti):
        pos = r[0][1] + 1
        if basmala and heard_as(lp, r[1], basmala):
            has_basmala = True
            (b0, b1) = r[1]
    elif basmala:
        r = align(head, [basmala, first])
        if heard_as(lp, r[0], basmala):
            has_basmala = True
            (b0, b1) = r[0]
    if has_basmala:
        first_start, pos = b0, b1 + 1
        # (Back to the voice's start — 0.3 s at most: an istiʿādhah said
        # without a pause before it is not the Bismillah's.)
        if db is not None:
            floor = max(0, b0 - 300 // FRAME_MS)
            while first_start > floor and db[first_start - 1] > quiet:
                first_start -= 1
    # The whole rest of the surah at once, where it fits in memory (the
    # back-pointers: frames × states bytes): every ayah in its place, none
    # skipped — ayah by ayah, Ar-Raḥmān's refrain and its look-alike verses
    # let the window slip by one (55:46).
    rest = lp[pos:]
    labels_total = sum(len(x) for x in ayah_labels)
    if len(rest) * (2 * labels_total + 3) <= WHOLE_LIMIT:
        r = align(rest, ayah_labels)
        for a in range(n):
            s0, s1 = r[a]
            start, end = pos + s0, pos + s1
            nstart = pos + r[a + 1][0] if a + 1 < n else None
            scores.append(float(np.mean(lp[start:end + 1].max(1))))
            spans.append([start, end, nstart])
        n = 0  # (done: the ayah-by-ayah loop below is skipped)
    for a in range(n):
        cur = ayah_labels[a]
        nxt = ayah_labels[a + 1][:NEXT_TOKENS] if a + 1 < n else None
        need = len(cur) + (len(nxt) if nxt else 0)
        length = int(need * rate * 2.2 + 400)
        win = lp[pos:pos + length]
        segs = [cur] + ([nxt] if nxt else [])
        r = align(win, segs, max_lead=MAX_LEAD)
        (s0, s1) = r[0]
        start, end = pos + s0, pos + s1
        nstart = pos + r[1][0] if nxt else None
        # a frame's likelihood against the best class, over the ayah
        seg = lp[start:end + 1]
        scores.append(float(np.mean(seg.max(1))))
        spans.append([start, end, nstart])
        rate = 0.8 * rate + 0.2 * max(1.2, min(6.0, (end - start + 1) / max(1, len(cur))))
        pos = end + 1
    total = len(lp)
    # The voice itself: an ayah's last sound recognised before it ends (a
    # held madd, a ghunnah) — on to the pause; its first one a little after
    # it begins — back to it. Never past the neighbours' sounds.
    if db is not None:
        loud = db > quiet
        for i, sp in enumerate(spans):
            s0, s1, nstart = sp
            limit = (nstart if nstart is not None else total) - 1
            while s1 + 1 < min(limit, len(loud)) and loud[s1 + 1:s1 + 6].any():
                s1 += 1
            # (0.3 s at most: not into a sound said just before.)
            floor = max(spans[i - 1][1] + 1 if i else 0, s0 - 300 // FRAME_MS)
            if i == 0 and first_start is not None:
                floor = s0
            while s0 - 1 > floor and loud[s0 - 1]:
                s0 -= 1
            sp[0], sp[1] = s0, s1
    # frames → ms, a margin into each pause (half of it, at most 0.4 s / 0.25 s)
    out = []
    for i, (s0, s1, nstart) in enumerate(spans):
        prev_end = spans[i - 1][1] if i else None
        gap_before = (s0 - prev_end - 1) if prev_end is not None else s0
        gap_after = ((nstart if nstart is not None else total) - s1 - 1)
        begin = s0 - min(gap_before // 2, 250 // FRAME_MS)
        if i == 0 and first_start is not None:
            begin = first_start - min(first_start // 2, 250 // FRAME_MS)
        finish = s1 + 1 + min(gap_after // 2, 400 // FRAME_MS)
        out.append([max(0, begin) * FRAME_MS, finish * FRAME_MS])
    return out, scores, bool(basmala) and not has_basmala


def fix_openings(model, folder, result, surahs, seconds=90):
    """Re-aligns each surah's first [seconds] (after a fix to how openings
    are found) and takes the new spans up to where they meet the old ones
    again: the rest of the surah is unchanged."""
    changed = {}
    for surah in surahs:
        old = result.get(str(surah))
        if old is None:
            continue
        w = decode(os.path.join(folder, f'{surah:03d}.mp3'))[:seconds * 16000]
        lp = model.logprobs(w)
        k = sum(1 for sp in old if sp[1] < (seconds - 15) * 1000)
        if k == 0:
            continue
        texts = {a: Aya(surah, a).get().uthmani for a in range(1, min(k + 1, COUNTS[surah - 1]) + 1)}
        db, quiet = loudness(w)
        new, _, no_basmala = surah_spans(lp, surah, texts, db, quiet, n=min(k + 1, COUNTS[surah - 1]))
        took = 0
        for i in range(min(k, len(new))):
            if abs(new[i][0] - old[i][0]) <= 300 and abs(new[i][1] - old[i][1]) <= 300 and i > 0:
                break
            old[i] = new[i]
            took = i + 1
        nb = set(result.get('noBasmala', []))
        nb = (nb | {surah}) if no_basmala else (nb - {surah})
        result['noBasmala'] = sorted(nb)
        if took:
            changed[surah] = took
        print(f'{surah}: {took} opening span(s) replaced'
              f'{", no Bismillah" if no_basmala else ""}', flush=True)
    return changed


def main():
    p = argparse.ArgumentParser()
    p.add_argument('folder')
    p.add_argument('out')
    p.add_argument('--surahs', default='')
    p.add_argument('--threads', type=int, default=os.cpu_count())
    p.add_argument('--openings', action='store_true',
                   help='only re-align each surah\'s opening (fix_openings)')
    a = p.parse_args()
    model = Model(a.threads)
    result = json.load(open(a.out)) if os.path.exists(a.out) else {}
    wanted = [int(x) for x in a.surahs.split(',')] if a.surahs else range(1, 115)
    if a.openings:
        fix_openings(model, a.folder, result, wanted)
        json.dump(result, open(a.out, 'w'), separators=(',', ':'))
        return
    report = {}
    for surah in wanted:
        path = os.path.join(a.folder, f'{surah:03d}.mp3')
        if not os.path.exists(path) or str(surah) in result:
            continue
        t0 = time.time()
        w = decode(path)
        lp = model.logprobs(w)
        t1 = time.time()
        texts = {k: Aya(surah, k).get().uthmani for k in range(1, COUNTS[surah - 1] + 1)}
        db, quiet = loudness(w)
        spans, scores, no_basmala = surah_spans(lp, surah, texts, db, quiet)
        result[str(surah)] = spans
        # The surahs whose file has no Bismillah of his (played before).
        result['noBasmala'] = sorted(
            set(result.get('noBasmala', [])) - {surah} | ({surah} if no_basmala else set()))
        worst = sorted(range(len(scores)), key=lambda i: scores[i])[:3]
        report[surah] = [(i + 1, round(scores[i], 2)) for i in worst]
        # Each cut between two ayahs in a pause (quiet within 0.12 s)?
        loud = db > quiet
        unpaused = [i + 1 for i in range(len(spans) - 1)
                    if loud[max(0, spans[i][1] // FRAME_MS - 3):spans[i][1] // FRAME_MS + 3].all()]
        report[surah] = (report[surah], unpaused)
        json.dump(result, open(a.out, 'w'), separators=(',', ':'))
        print(f'{surah:3d}: {len(w) / 16000:7.0f} s audio, model {t1 - t0:5.0f} s, '
              f'align {time.time() - t1:5.0f} s; end {spans[-1][1] / 1000:.0f} s; '
              f'worst {report[surah][0]}; cut not in a pause after '
              f'{len(report[surah][1])}/{len(spans) - 1}: {report[surah][1][:12]}', flush=True)


if __name__ == '__main__':
    main()
