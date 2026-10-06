"""Stage A: shrink the teacher without retraining.

  python export_candidates.py fp32            # one FP32 export (convs as MatMul)
  python export_candidates.py quant <name> <bits> <block> [--only REGEX] [--rest-bits B]
         [--group REGEX=BITS:BLOCK ...] [--src fp32dir]
  python export_candidates.py fp32 [--drop 7,18]   # also: drop encoder layers
  python export_candidates.py fp32 --student <run dir> --out <dir>   # a distilled student

The teacher's 1x1 "pointwise" convolutions are matrix multiplications
written as Conv1d, and the adapter's stride-2 convolutions are unfold +
matmul; both are rewritten as MatMul before export (outputs checked
identical), so weight-only quantization reaches every large weight — the
stock export leaves 178 MB of them as FP16 convolution weights.
Weight-only block quantization (MatMulNBits) keeps activations FP32.
--only / --rest-bits: quantize matching MatMuls at <bits>, the others at
--rest-bits (mixed precision).
"""
import math, os, re, sys
import numpy as np
import torch
import torch.nn as nn
import torch.nn.functional as F

HERE = os.path.dirname(os.path.abspath(__file__))
ART = os.path.join(HERE, 'artifacts')
sys.path.insert(0, os.path.dirname(HERE))
from export_model import Fbank  # noqa: E402


class PointwiseAsLinear(nn.Module):
    """Conv1d(kernel 1) on (B, C, T) as a matmul."""

    def __init__(self, conv):
        super().__init__()
        self.linear = nn.Linear(conv.in_channels, conv.out_channels, bias=conv.bias is not None)
        self.linear.weight.data = conv.weight.data[:, :, 0].clone()
        if conv.bias is not None:
            self.linear.bias.data = conv.bias.data.clone()

    def forward(self, x):
        return self.linear(x.transpose(1, 2)).transpose(1, 2)


class ConvAsMatMul(nn.Module):
    """Conv1d(kernel k, stride s, padding p) on (B, C, T) as unfold + matmul."""

    def __init__(self, conv):
        super().__init__()
        self.k, self.s, self.p = conv.kernel_size[0], conv.stride[0], conv.padding[0]
        assert conv.groups == 1 and conv.dilation[0] == 1
        self.linear = nn.Linear(conv.in_channels * self.k, conv.out_channels, bias=conv.bias is not None)
        # (out, in, k) -> (out, k*in) matching unfold's (T', k, in) layout
        self.linear.weight.data = conv.weight.data.permute(0, 2, 1).reshape(conv.out_channels, -1).clone()
        if conv.bias is not None:
            self.linear.bias.data = conv.bias.data.clone()

    def forward(self, x):
        x = F.pad(x, (self.p, self.p))
        idx = torch.arange(0, x.shape[2] - self.k + 1, self.s)[:, None] + torch.arange(self.k)[None, :]
        cols = x[:, :, idx]                       # (B, C, T', k)
        cols = cols.permute(0, 2, 3, 1).reshape(x.shape[0], idx.shape[0], -1)  # (B, T', k*C)
        return self.linear(cols).transpose(1, 2)


def rewrite(model):
    n = 0
    for name, mod in list(model.named_modules()):
        for child_name, child in list(mod.named_children()):
            if isinstance(child, nn.Conv1d) and child.groups == 1:
                new = PointwiseAsLinear(child) if child.kernel_size[0] == 1 and child.stride[0] == 1 else ConvAsMatMul(child)
                setattr(mod, child_name, new)
                n += 1
    return n


class Wrapped(nn.Module):
    def __init__(self, model, fe):
        super().__init__()
        self.fbank, self.model = Fbank(fe), model

    def forward(self, wave):
        feats = self.fbank(wave)
        mask = torch.ones(feats.shape[:2], dtype=torch.long)
        logits = self.model(input_features=feats, attention_mask=mask, return_dict=False)[0]['phonemes']
        return F.log_softmax(logits, dim=-1)


