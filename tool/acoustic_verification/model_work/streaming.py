"""Streaming (v3 feasibility): a student whose self-attention sees the past and only the
rest of its own chunk, so each frame's output is final once its chunk has been heard.

Wav2Vec2-BERT's convolutions are already causal (its depthwise convolution pads on the
left only); the future reaches a frame through self-attention alone: the conformer
layers' (20 ms frames) and the adapter's (40 ms frames). Here every attention layer of
one model gets a chunk mask: a frame attends to the frames of its own chunk and of the
chunks before it, back to [left] seconds. Run over a whole clip, the model computes what a
chunk-by-chunk streaming run (with cached past) would, so offline scores are streaming
scores.

  enable(model, chunk_s=0.48, left_s=2.56)    # per model instance: a teacher in the
                                              # same process keeps full attention
  STREAM=0.48,2.56 python bench_run.py student:<run dir> <tag> --pack <set>
"""
import glob, json, os, sys, types

import torch
from transformers.models.wav2vec2_bert import modeling_wav2vec2_bert as w2v


def chunk_bias(n, chunk, left, device, dtype):
    """(1, 1, n, n) additive bias: 0 where frame i may see frame j, else very negative."""
    i = torch.arange(n, device=device)
    c = i // chunk
    seen = (c[None, :] <= c[:, None]) & (i[None, :] >= c[:, None] * chunk - left)
    bias = torch.zeros(n, n, device=device, dtype=dtype)
    return bias.masked_fill(~seen, torch.finfo(dtype).min)[None, None]


def enable(model, chunk_s, left_s):
    """Chunk masks on every self-attention layer of [model] (an instance, in place)."""
    n = 0
    for m in model.modules():
        if not isinstance(m, w2v.Wav2Vec2BertSelfAttention):
            continue
        # The adapter's attention (no position embeddings) runs after its stride-2
        # subsampling: 40 ms frames; the conformer layers': 20 ms.
        step = 0.04 if m.position_embeddings_type is None else 0.02
        chunk, left = max(1, round(chunk_s / step)), round(left_s / step)
        orig = m.forward

        def forward(self, hidden_states, attention_mask=None, *args, _orig=orig, _c=chunk, _l=left, **kw):
            b = chunk_bias(hidden_states.shape[1], _c, _l, hidden_states.device, hidden_states.dtype)
            if attention_mask is not None:
                b = torch.clamp(attention_mask + b, min=torch.finfo(b.dtype).min)
            return _orig(hidden_states, b, *args, **kw)

        m.forward = types.MethodType(forward, m)
        n += 1
    return n


PRIOR_FRAMES = 100   # the prior counts as 1 s of audio (10 ms fbank frames)


def prior(path, device):
    """(mean, variance, weight) for gpu_fbank's running normalisation: the training
    audio's average log-mel statistics (stream_prior in this file's __main__)."""
    p = json.load(open(path))
    t = lambda v: torch.tensor(v, dtype=torch.float32, device=device)
    return t(p['mean']), t(p['var']), PRIOR_FRAMES


def parse(spec):
    chunk, left = (float(x) for x in spec.split(','))
    return chunk, left


if __name__ == '__main__':
    # python streaming.py <shard dir> <out.json>: per mel bin, the mean and variance of
    # the raw log-mel features over (up to) 3000 clips of the shards.
    import numpy as np
    import distill_student as ds
    from gpu_fbank import GpuFbank
    t = ds.load_teacher()
    fe = getattr(t.processor, 'feature_extractor', t.processor)
    g = GpuFbank(fe, ds.DEV)
    s1 = s2 = n = 0
    for sh in sorted(glob.glob(os.path.join(sys.argv[1], 'shard_[0-9][0-9][0-9][0-9].npz')))[::3]:
        for x, _ in ds.clips(sh)[::7]:
            w = torch.from_numpy(np.asarray(x, dtype=np.float32)).to(ds.DEV)
            m = g.one(w, 'raw')
            s1, s2, n = s1 + m.sum(0), s2 + (m * m).sum(0), n + m.shape[0]
        if n > 3000 * 600:
            break
    mean = s1 / n
    json.dump(dict(mean=mean.tolist(), var=(s2 / n - mean * mean).tolist(), frames=int(n)),
              open(sys.argv[2], 'w'))
    print('prior from', n, 'frames')
