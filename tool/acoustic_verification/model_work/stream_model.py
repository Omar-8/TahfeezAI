"""v3 phase 2: a streaming student run chunk by chunk with its past cached, for export.

The masked student (streaming.py) computes, over a whole clip, what this computes one
chunk at a time: every attention layer keeps the keys and values of the frames before
the chunk (its left context), every causal convolution its last inputs, the adapter's
stride-2 convolutions their last input frame, and the features their running
normalisation sums. Each chunk of audio is computed once.

  python stream_model.py <student run dir> [--chunk 1.28 --left 5.12]   # checks it
      against the masked student on real clips (outputs must match)

Audio framing: fbank frame k covers samples [160k, 160k + 400); stacked pairs make
20 ms frames. A chunk of C stacked frames (C = chunk / 0.02) needs samples
[chunk_start, chunk_start + 320 C + 240): the caller keeps the last 240 samples.
"""
import json, math, os, sys
import numpy as np
import torch
import torch.nn.functional as F
from torch import nn

HERE = os.path.dirname(os.path.abspath(__file__))


def load_student(run_dir):
    from quran_muaalem import Muaalem
    m = Muaalem(model_name_or_path='obadx/muaalem-model-v3_2', device='cpu', dtype=torch.float32)
    net = m.model.__class__(m.model.config.__class__.from_pretrained(run_dir))
    net.load_state_dict(torch.load(os.path.join(run_dir, 'student.pt'), map_location='cpu'))
    return net.eval(), getattr(m.processor, 'feature_extractor', m.processor)