def export_fp32(drop=(), out_dir='fp32', student=None):
    from quran_muaalem import Muaalem
    m = Muaalem(model_name_or_path='obadx/muaalem-model-v3_2', device='cpu', dtype=torch.float32)
    model, fe = m.model.eval(), getattr(m.processor, 'feature_extractor', m.processor)
    if student:
        # a distilled student: the teacher's class, the student's config/weights
        cfg = model.config.__class__.from_pretrained(student)
        model = model.__class__(cfg)
        model.load_state_dict(torch.load(os.path.join(student, 'student.pt'), map_location='cpu'))
        model.eval()
        print(f'student {student}: {sum(p.numel() for p in model.parameters()) / 1e6:.1f}M parameters')
    # only the phoneme head is used; drop the ten attribute heads
    model.level_to_lm_head = nn.ModuleDict({'phonemes': model.level_to_lm_head['phonemes']})
    if drop:
        enc = model.wav2vec2_bert.encoder
        enc.layers = nn.ModuleList([l for i, l in enumerate(enc.layers) if i not in drop])
        model.config.num_hidden_layers = len(enc.layers)
        print(f'dropped encoder layers {sorted(drop)}: {len(enc.layers)} left')
    wave = torch.from_numpy((np.random.default_rng(0).standard_normal(16000 * 5) * 0.1).astype(np.float32))[None]
    w = Wrapped(model, fe).eval()
    with torch.no_grad():
        before = w(wave)
        n = rewrite(model)
        after = w(wave)
    print(f'rewrote {n} convolutions; max output change {float((before - after).abs().max()):.2e}')
    out = os.path.join(ART, out_dir, 'model.onnx')
    os.makedirs(os.path.dirname(out), exist_ok=True)
    with torch.no_grad():
        torch.onnx.export(w, (wave,), out, input_names=['waveform'], output_names=['log_probs'],
                          dynamic_axes={'waveform': {1: 'samples'}, 'log_probs': {1: 'frames'}},
                          opset_version=17, dynamo=False)
    import onnx
    mdl = onnx.load(out, load_external_data=True)
    onnx.save(mdl, out, save_as_external_data=True, all_tensors_to_one_file=True, location='model.onnx.data')
    for f in os.listdir(os.path.dirname(out)):
        if f not in ('model.onnx', 'model.onnx.data'):
            os.remove(os.path.join(os.path.dirname(out), f))
    size = sum(os.path.getsize(os.path.join(os.path.dirname(out), f)) for f in os.listdir(os.path.dirname(out)))
    print(f'fp32 export: {size / 1e6:.1f} MB (model.onnx + model.onnx.data)')


def quantize(name, bits, block, only=None, rest_bits=None, groups_spec=(), src_dir='fp32'):
    import onnx
    from onnxruntime.quantization.matmul_nbits_quantizer import MatMulNBitsQuantizer
    src = onnx.load(os.path.join(ART, src_dir, 'model.onnx'), load_external_data=True)
    names = [n.name for n in src.graph.node if n.op_type == 'MatMul']
    inits = {t.name for t in src.graph.initializer}
    # The fbank front end's DFT / mel matrices stay FP32 (tiny, and they
    # shape every feature the model sees).
    weighted = [n.name for n in src.graph.node
                if n.op_type == 'MatMul' and n.input[1] in inits and not n.name.startswith('/fbank/')]
    if groups_spec:
        remaining, groups = list(weighted), []
        for spec in groups_spec:
            pat, rest = spec.split('=')
            b, blk = (int(v) for v in rest.split(':'))
            sel = [n for n in remaining if re.search(pat, n)]
            remaining = [n for n in remaining if n not in sel]
            groups.append((sel, b, blk))
            print(f'  {len(sel)} MatMuls at {b} bits (block {blk}): {pat}')
        groups.append((remaining, bits, block))
    elif only is None:
        groups = [(weighted, bits, block)]
    else:
        pat = re.compile(only)
        sel = [n for n in weighted if pat.search(n)]
        groups = [(sel, bits, block), ([n for n in weighted if n not in sel], rest_bits, block)]
    model = src
    for nodes, b, blk in groups:
        if not nodes or b is None:
            continue
        # (nodes_to_include is OR-ed with "every MatMul" by the quantizer, so
        # select by excluding every other MatMul — and the fbank's — instead)
        chosen = set(nodes)
        exclude = [n.name for n in model.graph.node if n.op_type == 'MatMul' and n.name not in chosen]
        q = MatMulNBitsQuantizer(model, block_size=blk, is_symmetric=True, bits=b,
                                 nodes_to_exclude=exclude)
        q.process()
        model = q.model.model
    out = os.path.join(ART, f'{name}.onnx')
    onnx.save(model, out)
    print(f'{name}: {os.path.getsize(out) / 1e6:.1f} MB ({len(weighted)} weight MatMuls of {len(names)})')


if __name__ == '__main__':
    a = sys.argv
    if a[1] == 'fp32':
        drop = tuple(int(x) for x in a[a.index('--drop') + 1].split(',')) if '--drop' in a else ()
        student = a[a.index('--student') + 1] if '--student' in a else None
        out = a[a.index('--out') + 1] if '--out' in a else (
            'fp32' if not drop else 'fp32_drop' + '_'.join(map(str, drop)))
        export_fp32(drop, out, student)
    else:
        only = a[a.index('--only') + 1] if '--only' in a else None
        rest = int(a[a.index('--rest-bits') + 1]) if '--rest-bits' in a else None
        groups = [a[i + 1] for i, x in enumerate(a) if x == '--group']
        src = a[a.index('--src') + 1] if '--src' in a else 'fp32'
        quantize(a[2], int(a[3]), int(a[4]), only, rest, groups, src)
