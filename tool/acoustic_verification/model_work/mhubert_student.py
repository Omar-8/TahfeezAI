"""A student with an intact pretrained ear (2026-10-20): mHuBERT-147 (utter-project, 94M
parameters, 12 layers, pretrained on ~90k hours of speech in ~147 languages; CC-BY-NC-SA
4.0) with a 43-sound Quran Phonetic Script head, distilled from the teachers as
distill_student.py does. Every cut-down student so far (6 / 8 layers, grown or from the
teacher's layers) relearns hearing from our mostly studio audio and fails on phone audio
the teacher hears right (owner's «تَذْكُرُوا۟», 43:13); this one keeps all of its own.

Offline first (whole clips, no streaming): a test of the idea before any export work.
Its frames are 20 ms; each pair is joined (their two vectors side by side) into one 40 ms
frame, the teacher's.

  TEACHER_WEIGHTS=teachers/teacher_ft4.pt,teachers/teacher_ft5.pt TEACHER_SELECT=1 \\
  python mhubert_student.py train <data dir> <out dir> [--steps 12000 --max-audio 120]
  python mhubert_student.py bench <run dir> <tag> <pack>...   # results/<pack>_<tag>
"""
import argparse, json, math, os, random, sys, time

import numpy as np
import torch
import torch.nn.functional as F

import distill_student as ds

HERE = os.path.dirname(os.path.abspath(__file__))
ART = os.path.join(HERE, 'artifacts')
BASE = 'utter-project/mHuBERT-147'


class MHubertStudent(torch.nn.Module):
    def __init__(self, base=BASE, config=None):
        super().__init__()
        from transformers import AutoConfig, HubertModel
        if config is None:
            self.encoder = HubertModel.from_pretrained(base)
        else:
            self.encoder = HubertModel(AutoConfig.from_pretrained(config))
        h = self.encoder.config.hidden_size
        self.head = torch.nn.Linear(2 * h, 43)

    def forward(self, wave):
        """[wave] (B, N), each row normalised to zero mean / unit variance: log-probs at
        40 ms frames (B, T, 43)."""
        hs = self.encoder(wave).last_hidden_state                # (B, 2T(+1), h)
        t = hs.shape[1] // 2
        pairs = hs[:, :2 * t].reshape(hs.shape[0], t, 2 * hs.shape[2])
        return F.log_softmax(self.head(pairs).float(), -1)


def normalise(waves):
    n = max(len(w) for w in waves)
    out = torch.zeros(len(waves), n)
    for i, w in enumerate(waves):
        w = torch.as_tensor(np.asarray(w, dtype=np.float32))
        out[i, :len(w)] = (w - w.mean()) / (w.std() + 1e-7)
    return out


