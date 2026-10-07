"""Fine-tunes the teacher (Muaalem, 606M) towards non-professional recitation, before
distilling a student from it.

  python finetune_teacher.py <out.pt> --data DIR [DIR ...] --amateur DIR [--steps 2000]

The teacher flags a fifth to a third of the words in amateurs' correct recitation (RetaSy
test), and a student distilled from it learns its view. Here it learns, by CTC, that the
amateur clips annotators marked correct say the expected Hafs pronunciation (those
clips carry it as their target: retasy_data.py), mixed with its own training data
(muaalem transcripts, data_orig) so it does not forget professional recitation. The
lower layers stay frozen; a small learning rate; the best step on held-out amateur
clips (CTC loss) is kept.

Writes the model's state dict (load with TEACHER_WEIGHTS=<out.pt> in distill_student.py
and bench_run.py torch).
"""
import argparse, glob, os, random, time

import numpy as np
import torch
import torch.nn.functional as F

import distill_student as ds


def labelled(dirs, prefix='shard_'):
    """(audio, targets) of every clip with a transcript in [dirs]' shards."""
    out = []
    for d in dirs:
        for sh in sorted(glob.glob(os.path.join(d, prefix + '[0-9][0-9][0-9][0-9].npz'))):
            out += [(x, t) for x, t in ds.clips(sh) if len(t) > 0]
    return out


def nasal(target):
    """Whether a transcript holds nasal tajweed: a hidden noon or meem, or a ghunnah
    (a noon or meem held two counts or more)."""
    hidden = {ds.ID['ں'], ds.ID['۾']}
    run, prev = 0, None
    for i in target:
        if i in hidden:
            return True
        run = run + 1 if i == prev else 1
        if run >= 2 and i in (ds.ID['ن'], ds.ID['م']):
            return True
        prev = i
    return False


def batches(items, max_audio_s, rng):
    while True:
        rng.shuffle(items)
        cur = []
        for x, t in sorted(items[:400], key=lambda c: len(c[0])):
            if cur and len(x) * (len(cur) + 1) / 16000 > max_audio_s:
                yield cur
                cur = []
            cur.append((x, t))
        if cur:
            yield cur


def ctc(model, fe, items):
    x, mask = ds.featurize(fe, items)
    with torch.autocast('cuda', dtype=torch.bfloat16):
        out = model(input_features=x, attention_mask=mask, return_dict=True)
    lp = F.log_softmax(out.logits['phonemes'].float(), -1)
    n = lp.shape[1]
    lens = mask[:, ::2][:, :n].sum(1).long()
    targets = torch.tensor([i for _, t in items for i in t], device=lp.device)
    tl = torch.tensor([len(t) for _, t in items], device=lp.device)
    return F.ctc_loss(lp.transpose(0, 1), targets, lens, tl, blank=0, zero_infinity=True)


def main():
    p = argparse.ArgumentParser()
    p.add_argument('out')
    p.add_argument('--data', nargs='+', required=True, help='professional shards (transcribed)')
    p.add_argument('--amateur', nargs='+', required=True, help='amateur shards (correct clips)')
    p.add_argument('--steps', type=int, default=2000)
    p.add_argument('--lr', type=float, default=1e-5)
    p.add_argument('--amateur-share', type=float, default=0.4)
    p.add_argument('--freeze', type=int, default=12, help='lower encoder layers kept frozen')
    p.add_argument('--max-audio', type=float, default=120)
    p.add_argument('--seed', type=int, default=0)
    p.add_argument('--no-nasal', action='store_true',
                   help='leave out amateur clips with nasal tajweed (ikhfa, idgham, ghunnah): their '
                        '"correct" labels judge vowels only, and teach the teacher to accept a plain noon '
                        'where ikhfa is due')
    p.add_argument('--held', nargs='*', default=[],
                   help='held-out mistake shards (spliced, other reciters): validated beside the amateur '
                        'clips, and the best step is chosen on the sum of the two losses')
    a = p.parse_args()
    rng = random.Random(a.seed)
    t = ds.load_teacher()
    model = t.model.float().train()
    fe = getattr(t.processor, 'feature_extractor', t.processor)
    for name, prm in model.named_parameters():
        frozen = not name.startswith(('wav2vec2_bert.encoder.layers',
                                      'wav2vec2_bert.adapter',
                                      'level_to_lm_head.phonemes'))
        if '.layers.' in name:
            layer = int(name.split('.layers.')[1].split('.')[0])
            frozen = 'encoder.layers' in name and layer < a.freeze
        prm.requires_grad_(not frozen)
    trainable = [q for q in model.parameters() if q.requires_grad]
    print(f'trainable {sum(q.numel() for q in trainable) / 1e6:.0f}M of '
          f'{sum(q.numel() for q in model.parameters()) / 1e6:.0f}M', flush=True)
    pro = labelled(a.data)
    ama = labelled(a.amateur)
    if a.no_nasal:
        ama = [c for c in ama if not nasal(c[1])]
    rng.shuffle(ama)
    held = ama[:max(20, len(ama) // 10)]
    ama = ama[len(held):]
    held_mis = labelled(a.held)
    print(f'{len(pro)} professional, {len(ama)} amateur, {len(held)} held-out amateur clips, '
          f'{len(held_mis)} held-out mistake clips', flush=True)
    opt = torch.optim.AdamW(trainable, lr=a.lr, weight_decay=0.01)
    sched = torch.optim.lr_scheduler.LambdaLR(
        opt, lambda s: min(1.0, (s + 1) / 100) * max(0.05, 1 - s / a.steps))
    gp, ga = batches(pro, a.max_audio, rng), batches(ama, a.max_audio / 2, rng)

    def loss_on(clips):
        with torch.no_grad():
            return float(np.mean([ctc(model, fe, clips[i:i + 8]).item() for i in range(0, len(clips), 8)]))

    def held_loss():
        model.eval()
        v = loss_on(held)
        m = loss_on(held_mis) if held_mis else 0.0
        model.train()
        return v + m, v, m

    best, v, m = held_loss()
    print(f'step 0 held-out amateur ctc {v:.3f} mistakes {m:.3f}', flush=True)
    torch.save(model.state_dict(), a.out)
    t0 = time.time()
    for step in range(1, a.steps + 1):
        items = next(ga) if rng.random() < a.amateur_share else next(gp)
        loss = ctc(model, fe, items)
        if not torch.isfinite(loss):
            opt.zero_grad(set_to_none=True)
            continue
        loss.backward()
        torch.nn.utils.clip_grad_norm_(trainable, 1.0)
        opt.step(); opt.zero_grad(set_to_none=True); sched.step()
        if step % 50 == 0:
            print(f'step {step} ctc {loss.item():.3f} {(time.time() - t0) / 3600:.2f} h', flush=True)
        if step % 250 == 0:
            total, v, m = held_loss()
            mark = ''
            if total < best:
                best, mark = total, ' (best, saved)'
                torch.save(model.state_dict(), a.out)
            print(f'VAL step {step} held-out amateur ctc {v:.3f} mistakes {m:.3f}{mark}', flush=True)
    print('done', a.out, flush=True)


if __name__ == '__main__':
    main()
