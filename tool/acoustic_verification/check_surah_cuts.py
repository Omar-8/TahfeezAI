"""Checks ayah timings (align_surah_audio.py's output) by ear, as the model
hears it: each ayah's clip is decoded — its first and last 8 s, each from a
fresh model state — and compared (edit distance) with the expected opening
and closing sounds of that ayah and of its neighbours. A cut is right when
its own ayah matches best.

  .venv/bin/python check_surah_cuts.py <folder> <timings.json> [--surahs 3]
"""
import argparse, json, os, sys
import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import align_surah_audio as A  # noqa: E402
from quran_transcript import Aya  # noqa: E402
from acoustic import BLANK  # noqa: E402

N = 14  # sounds compared at each end


def greedy(lp):
    out, prev = [], None
    for i in lp.argmax(1):
        if i != prev and i != BLANK:
            out.append(int(i))
        prev = i
    return squeeze(out)


def squeeze(seq):
    """A sound repeated (a held madd spelled again and again; a doubled
    letter) as one."""
    return [x for k, x in enumerate(seq) if k == 0 or seq[k - 1] != x]


def dist(a, b):
    d = list(range(len(b) + 1))
    for i, x in enumerate(a, 1):
        prev, d[0] = d[0], i
        for j, y in enumerate(b, 1):
            prev, d[j] = d[j], min(d[j] + 1, d[j - 1] + 1, prev + (x != y))
    return d[-1]


def main():
    p = argparse.ArgumentParser()
    p.add_argument('folder'); p.add_argument('timings')
    p.add_argument('--surahs', default='')
    p.add_argument('--first', type=int, default=0,
                   help='only each surah\'s first N ayahs (its opening)')
    a = p.parse_args()
    model = A.Model(8)
    timings = json.load(open(a.timings))
    surahs = [int(s) for s in a.surahs.split(',')] if a.surahs else sorted(int(k) for k in timings if k.isdigit())
    no_basmala = set(timings.get('noBasmala', []))
    total = bad = 0
    for surah in surahs:
        spans = timings[str(surah)]
        w = A.decode(os.path.join(a.folder, f'{surah:03d}.mp3'))
        labs = [squeeze(A.labels_of(Aya(surah, k).get().uthmani)) for k in range(1, len(spans) + 1)]
        basmala = squeeze(A.labels_of(Aya(1, 1).get().uthmani))
        wrong = []
        for i, (s0, s1) in enumerate(spans):
            if a.first and i >= a.first:
                break
            clip = w[s0 * 16:s1 * 16]
            # (8 s: a held madd alone can fill 3.)
            head = greedy(model._stream(clip[:8 * 16000]))[:N + 4]
            tail = greedy(model._stream(clip[-8 * 16000:]))[-(N + 4):]
            def ok(seq, end):
                cands = {j: (labs[j][-N:] if end else labs[j][:N]) for j in (i - 1, i, i + 1) if 0 <= j < len(labs)}
                if not end and i == 0 and surah not in (1, 9) and surah not in no_basmala:
                    cands = {i: basmala[:N]}  # the first clip opens with the Bismillah
                scores = {j: dist(seq[-len(c):] if end else seq[:len(c)], c) / max(1, len(c)) for j, c in cands.items()}
                # (Its own best, a tie too: neighbours can open alike.)
                return scores[i] <= min(scores.values()) and scores[i] < 0.6, round(scores[i], 2)
            h, t = ok(head, False), ok(tail, True)
            total += 1
            if not (h[0] and t[0]):
                bad += 1
                wrong.append((i + 1, h[1], t[1]))
        shown = min(len(spans), a.first) if a.first else len(spans)
        print(f'{surah}: {shown - len(wrong)}/{shown} ayahs open and close as expected; '
              f'unsure: {wrong[:15]}', flush=True)
    print(f'all: {total - bad}/{total}')


if __name__ == '__main__':
    main()