def train(a):
    teacher = ds.load_teacher()
    fe = getattr(teacher.processor, 'feature_extractor', teacher.processor)
    s = MHubertStudent().to(ds.DEV).train()
    s.encoder.feature_extractor._freeze_parameters()
    head = [p for n, p in s.named_parameters() if n.startswith('head')]
    body = [p for n, p in s.named_parameters() if not n.startswith('head') and p.requires_grad]
    opt = torch.optim.AdamW([{'params': body, 'lr': a.lr}, {'params': head, 'lr': a.lr * 20}],
                            weight_decay=0.01)
    warm = 1000
    sched = torch.optim.lr_scheduler.LambdaLR(
        opt, lambda k: min(1, (k + 1) / warm) * 0.5 * (1 + math.cos(math.pi * min(1, k / a.steps))))
    ds.REPEAT[:] = [(p, int(t)) for p, t in (r.split('=') for r in a.repeat.split(','))] if a.repeat else []
    ds.TRUST[:] = a.trust.split(',') if a.trust else []
    # Real phone recordings (M2: TLOG): never augmented, teacher and student the same
    # waveform; their inferred transcripts only a weak CTC (--ctc-scale).
    ds.REAL_PHONE[:] = [q for q in a.real_phone.split('+') if q]
    ds.CTC_SCALE[:] = [(q.split('=')[0], float(q.split('=')[1])) for q in a.ctc_scale.split(',') if q]
    # v3.7's recipe (M3): more phone conditions, pitch and tempo; short vowels, hard sounds and
    # the frames furthest from the teacher weigh more (distill_student.py --vowel / --hard /
    # --focus); v3.5 a second teacher on amateurs' clips (--guide path:prefix:weight).
    ds.PITCH, ds.TEMPO, ds.EXTRA = a.pitch, a.tempo, a.phone_extra
    guide, guide_pre = None, []
    if a.guide:
        import streaming
        path, pre, gw = a.guide.split(':')
        guide = ds.make_student(ds._base(teacher.model), 'd6').to(ds.DEV).eval()
        guide.load_state_dict(torch.load(path, map_location=ds.DEV))
        for p_ in guide.parameters():
            p_.requires_grad_(False)
        ds.STUDENT_CAUSAL = streaming.prior(os.path.join(HERE, 'fbank_prior.json'), ds.DEV)
        print('guide streaming:', streaming.enable(guide, *streaming.parse('0.96,5.12')), 'attention layers')
        guide_pre = [(q, float(gw)) for q in pre.split('+')]
        # batches() tags those shards' clips with their weight ([guided]).
        ds.GUIDE, ds.GUIDE_PRE[:] = guide, guide_pre
    vowel = torch.zeros(43, device=ds.DEV)
    for c in ds.VOWEL_SYMBOLS:
        vowel[ds.VOCAB.index(c)] = 1.0
    hard = torch.zeros(43, device=ds.DEV)
    for c in ds.HARD_SYMBOLS:
        hard[ds.VOCAB.index(c)] = 1.0
    os.makedirs(a.out, exist_ok=True)
    ckpt = os.path.join(a.out, 'checkpoint.pt')
    step = 0
    if os.path.exists(ckpt):
        c = torch.load(ckpt, map_location='cpu', weights_only=False)
        s.load_state_dict(c['model']); opt.load_state_dict(c['opt']); sched.load_state_dict(c['sched'])
        step = c['step']
    log = open(os.path.join(a.out, 'train.log'), 'a')
    rng = random.Random(a.seed + step)
    val = [c for c in ds.clips(os.path.join(a.data, 'val.npz'))][:200]
    it = ds.batches(a.data, a.max_audio, a.seed + step)
    t0 = time.time()
    while step < a.steps:
        items = next(it)
        items, _ = ds.tempo(items, None, rng)
        x, mask = ds.featurize(fe, items)
        with torch.no_grad():
            tl = F.log_softmax(teacher.model(input_features=x.to(teacher.model.dtype), attention_mask=mask,
                                             return_dict=True).logits['phonemes'].float(), -1)
        heard = ds.augment(items, a.augment, rng, None, 0.7, items) if a.augment > 0 else items
        wave = normalise([np.asarray(h.cpu() if torch.is_tensor(h) else h) for h, _ in heard]).to(ds.DEV)
        with torch.autocast(ds.DEV, dtype=torch.bfloat16, enabled=ds.DEV == 'cuda'):
            sl = s(wave)
        n = min(tl.shape[1], sl.shape[1])
        fm = mask[:, ::2][:, :n].float()
        kl = F.kl_div(sl[:, :n], tl[:, :n], log_target=True, reduction='none').sum(-1)
        g = torch.tensor([getattr(t, 'guided', 0.0) for _, t in items], device=kl.device)[:, None]
        if (g > 0).any():
            # The second teacher hears what the student hears, streaming as in the app.
            xs, sm = ds.featurize(fe, heard, ds.STUDENT_CAUSAL)
            with torch.no_grad(), torch.autocast(ds.DEV, dtype=torch.bfloat16, enabled=ds.DEV == 'cuda'):
                gl = F.log_softmax(guide(input_features=xs, attention_mask=sm, return_dict=True)
                                   .logits['phonemes'].float(), -1)
            m = min(n, gl.shape[1])
            kl_g = torch.zeros_like(kl)
            kl_g[:, :m] = F.kl_div(sl[:, :m], gl[:, :m], log_target=True, reduction='none').sum(-1)
            kl = (1 - g) * kl + g * kl_g
        w = torch.ones_like(kl)
        tp = tl[:, :n].exp()
        if a.vowel > 0:
            w = w + a.vowel * (tp * vowel).sum(-1).clamp(0, 1)
        if a.hard > 0:
            w = w + a.hard * hard[tp.argmax(-1)]
        if a.focus > 0:
            mean = (kl * fm).sum() / fm.sum().clamp_min(1)
            w = w + a.focus * (kl.detach() / mean.detach().clamp_min(1e-6)).clamp(0, 3) / 3
        w = w / ((w * fm).sum() / fm.sum().clamp_min(1))   # same overall scale
        trusted = [getattr(t, 'trusted', False) and len(t) > 0 for _, t in items]
        w = w * torch.tensor([a.trust_kl if tr else 1.0 for tr in trusted], device=kl.device)[:, None]
        loss_kl = (kl * w * fm).sum() / fm.sum()
        keep = [j for j, (_, t) in enumerate(items) if len(t) > 0]
        loss_ctc = torch.zeros((), device=kl.device)
        if keep and a.ctc > 0:
            targets = torch.tensor([i for j in keep for i in items[j][1]], device=ds.DEV)
            lengths = torch.tensor([len(items[j][1]) for j in keep], device=ds.DEV)
            per = F.ctc_loss(sl[keep, :n].transpose(0, 1), targets, fm[keep].sum(1).long(), lengths,
                             blank=0, zero_infinity=True, reduction='none') / lengths.clamp_min(1)
            cw = torch.tensor([(a.trust_ctc if trusted[j] else 1.0) * getattr(items[j][1], 'ctc', 1.0)
                               for j in keep], device=per.device)
            loss_ctc = (per * cw).mean()
        loss = loss_kl + a.ctc * loss_ctc
        opt.zero_grad(set_to_none=True)
        loss.backward()
        torch.nn.utils.clip_grad_norm_(s.parameters(), 5.0)
        opt.step(); sched.step(); step += 1
        if step % 50 == 0:
            print(f'step {step} kl {loss_kl.item():.4f} ctc {loss_ctc.item():.3f} '
                  f'lr {sched.get_last_lr()[0]:.2e} {(time.time() - t0) / 3600:.2f} h', file=log, flush=True)
        if step % 1000 == 0 or step == a.steps:
            s.eval(); tot = cnt = 0.0
            with torch.no_grad():
                for k in range(0, len(val), 8):
                    v = val[k:k + 8]
                    x, mask = ds.featurize(fe, v)
                    tl = F.log_softmax(teacher.model(input_features=x.to(teacher.model.dtype), attention_mask=mask,
                                                     return_dict=True).logits['phonemes'].float(), -1)
                    sl = s(normalise([c[0] for c in v]).to(ds.DEV))
                    n = min(tl.shape[1], sl.shape[1]); fm = mask[:, ::2][:, :n].float()
                    kl = F.kl_div(sl[:, :n], tl[:, :n], log_target=True, reduction='none').sum(-1)
                    tot += (kl * fm).sum().item(); cnt += fm.sum().item()
            s.train()
            print(f'VAL step {step} kl(T=1) {tot / cnt:.4f}', file=log, flush=True)
            torch.save({'model': s.state_dict(), 'opt': opt.state_dict(), 'sched': sched.state_dict(),
                        'step': step}, ckpt + '.tmp')
            os.replace(ckpt + '.tmp', ckpt)
            if a.save_every and step % a.save_every == 0:
                torch.save(s.state_dict(), os.path.join(a.out, f'student_{step}.pt'))
    torch.save(s.state_dict(), os.path.join(a.out, 'student.pt'))
    s.encoder.config.save_pretrained(a.out)
    json.dump(vars(a), open(os.path.join(a.out, 'run.json'), 'w'))


