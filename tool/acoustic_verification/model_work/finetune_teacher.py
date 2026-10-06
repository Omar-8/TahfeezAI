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
    rng.shuffle(ama)
    held = ama[:max(20, len(ama) // 10)]
    ama = ama[len(held):]
    print(f'{len(pro)} professional, {len(ama)} amateur, {len(held)} held-out amateur clips',
          flush=True)
    opt = torch.optim.AdamW(trainable, lr=a.lr, weight_decay=0.01)
    sched = torch.optim.lr_scheduler.LambdaLR(
        opt, lambda s: min(1.0, (s + 1) / 100) * max(0.05, 1 - s / a.steps))
    gp, ga = batches(pro, a.max_audio, rng), batches(ama, a.max_audio / 2, rng)

    def held_loss():
        model.eval()
        with torch.no_grad():
            v = [ctc(model, fe, held[i:i + 8]).item() for i in range(0, len(held), 8)]
        model.train()
        return float(np.mean(v))

    best = held_loss()
    print(f'step 0 held-out amateur ctc {best:.3f}', flush=True)
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
            v = held_loss()
            mark = ''
            if v < best:
                best, mark = v, ' (best, saved)'
                torch.save(model.state_dict(), a.out)
            print(f'VAL step {step} held-out amateur ctc {v:.3f}{mark}', flush=True)
    print('done', a.out, flush=True)


if __name__ == '__main__':
    main()