class StreamFbank(nn.Module):
    """gpu_fbank's fbank with running normalisation, one chunk at a time.
    In: samples (1, 320 C + 240), sums (2, 80) [sum, sum of squares], count (1,).
    Out: features (1, C, 160), new sums, new count."""

    def __init__(self, fe):
        super().__init__()
        n = torch.arange(400, dtype=torch.float64)
        k = torch.arange(257, dtype=torch.float64)
        ang = 2 * math.pi * n[:, None] * k[None, :] / 512
        win = torch.tensor(fe.window, dtype=torch.float64)
        self.register_buffer('cos', (win[:, None] * torch.cos(ang)).float())
        self.register_buffer('sin', (win[:, None] * torch.sin(ang)).float())
        self.register_buffer('mel', torch.tensor(fe.mel_filters, dtype=torch.float32))
        self.register_buffer('offsets', torch.arange(400))

    def forward(self, samples, sums, count):
        x = samples[0] * 32768.0
        frames = (x.shape[0] - 400) // 160 + 1
        f = x[torch.arange(frames)[:, None] * 160 + self.offsets[None, :]]
        f = f - f.mean(dim=1, keepdim=True)
        f = torch.cat([f[:, :1] * 0.03, f[:, 1:] - 0.97 * f[:, :-1]], dim=1)
        re, im = f @ self.cos, f @ self.sin
        m = torch.log(torch.clamp((re * re + im * im) @ self.mel, min=1.192092955078125e-07))
        s1 = sums[0] + torch.cumsum(m, 0)
        s2 = sums[1] + torch.cumsum(m * m, 0)
        k = count + torch.arange(1, frames + 1, dtype=m.dtype)[:, None]
        mean = s1 / k
        var = s2 / k - mean * mean
        out = (m - mean) / torch.sqrt(torch.clamp(var, min=0) + 1e-7)
        return (out.reshape(1, frames // 2, 160), torch.stack([s1[-1], s2[-1]]),
                count + frames)


class StreamEncoder(nn.Module):
    """The student after its features, a chunk at a time with cached past.
    State: per conformer layer keys/values (2, heads, L, d) and conv inputs (D, K-1);
    adapter keys/values (2, heads, L/2, d) and its two convolutions' last frame;
    [valid]: how many past frames are real (the rest of the cache is masked)."""

    def __init__(self, net, chunk, left):
        super().__init__()
        w = net.wav2vec2_bert
        self.fp, self.layers, self.adapter = w.feature_projection, w.encoder.layers, w.adapter.layers[0]
        self.head = net.level_to_lm_head['phonemes']
        self.C, self.L = chunk, left                    # 20 ms frames
        self.Ca, self.La = chunk // 2, left // 2        # adapter: 40 ms frames
        a = self.layers[0].self_attn
        self.H, self.d = a.num_heads, a.head_size
        self.K = self.layers[0].conv_module.depthwise_conv.kernel_size[0]
        self.lmax, self.rmax = a.left_max_position_embeddings, a.right_max_position_embeddings
        # relative distances key - query: keys are the L cached frames then the chunk
        q = torch.arange(left, left + chunk)[:, None]
        kk = torch.arange(left + chunk)[None, :]
        self.register_buffer('dist', torch.clamp(kk - q, -self.lmax, self.rmax) + self.lmax)

    def state_shapes(self):
        D, H, d = 1024, self.H, self.d
        n = len(self.layers)
        return dict(kv=(n, 2, H, self.L, d), conv=(n, D, self.K - 1), akv=(2, H, self.La, d),
                    aconv=(2, D, 1), valid=(1,))

    @staticmethod
    def _heads(x, H, d):
        return x.view(x.shape[0], H, d).transpose(0, 1)              # (H, T, d)

    def _attend(self, attn, x, kv, keep, mask_past, rel):
        """x (T, D) normed; kv (2, H, P, d) past; returns (T, D) and the new past."""
        H, d = attn.num_heads, attn.head_size
        q = self._heads(attn.linear_q(x), H, d)
        k = self._heads(attn.linear_k(x), H, d)
        v = self._heads(attn.linear_v(x), H, d)
        K = torch.cat([kv[0], k], 1)
        V = torch.cat([kv[1], v], 1)
        s = torch.matmul(q, K.transpose(1, 2)) / math.sqrt(d)
        if rel is not None:
            pe = attn.distance_embedding(rel)                        # (T, P+T, d)
            s = s + torch.einsum('hld,lrd->hlr', q, pe) / math.sqrt(d)
        s = s + mask_past                                            # (P+T) bias: invalid past
        p = torch.softmax(s, -1)
        out = torch.matmul(p, V).transpose(0, 1).reshape(x.shape[0], H * d)
        return attn.linear_out(out), torch.stack([K[:, -keep:], V[:, -keep:]])

    def forward(self, feats, kv, conv, akv, aconv, valid):
        x = self.fp(feats)[0][0]                                      # (C, D)
        T = x.shape[0]
        neg = torch.finfo(x.dtype).min
        past = torch.arange(self.L, dtype=valid.dtype)
        mask = torch.cat([torch.where(past >= self.L - valid, 0.0, neg), torch.zeros(T)])
        new_kv, new_conv = [], []
        for i, layer in enumerate(self.layers):
            r = x
            x = layer.ffn1(layer.ffn1_layer_norm(x)) * 0.5 + r
            r = x
            h, kvi = self._attend(layer.self_attn, layer.self_attn_layer_norm(x), kv[i], self.L,
                                  mask, self.dist[:T, :self.L + T])
            x = h + r
            # causal depthwise convolution module, its last K-1 inputs cached
            cm = layer.conv_module
            # (pointwise convolutions as matrix products, so 4-bit quantisation reaches them)
            h = F.glu(F.linear(cm.layer_norm(x), cm.pointwise_conv1.weight[:, :, 0], cm.pointwise_conv1.bias), dim=-1)
            h = torch.cat([conv[i][None], h.transpose(0, 1)[None]], 2)  # (1, D, K-1+T)
            new_conv.append(h[0, :, -(self.K - 1):])
            h = cm.depthwise_conv(h)
            h = cm.depthwise_layer_norm(h.transpose(1, 2)).transpose(1, 2)
            h = cm.activation(h)
            x = x + F.linear(h[0].transpose(0, 1), cm.pointwise_conv2.weight[:, :, 0], cm.pointwise_conv2.bias)
            r = x
            x = layer.ffn2(layer.ffn2_layer_norm(x)) * 0.5 + r
            x = layer.final_layer_norm(x)
            new_kv.append(kvi)
        # adapter: stride-2 convolutions (kernel 3, padding 1) need the previous frame
        ad = self.adapter
        def pooled(norm, convl, last):
            h = norm(x).transpose(0, 1)[None]                        # (1, D, T)
            h = torch.cat([last[None], h], 2)                        # previous frame first
            keep = h[0, :, -1:]
            h = F.pad(h, (0, T % 2))     # an odd (final) chunk: the whole clip's zero padding
            # kernel 3, stride 2 as one matrix product over each output's three input frames
            h = h[0].transpose(0, 1)                                 # (1 + T', D)
            n = (h.shape[0] - 3) // 2 + 1
            idx = torch.arange(n)[:, None] * 2 + torch.arange(3)[None, :]
            win = h[idx].reshape(n, 3 * h.shape[1])                  # frames t-1, t, t+1
            wgt = convl.weight.permute(0, 2, 1).reshape(convl.weight.shape[0], -1)
            return F.glu(F.linear(win, wgt, convl.bias), dim=-1), keep
        res, last_r = pooled(ad.residual_layer_norm, ad.residual_conv, aconv[0])
        h, last_a = pooled(ad.self_attn_layer_norm, ad.self_attn_conv, aconv[1])
        Ta = h.shape[0]
        apast = torch.arange(self.La, dtype=valid.dtype)
        amask = torch.cat([torch.where(apast >= self.La - valid // 2, 0.0, neg), torch.zeros(Ta)])
        h, akvi = self._attend(ad.self_attn, h, akv, self.La, amask, None)
        x = h + res
        x = ad.ffn(ad.ffn_layer_norm(x)) + x
        lp = F.log_softmax(self.head(x), -1)[None]
        return (lp, torch.stack(new_kv), torch.stack(new_conv), akvi,
                torch.stack([last_r, last_a]), torch.clamp(valid + T, max=self.L))


def initial_state(enc, prior_path):
    p = json.load(open(prior_path))
    mu, var, n0 = torch.tensor(p['mean']), torch.tensor(p['var']), 100.0
    sh = enc.state_shapes()
    return dict(sums=torch.stack([n0 * mu, n0 * (var + mu * mu)]), count=torch.tensor([n0]),
                kv=torch.zeros(sh['kv']), conv=torch.zeros(sh['conv']), akv=torch.zeros(sh['akv']),
                aconv=torch.zeros(sh['aconv']), valid=torch.zeros(1))


def run_stream(fbank, enc, st, wave, chunk):
    """The whole clip chunk by chunk (the last, partial chunk run as it is)."""
    hop = 320 * chunk
    outs, start = [], 0
    with torch.no_grad():
        while start + 400 <= len(wave):
            seg = wave[start:start + hop + 240]
            n = ((len(seg) - 400) // 160 + 1) // 2 * 2               # whole stacked frames
            if n == 0:
                break
            seg = seg[:160 * (n - 1) + 400]
            feats, st['sums'], st['count'] = fbank(torch.from_numpy(seg)[None], st['sums'], st['count'])
            lp, st['kv'], st['conv'], st['akv'], st['aconv'], st['valid'] = enc(
                feats, st['kv'], st['conv'], st['akv'], st['aconv'], st['valid'])
            outs.append(lp[0].numpy())
            start += hop
    return np.concatenate(outs)


class StreamStep(nn.Module):
    """One chunk: audio and state in, log-probabilities and state out (the exported graph)."""

    def __init__(self, fbank, enc):
        super().__init__()
        self.fbank, self.enc = fbank, enc

    def forward(self, samples, sums, count, kv, conv, akv, aconv, valid):
        feats, sums, count = self.fbank(samples, sums, count)
        lp, kv, conv, akv, aconv, valid = self.enc(feats, kv, conv, akv, aconv, valid)
        return lp, sums, count, kv, conv, akv, aconv, valid


STATE = ['sums', 'count', 'kv', 'conv', 'akv', 'aconv', 'valid']


def gemm_to_matmul(model):
    """Gemm(A, W, b, transB) with constant W -> MatMul(A, W^T) + Add(b): the 4-bit
    quantiser (MatMulNBits) only takes MatMul."""
    import onnx
    from onnx import helper, numpy_helper
    inits = {t.name: t for t in model.graph.initializer}
    nodes, n = [], 0
    for node in model.graph.node:
        attrs = {a.name: helper.get_attribute_value(a) for a in node.attribute}
        if (node.op_type != 'Gemm' or node.input[1] not in inits or attrs.get('transA', 0)
                or attrs.get('alpha', 1.0) != 1.0 or attrs.get('beta', 1.0) != 1.0):
            nodes.append(node)
            continue
        w = numpy_helper.to_array(inits[node.input[1]])
        if attrs.get('transB', 0):
            w = w.T
        wname = node.input[1] + '_mm'
        model.graph.initializer.append(numpy_helper.from_array(np.ascontiguousarray(w), wname))
        mid = node.output[0] + '_mm'
        nodes.append(helper.make_node('MatMul', [node.input[0], wname], [mid] if len(node.input) > 2 else [node.output[0]],
                                      name=node.name + '_MatMul'))
        if len(node.input) > 2:
            nodes.append(helper.make_node('Add', [mid, node.input[2]], [node.output[0]], name=node.name + '_Add'))
        n += 1
    del model.graph.node[:]
    model.graph.node.extend(nodes)
    used = {i for nd in model.graph.node for i in nd.input}
    keep = [t for t in model.graph.initializer if t.name in used]
    del model.graph.initializer[:]
    model.graph.initializer.extend(keep)
    return n


def export(run_dir, out_dir, chunk_s, left_s):
    import onnx
    net, fe = load_student(run_dir)
    C, L = round(chunk_s / 0.02), round(left_s / 0.02)
    enc, fbank = StreamEncoder(net, C, L).eval(), StreamFbank(fe).eval()
    step = StreamStep(fbank, enc).eval()
    st = initial_state(enc, os.path.join(HERE, 'fbank_prior.json'))
    samples = torch.zeros(1, 320 * C + 240)
    args = (samples,) + tuple(st[k] for k in STATE)
    os.makedirs(out_dir, exist_ok=True)
    out = os.path.join(out_dir, 'model.onnx')
    with torch.no_grad():
        torch.onnx.export(step, args, out, input_names=['samples'] + STATE,
                          output_names=['log_probs'] + [k + '_out' for k in STATE],
                          dynamic_axes={'samples': {1: 'n'}, 'log_probs': {1: 'frames'}},
                          opset_version=17, dynamo=False)
    m = onnx.load(out, load_external_data=True)
    print('Gemm -> MatMul:', gemm_to_matmul(m))
    onnx.save(m, out, save_as_external_data=True, all_tensors_to_one_file=True, location='model.onnx.data')
    json.dump(dict(chunk_s=chunk_s, left_s=left_s, chunk_frames=C, left_frames=L,
                   chunk_samples=320 * C, overlap_samples=240,
                   state={k: list(v.shape) for k, v in st.items()},
                   initial={'sums': st['sums'].tolist(), 'count': st['count'].tolist()}),
              open(os.path.join(out_dir, 'stream.json'), 'w'), indent=1)
    print('exported', out)


def run_onnx(sess, st, wave, chunk):
    """As run_stream, on the exported graph (onnxruntime)."""
    hop = 320 * chunk
    outs, start = [], 0
    st = {k: v.numpy().astype(np.float32) for k, v in st.items()}
    while start + 400 <= len(wave):
        seg = wave[start:start + hop + 240]
        n = ((len(seg) - 400) // 160 + 1) // 2 * 2
        if n == 0:
            break
        seg = seg[:160 * (n - 1) + 400]
        res = sess.run(None, dict(samples=seg[None].astype(np.float32), **st))
        outs.append(res[0][0])
        st = dict(zip(STATE, res[1:]))
        start += hop
    return np.concatenate(outs)


if __name__ == '__main__' and '--export' in sys.argv:
    # python stream_model.py <run dir> --export <out dir> [--chunk 1.28 --left 5.12]
    # then checks the graph (onnxruntime) against the PyTorch chunk loop on real clips
    import onnxruntime as ort
    run, out = sys.argv[1], sys.argv[sys.argv.index('--export') + 1]
    chunk_s = float(sys.argv[sys.argv.index('--chunk') + 1]) if '--chunk' in sys.argv else 1.28
    left_s = float(sys.argv[sys.argv.index('--left') + 1]) if '--left' in sys.argv else 5.12
    export(run, out, chunk_s, left_s)
    net, fe = load_student(run)
    C, L = round(chunk_s / 0.02), round(left_s / 0.02)
    enc, fbank = StreamEncoder(net, C, L).eval(), StreamFbank(fe).eval()
    sess = ort.InferenceSession(os.path.join(out, 'model.onnx'))
    z = np.load(os.path.join(HERE, 'artifacts', 'retasy_audio.npz'))
    worst = 0
    for k in z.files[:60:6]:
        w = z[k].astype(np.float32)
        if np.abs(w).max() > 2:
            w = w / 32767
        a = run_stream(fbank, enc, initial_state(enc, os.path.join(HERE, 'fbank_prior.json')), w, C)
        b = run_onnx(sess, initial_state(enc, os.path.join(HERE, 'fbank_prior.json')), w, C)
        d = float(np.abs(a - b).max()); worst = max(worst, d)
        print(f'{len(w) / 16000:5.1f} s: {len(a)} frames, onnx vs torch max diff {d:.2e}')
    print('WORST', worst)
    sys.exit(0)

if __name__ == '__main__':
    import streaming
    from gpu_fbank import GpuFbank
    run = sys.argv[1]
    chunk_s = float(sys.argv[sys.argv.index('--chunk') + 1]) if '--chunk' in sys.argv else 1.28
    left_s = float(sys.argv[sys.argv.index('--left') + 1]) if '--left' in sys.argv else 5.12
    net, fe = load_student(run)
    C, L = round(chunk_s / 0.02), round(left_s / 0.02)
    enc, fbank = StreamEncoder(net, C, L).eval(), StreamFbank(fe).eval()
    masked, _ = load_student(run)
    streaming.enable(masked, chunk_s, left_s)
    g = GpuFbank(fe, 'cpu'); prior = streaming.prior(os.path.join(HERE, 'fbank_prior.json'), 'cpu')
    z = np.load(os.path.join(HERE, 'artifacts', 'retasy_audio.npz'))
    clips = [z[k].astype(np.float32) for k in z.files[:120] if len(z[k]) > 16000 * 3][:16]
    worst = 0
    for w in clips:
        if np.abs(w).max() > 2:
            w = w / 32767
        if ((len(w) - 400) // 160 + 1) % 2:
            # as the app's export: whole stacked frames only (the extractor's padding of an
            # odd last frame leaks into the adapter's last chunk; the app never has it)
            w = w[:len(w) - 160]
        a, mk = g.batch([w], prior)
        with torch.no_grad():
            ref = F.log_softmax(masked(input_features=a, attention_mask=mk, return_dict=False)[0]['phonemes'][0], -1).numpy()
        got = run_stream(fbank, enc, initial_state(enc, os.path.join(HERE, 'fbank_prior.json')), w, C)
        n = min(len(ref), len(got))
        d = float(np.abs(ref[:n] - got[:n]).max())
        worst = max(worst, d)
        per = np.abs(ref[:n] - got[:n]).max(1)
        bad = np.nonzero(per > 1e-3)[0]
        fb = (len(w) - 400) // 160 + 1
        print(f'{len(w) / 16000:5.1f} s: frames {len(ref)} masked / {len(got)} streamed, max diff {d:.2e}; '
              f'fbank frames {fb} ({"odd" if fb % 2 else "even"}); frames differing: {bad.tolist()[:8]} of {n}')
    print('WORST', worst)