def bench(a):
    """Offline frames over test packs, in bench_run.py's results format: whole clips
    (pieces of 20 s with 2 s overlap beyond that), so the Dart tools can judge them."""
    dev = 'cuda' if torch.cuda.is_available() else 'cpu'
    s = MHubertStudent(config=a.run).eval()
    s.load_state_dict(torch.load(os.path.join(a.run, a.weights), map_location='cpu'))
    s.to(dev)
    torch.set_num_threads(os.cpu_count())
    piece, overlap, hop = 20 * 16000, 2 * 16000, 640

    def frames(w):
        def run(x):
            with torch.no_grad():
                return s(normalise([x]).to(dev))[0].float().cpu().numpy()
        if len(w) <= piece:
            return run(w)
        parts, start = [], 0
        while True:
            lp = run(w[start:start + piece]); end = start + piece >= len(w)
            first = 0 if start == 0 else (overlap // 2) // hop
            last = len(lp) if end else len(lp) - (overlap // 2) // hop
            parts.append(lp[first:last])
            if end:
                return np.concatenate(parts)
            start += piece - overlap

    for pack in a.packs:
        cases = json.load(open(os.path.join(ART, f'{pack}_cases.json')))
        audio = np.load(os.path.join(ART, f'{pack}_audio.npz'))
        out, blobs, off = [], [], 0
        for i, c in enumerate(cases):
            lp = frames(audio[f'c{i}']).astype('<f4')
            out.append(dict(c, main=dict(offset=off, frames=int(lp.shape[0])), shifted=None))
            blobs.append(lp.ravel()); off += lp.size
        np.concatenate(blobs).tofile(os.path.join(ART, 'results', f'{pack}_{a.tag}.f32'))
        json.dump(out, open(os.path.join(ART, 'results', f'{pack}_{a.tag}.json'), 'w'))
        print(pack, 'done', flush=True)


def main():
    p = argparse.ArgumentParser()
    sub = p.add_subparsers(dest='cmd', required=True)
    t = sub.add_parser('train')
    t.add_argument('data'); t.add_argument('out')
    t.add_argument('--steps', type=int, default=12000)
    t.add_argument('--max-audio', type=float, default=120)
    t.add_argument('--lr', type=float, default=5e-5)
    t.add_argument('--augment', type=float, default=0.6)
    t.add_argument('--ctc', type=float, default=0.1)
    t.add_argument('--repeat', default='')
    t.add_argument('--trust', default='')
    t.add_argument('--trust-kl', type=float, default=0.2)
    t.add_argument('--trust-ctc', type=float, default=10)
    t.add_argument('--seed', type=int, default=0)
    t.add_argument('--real-phone', default='', help='shard prefixes (a+b) of real phone recordings')
    t.add_argument('--ctc-scale', default='', help='PREFIX=W,...: CTC weight per shard prefix')
    t.add_argument('--save-every', type=int, default=0, help='also keep student_<step>.pt')
    t.add_argument('--vowel', type=float, default=0.0)
    t.add_argument('--hard', type=float, default=0.0)
    t.add_argument('--focus', type=float, default=0.0)
    t.add_argument('--pitch', type=float, default=0.0)
    t.add_argument('--tempo', type=float, default=0.0)
    t.add_argument('--phone-extra', action='store_true')
    t.add_argument('--guide', default='', help='path:prefix(+prefix):weight — a second teacher')
    b = sub.add_parser('bench')
    b.add_argument('run'); b.add_argument('tag'); b.add_argument('packs', nargs='+')
    b.add_argument('--weights', default='student.pt')
    a = p.parse_args()
    train(a) if a.cmd == 'train' else bench(a)


if __name__ == '__main__':
    main()
