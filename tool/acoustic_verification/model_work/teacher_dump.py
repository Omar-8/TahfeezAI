"""A teacher's per-frame log-probabilities on transcribed clips, for calibrating it
(calibrate_teacher.py): every clip with a transcript in the given shards, the teacher
hearing the whole clip as in distillation.

  TEACHER_WEIGHTS=teachers/teacher_ft4.pt python teacher_dump.py out.npz data_retasy/shard_95*.npz ...

Writes, per clip: its log-probabilities (frames x 43, float16), its transcript and the
shard it came from.
"""
import os, sys

import numpy as np
import torch
import torch.nn.functional as F

import distill_student as ds


def main():
    out, shards = sys.argv[1], sys.argv[2:]
    t = ds.load_teacher()
    fe = getattr(t.processor, 'feature_extractor', t.processor)
    lps, targets, sources = [], [], []
    for sh in shards:
        items = [(x, tg) for x, tg in ds.clips(sh) if len(tg) > 0]
        items.sort(key=lambda c: len(c[0]))
        for k in range(0, len(items), 8):
            batch = items[k:k + 8]
            x, mask = ds.featurize(fe, batch)
            with torch.no_grad():
                lp = F.log_softmax(t.model(input_features=x.to(t.model.dtype), attention_mask=mask,
                                           return_dict=True).logits['phonemes'].float(), -1)
            n = mask[:, ::2].sum(1)
            for j, (_, tg) in enumerate(batch):
                lps.append(lp[j, :int(n[j])].cpu().numpy().astype(np.float16))
                targets.append(np.array(tg, np.int16))
                sources.append(os.path.basename(sh))
        print(sh, len(items), flush=True)
    np.savez(out, lp=np.array(lps, dtype=object), targets=np.array(targets, dtype=object),
             sources=np.array(sources))
    print('clips', len(lps))


if __name__ == '__main__':
    main()
