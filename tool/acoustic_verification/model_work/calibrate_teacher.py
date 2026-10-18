"""Calibrates a teacher before distillation: one temperature and a bias per sound,
lp' = log_softmax(lp / T + b), fitted to make the true transcripts most likely (CTC)
on clips whose transcripts are known — RetaSy amateurs judged correct (shard_95),
expert-labelled learners (shard_96: what was heard, mistakes included) and
professional recitation (shard_0000) — each group weighed alike. The teachers flag
9-13% of amateurs' correct words; this is the cheapest fix that changes no model.

  python calibrate_teacher.py fit calib_fit/ft4.npz calib_fit/ft5.npz --out artifacts/teacher_calib.json
  python calibrate_teacher.py apply artifacts/teacher_calib.json ft4 <pack> ...
  python calibrate_teacher.py select artifacts/teacher_calib.json <pack> ...
      # the student's per-frame target from tft4 + tft5: tsel (raw), tselc (calibrated)
      # results/<pack>_tft4.{json,f32} -> results/<pack>_tft4c.{json,f32}

20% of each group's clips (by index, fixed) are held out: the fit reports their loss
before and after.
"""
import argparse, json, os, shutil

import numpy as np
import torch
import torch.nn.functional as F

HERE = os.path.dirname(os.path.abspath(__file__))
R = os.path.join(HERE, 'artifacts', 'results')


def group(source):
    return 'amateur' if source.startswith('shard_95') else \
        'learner' if source.startswith('shard_96') else 'professional'


def ctc(lp, tgt):
    """Mean per-token CTC loss of a batch of (frames x 43 log-probs, target)."""
    T = max(x.shape[0] for x in lp)
    pad = torch.full((T, len(lp), 43), 0.0)
    for j, x in enumerate(lp):
        pad[:x.shape[0], j] = x
    return F.ctc_loss(pad, torch.cat(tgt), torch.tensor([x.shape[0] for x in lp]),
                      torch.tensor([len(t) for t in tgt]), blank=0, zero_infinity=True,
                      reduction='none') / torch.tensor([len(t) for t in tgt]).clamp_min(1)


def fit(path, steps=300):
    z = np.load(path, allow_pickle=True)
    lps = [torch.tensor(x.astype(np.float32)) for x in z['lp']]
    tgts = [torch.tensor(t.astype(np.int64)) for t in z['targets']]
    groups = [group(s) for s in z['sources']]
    idx = {g: [i for i, x in enumerate(groups) if x == g] for g in ('amateur', 'learner', 'professional')}
    train = {g: [i for k, i in enumerate(v) if k % 5] for g, v in idx.items()}
    held = {g: [i for k, i in enumerate(v) if not k % 5] for g, v in idx.items()}
    log_t = torch.zeros((), requires_grad=True)
    bias = torch.zeros(43, requires_grad=True)
    opt = torch.optim.Adam([log_t, bias], lr=0.02)

    def loss_of(ids, n=None):
        rng = np.random.default_rng(len(ids))
        pick = ids if n is None else list(rng.choice(ids, size=min(n, len(ids)), replace=False))
        lp = [F.log_softmax(lps[i] / log_t.exp() + bias, -1) for i in pick]
        return ctc(lp, [tgts[i] for i in pick]).mean()

    def report(tag):
        with torch.no_grad():
            print(tag, {g: round(float(loss_of(v)), 4) for g, v in held.items() if v},
                  'T', round(float(log_t.exp()), 3))

    report('held-out before')
    for step in range(steps):
        rng = np.random.default_rng(step)
        loss = sum(loss_of(list(rng.choice(v, size=min(48, len(v)), replace=False)))
                   for v in train.values() if v) / 3
        opt.zero_grad(); loss.backward(); opt.step()
        with torch.no_grad():
            bias[0] = 0.0          # the blank is the reference
    report('held-out after ')
    return {'T': float(log_t.exp()), 'bias': [round(float(b), 4) for b in bias]}


def apply(calib, teacher, packs):
    c = json.load(open(calib))[teacher]
    for pack in packs:
        src = os.path.join(R, f'{pack}_t{teacher}')
        dst = os.path.join(R, f'{pack}_t{teacher}c')
        lp = np.fromfile(src + '.f32', dtype=np.float32).reshape(-1, 43)
        out = torch.log_softmax(torch.tensor(lp) / c['T'] + torch.tensor(c['bias']), -1).numpy()
        out.astype(np.float32).tofile(dst + '.f32')
        shutil.copy(src + '.json', dst + '.json')
        print(pack, 'written', dst)


TAJWEED = 'ں۾ڇاۥۦنم'   # as distill_student.TeacherMix (TEACHER_SELECT)


def select(calib, packs):
    """The student's target, per frame (TEACHER_SELECT): ft5 where either teacher's
    likeliest sound is a tajweed one, else ft4 — raw (tsel) and calibrated (tselc)."""
    import distill_student as ds
    ids = torch.tensor([ds.VOCAB.index(c) for c in TAJWEED])
    c = json.load(open(calib))
    for pack in packs:
        a = torch.tensor(np.fromfile(os.path.join(R, f'{pack}_tft4.f32'), dtype=np.float32).reshape(-1, 43))
        b = torch.tensor(np.fromfile(os.path.join(R, f'{pack}_tft5.f32'), dtype=np.float32).reshape(-1, 43))
        tj = torch.isin(a.argmax(-1), ids) | torch.isin(b.argmax(-1), ids)
        for tag, x, y in [('tsel', a, b),
                          (os.environ.get('SEL_TAG', 'tselc'), torch.log_softmax(a / c['ft4']['T'] + torch.tensor(c['ft4']['bias']), -1),
                           torch.log_softmax(b / c['ft5']['T'] + torch.tensor(c['ft5']['bias']), -1))]:
            out = torch.where(tj[:, None], y, x).numpy().astype(np.float32)
            out.tofile(os.path.join(R, f'{pack}_{tag}.f32'))
            shutil.copy(os.path.join(R, f'{pack}_tft4.json'), os.path.join(R, f'{pack}_{tag}.json'))
        print(pack, 'tsel / tselc written')


def main():
    p = argparse.ArgumentParser()
    p.add_argument('mode', choices=['fit', 'apply', 'select'])
    p.add_argument('args', nargs='+')
    p.add_argument('--out', default=os.path.join(HERE, 'artifacts', 'teacher_calib.json'))
    a = p.parse_args()
    if a.mode == 'fit':
        out = {}
        for path in a.args:
            name = os.path.basename(path).split('.')[0]
            print('==', name)
            out[name] = fit(path)
        json.dump(out, open(a.out, 'w'), indent=1)
        print('written', a.out)
    elif a.mode == 'select':
        select(a.args[0], a.args[1:])
    else:
        apply(a.args[0], a.args[1], a.args[2:])


if __name__ == '__main__':
    main()
