"""Where the student is confidently wrong against its teachers: per clip, the sounds the
teachers are sure of (their mixture as in training, TEACHER_WEIGHTS / TEACHER_SELECT, p >=
--sure) that the shipped streaming student all but rules out (p < --ruled-out within a frame
either side) — each such run of frames one event. No transcript needed: the teachers'
own verdict is the reference, so any recitation can be mined.

  TEACHER_WEIGHTS=teachers/teacher_ft4.pt,teachers/teacher_ft5.pt TEACHER_SELECT=1 \\
  python disagree_mine.py <out.json> <student.onnx> <stream.json> <source>...

A source is a training shard (shard_NNNN.npz: audio, offsets, targets) or a test pack
(artifacts/<pack>_cases.json + _audio.npz, given as pack:<name>; only its clean cases).
out.json: every clip's events and its score (events per minute), worst first — what a
training round oversamples (--repeat / a shard of them, disagree_shard.py).
"""
import argparse, json, os

import numpy as np
import torch
import torch.nn.functional as F

import distill_student as ds

HERE = os.path.dirname(os.path.abspath(__file__))
ART = os.path.join(HERE, 'artifacts')
# Sounds judged by the verifier as letters / vowels: not blank, not the long-vowel / tajweed
# markers whose timing differs by design between offline and streaming.
SKIP = {0} | {ds.VOCAB.index(c) for c in 'اۥۦڇ' if c in ds.VOCAB}


class Student:
    """The shipped stateful streaming ONNX export, run as the app runs it."""

    NAMES = ['sums', 'count', 'kv', 'conv', 'akv', 'aconv', 'valid']

    def __init__(self, onnx, cfg, threads=8):
        import onnxruntime as ort
        so = ort.SessionOptions()
        # More is far slower on a many-core box: 80 threads ran 35x slower than 8.
        so.intra_op_num_threads = threads
        self.s = ort.InferenceSession(onnx, so)
        self.cfg = json.load(open(cfg))

    def __call__(self, w):
        c = self.cfg
        st = {k: np.zeros(c['state'][k], np.float32) for k in self.NAMES}
        st['sums'] = np.array(c['initial']['sums'], np.float32)
        st['count'] = np.array(c['initial']['count'], np.float32)
        outs, start = [], 0
        while start + 400 <= len(w):
            seg = w[start:start + c['chunk_samples'] + c['overlap_samples']]
            n = ((len(seg) - 400) // 160 + 1) // 4 * 4
            if n == 0:
                break
            r = self.s.run(None, dict(samples=seg[:160 * (n - 1) + 400][None].astype(np.float32), **st))
            outs.append(r[0][0])
            st = dict(zip(self.NAMES, r[1:]))
            start += c['chunk_samples']
        return np.concatenate(outs) if outs else np.zeros((0, 43), np.float32)


def events(t_lp, s_lp, sure, ruled_out):
    """Runs of frames where the teachers are sure of a sound the student rules out."""
    n = min(len(t_lp), len(s_lp))
    t_lp, s_lp = t_lp[:n], s_lp[:n]
    top, tp = t_lp.argmax(-1), np.exp(t_lp.max(-1))
    sp = np.exp(s_lp)
    # the student's best chance at that sound a frame either side (streaming may lag one)
    near = np.maximum.reduce([sp, np.roll(sp, 1, 0), np.roll(sp, -1, 0)])
    bad = [(f, int(top[f])) for f in range(n)
           if top[f] not in SKIP and tp[f] >= sure and near[f, top[f]] < ruled_out]
    out = []
    for f, c in bad:
        if out and out[-1]['sound'] == ds.VOCAB[c] and f - out[-1]['end'] <= 1:
            out[-1]['end'] = f
            continue
        heard = s_lp[f].copy()
        heard[c] = -1e9
        out.append({'start': f, 'end': f, 'sound': ds.VOCAB[c],
                    'student': ds.VOCAB[int(heard.argmax())] or '-'})
    for e in out:
        e['s'] = round(e['start'] * 0.04, 2)
    return out


def sources(args):
    for src in args:
        if src.startswith('pack:'):
            name = src[5:]
            cases = json.load(open(os.path.join(ART, f'{name}_cases.json')))
            audio = np.load(os.path.join(ART, f'{name}_audio.npz'))
            for i, c in enumerate(cases):
                if c.get('set', 'clean') == 'clean' and not c.get('targetWords'):
                    yield src, i, c.get('name', str(i)), audio[f'c{i}'].astype(np.float32)
        else:
            for i, (x, _) in enumerate(ds.clips(src)):
                yield os.path.basename(src), i, f'{os.path.basename(src)}#{i}', x


def main():
    p = argparse.ArgumentParser()
    p.add_argument('out')
    p.add_argument('student')
    p.add_argument('stream')
    p.add_argument('sources', nargs='+')
    p.add_argument('--sure', type=float, default=0.9)
    p.add_argument('--ruled-out', type=float, default=0.05)
    p.add_argument('--threads', type=int, default=8, help="the student's CPU threads")
    a = p.parse_args()
    teacher = ds.load_teacher()
    fe = getattr(teacher.processor, 'feature_extractor', teacher.processor)
    student = Student(a.student, a.stream, a.threads)
    rows, done = [], set()
    if os.path.exists(a.out):   # resume
        rows = json.load(open(a.out))['clips']
        done = {(r['source'], r['index']) for r in rows}
    for k, (src, i, name, x) in enumerate(sources(a.sources)):
        if (src, i) in done or len(x) < 16000:
            continue
        f = fe([x], sampling_rate=16000, return_tensors='pt')
        f = {n: v.to(ds.DEV, dtype=teacher.model.dtype if v.is_floating_point() else v.dtype)
             for n, v in f.items()}
        with torch.no_grad():
            t_lp = F.log_softmax(teacher.model(**f).logits['phonemes'][0].float(), -1)
        ev = events(t_lp.cpu().numpy(), student(x), a.sure, a.ruled_out)
        minutes = len(x) / 16000 / 60
        rows.append({'source': src, 'index': i, 'name': name, 'seconds': round(len(x) / 16000, 1),
                     'events': ev, 'per_min': round(len(ev) / minutes, 2)})
        if k % 20 == 0:
            json.dump({'clips': rows}, open(a.out, 'w'), ensure_ascii=False)
            print(k, src, len(rows), flush=True)
    rows.sort(key=lambda r: -r['per_min'])
    total = sum(r['seconds'] for r in rows) / 60
    n = sum(len(r['events']) for r in rows)
    json.dump({'clips': rows, 'minutes': round(total, 1), 'events': n}, open(a.out, 'w'),
              ensure_ascii=False, indent=0)
    print(f'{len(rows)} clips, {total:.0f} min, {n} events ({n / max(total, 1e-9):.2f}/min)')


if __name__ == '__main__':
    main()
