"""Which parts of the teacher are sensitive? (Stage A/B probes)

  python sensitivity.py

On a fixed probe set (12 spliced-mistake windows + 12 clean ayahs from the
screening subset), measures how far the output moves from the unmodified
model when:
  1. one encoder layer is skipped (structured layer pruning), and
  2. one group of weights — feed-forward / attention / convolution, in
     each quarter of the layers — is fake-quantized to 2 bits (symmetric,
     blocks of 64, like MatMulNBits), everything else left exact.
Metrics: top-1 frame agreement and mean per-frame KL(original || modified).
Writes artifacts/sensitivity.json.
"""
import copy, json, os, re
import numpy as np
import torch
import torch.nn.functional as F

HERE = os.path.dirname(os.path.abspath(__file__))
ART = os.path.join(HERE, 'artifacts')
torch.set_num_threads(os.cpu_count())

from quran_muaalem import Muaalem  # noqa: E402
m = Muaalem(model_name_or_path='obadx/muaalem-model-v3_2', device='cpu', dtype=torch.float32)
model, fe = m.model.eval(), m.processor

cases = json.load(open(os.path.join(ART, 'bench_cases.json')))
audio = np.load(os.path.join(ART, 'bench_audio.npz'))
pairs = [i for i, c in enumerate(cases) if c['screen'] and c['kind'] == 'spliced'][::10][:12]
clean = sorted([i for i, c in enumerate(cases) if c['screen'] and c['set'] == 'clean'],
               key=lambda i: len(audio[f'c{i}']))[:48:4]
probe = [audio[f'c{i}'][:16000 * 15] for i in pairs + clean]
feats = [fe([w], sampling_rate=16000, return_tensors='pt') for w in probe]


def outputs(mdl):
    with torch.no_grad():
        return [F.log_softmax(mdl(**f, return_dict=False)[0]['phonemes'][0], -1) for f in feats]


ref = outputs(model)


def score(outs):
    agree = np.mean([float((o.argmax(-1) == r.argmax(-1)).float().mean()) for o, r in zip(outs, ref)])
    kl = np.mean([float((r.exp() * (r - o)).sum(-1).mean()) for o, r in zip(outs, ref)])
    return round(agree * 100, 2), round(kl, 4)


results = {'layer_skip': {}, 'int2': {}}
layers = model.wav2vec2_bert.encoder.layers
for i in range(len(layers)):
    kept = torch.nn.ModuleList([l for k, l in enumerate(layers) if k != i])
    model.wav2vec2_bert.encoder.layers = kept
    results['layer_skip'][i] = score(outputs(model))
    print('skip layer', i, results['layer_skip'][i], flush=True)
model.wav2vec2_bert.encoder.layers = layers


def fake_int2(w, block=64):
    shape = w.shape
    x = w.reshape(-1, block) if w.numel() % block == 0 else w.reshape(1, -1)
    scale = x.abs().amax(1, keepdim=True).clamp_min(1e-8) / 1.5   # levels -1.5..1.5 (2 bits)
    q = torch.clamp(torch.round(x / scale - 0.5) + 0.5, -1.5, 1.5)
    return (q * scale).reshape(shape)


groups = {'ffn': r'\.ffn[12]\.', 'attention': r'\.self_attn\.linear_', 'conv': r'\.conv_module\.pointwise'}
for gname, pat in groups.items():
    for q in range(4):
        lo, hi = q * 6, q * 6 + 5
        saved = {}
        for name, p in model.named_parameters():
            mt = re.search(r'encoder\.layers\.(\d+)\.', name)
            if mt and lo <= int(mt.group(1)) <= hi and re.search(pat, name) and p.dim() >= 2:
                saved[name] = p.data.clone()
                p.data = fake_int2(p.data)
        results['int2'][f'{gname} layers {lo}-{hi}'] = score(outputs(model))
        print('int2', gname, lo, hi, results['int2'][f'{gname} layers {lo}-{hi}'], flush=True)
        for name, p in model.named_parameters():
            if name in saved:
                p.data = saved[name]
json.dump(results, open(os.path.join(ART, 'sensitivity.json'), 'w'), indent=1)
print('DONE')
