"""Run one candidate acoustic model over the fixed benchmark.

  python bench_run.py <model.onnx | torch> <tag> [--screen] [--threads N] [--pack calib]

Writes artifacts/results/<tag>.json (case index with offsets, in the format
tool/acoustic_verification/evaluate.dart reads) + <tag>.f32 (log-probs),
and artifacts/results/<tag>.perf.json (load time, peak RAM, speed).
Audio longer than 20 s is run in 20 s chunks overlapping 2 s, as the
server does. --stream instead computes frames as the app's on-device
pipeline streams them (lib/ai/acoustic/acoustic_frame_stream.dart: windows
of 2-6 s new audio with 1 s context each side, the tail flushed; set by
STREAM_HOP_S, STREAM_MAX_HOP_S, STREAM_CONTEXT_S), to measure
what reusing the tracker's frames does to verification.
"""
import json, os, resource, sys, time
import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
ART = os.path.join(HERE, 'artifacts')
model, tag = sys.argv[1], sys.argv[2]
screen = '--screen' in sys.argv
stream = '--stream' in sys.argv
threads = int(sys.argv[sys.argv.index('--threads') + 1]) if '--threads' in sys.argv else os.cpu_count()
# Longest single run and the overlap between runs (the app's runInPieces);
# PIECE_S / PIECE_OVERLAP_S try other limits.
CHUNK = int(float(os.environ.get('PIECE_S', 20)) * 16000)
OVERLAP = int(float(os.environ.get('PIECE_OVERLAP_S', 2)) * 16000)
HOP = 640

t0 = time.time()
if model == 'torch':
    import torch, torch.nn.functional as F
    from quran_muaalem import Muaalem
    torch.set_num_threads(threads)
    dev = 'cuda' if torch.cuda.is_available() else 'cpu'
    m = Muaalem(model_name_or_path='obadx/muaalem-model-v3_2', device=dev, dtype=torch.float32)
    # TEACHER_WEIGHTS: a fine-tuned teacher (finetune_teacher.py).
    if os.environ.get('TEACHER_WEIGHTS'):
        m.model.load_state_dict(torch.load(os.environ['TEACHER_WEIGHTS'], map_location='cpu'))
        m.model.to(dev)
    m.model.eval()
    def run(w):
        f = m.processor([w], sampling_rate=16000, return_tensors='pt').to(dev)
        with torch.no_grad():
            return F.log_softmax(m.model(**f, return_dict=False)[0]['phonemes'][0], -1).float().cpu().numpy()
elif model.startswith('student:'):
    # A distilled student's PyTorch weights (a run dir); STREAM=chunk_s,left_s gives it
    # streaming.py's chunk masks.
    import torch, torch.nn.functional as F
    from quran_muaalem import Muaalem
    torch.set_num_threads(threads)
    dev = 'cuda' if torch.cuda.is_available() else 'cpu'
    m = Muaalem(model_name_or_path='obadx/muaalem-model-v3_2', device='cpu', dtype=torch.float32)
    d = model.split(':', 1)[1]
    net = m.model.__class__(m.model.config.__class__.from_pretrained(d))
    net.load_state_dict(torch.load(os.path.join(d, 'student.pt'), map_location='cpu'))
    net.to(dev).eval()
    causal = None
    if os.environ.get('STREAM'):
        import streaming
        from gpu_fbank import GpuFbank
        print('streaming', os.environ['STREAM'], streaming.enable(net, *streaming.parse(os.environ['STREAM'])),
              'attention layers', file=sys.stderr)
        fbank = GpuFbank(getattr(m.processor, 'feature_extractor', m.processor), dev)
        causal = streaming.prior(os.path.join(HERE, 'fbank_prior.json'), dev)
    def run(w):
        if causal is not None:
            x, mask = fbank.batch([w], causal)
            f = dict(input_features=x, attention_mask=mask)
        else:
            f = m.processor([w], sampling_rate=16000, return_tensors='pt').to(dev)
        with torch.no_grad():
            return F.log_softmax(net(**f, return_dict=False)[0]['phonemes'][0], -1).float().cpu().numpy()
else:
    import onnxruntime as ort
    so = ort.SessionOptions(); so.intra_op_num_threads = threads
    s = ort.InferenceSession(model, so)
    if os.environ.get('STREAM_CFG'):
        # A stateful streaming export (stream_model.py): the whole clip chunk by chunk,
        # its state carried, as the app runs it.
        cfg = json.load(open(os.environ['STREAM_CFG']))
        names = ['sums', 'count', 'kv', 'conv', 'akv', 'aconv', 'valid']
        def run(w):
            st = {k: np.zeros(cfg['state'][k], np.float32) for k in names}
            st['sums'] = np.array(cfg['initial']['sums'], np.float32)
            st['count'] = np.array(cfg['initial']['count'], np.float32)
            hop, outs, start = cfg['chunk_samples'], [], 0
            while start + 400 <= len(w):
                seg = w[start:start + hop + cfg['overlap_samples']]
                n = ((len(seg) - 400) // 160 + 1) // 2 * 2
                if n == 0:
                    break
                res = s.run(None, dict(samples=seg[:160 * (n - 1) + 400][None].astype(np.float32), **st))
                outs.append(res[0][0]); st = dict(zip(names, res[1:]))
                start += hop
            return np.concatenate(outs) if outs else np.zeros((0, 43), np.float32)
    else:
        def run(w):
            return s.run(None, {'waveform': w[None].astype(np.float32)})[0][0]
load_s = time.time() - t0

def streamed(w):
    ctx = int(float(os.environ.get('STREAM_CONTEXT_S', 1)) * 16000)
    min_hop = int(float(os.environ.get('STREAM_HOP_S', 2)) * 16000)
    max_hop = max(min_hop, int(float(os.environ.get('STREAM_MAX_HOP_S', 6)) * 16000))
    parts, done, written = [], 0, 0
    def window(flush):
        nonlocal done
        keep = done * HOP
        available = written - keep - (0 if flush else ctx)
        if available < (HOP if flush else min_hop):
            return False
        keep_end = keep + min(available, max_hop)
        frm = max(0, keep - ctx)
        lp = run(w[frm:min(written, keep_end + ctx)])
        parts.append(lp[done - frm // HOP:keep_end // HOP - frm // HOP])
        done = keep_end // HOP
        return True
    while written < len(w):
        written = min(len(w), written + 1600)
        window(False)
    while window(True):
        pass
    return np.concatenate(parts)

def frames(w):
    if stream:
        return streamed(w)
    if os.environ.get('STREAM_CFG'):
        return run(w)
    if len(w) <= CHUNK:
        return run(w)
    parts, start = [], 0
    while True:
        lp = run(w[start:start + CHUNK]); end = start + CHUNK >= len(w)
        first = 0 if start == 0 else (OVERLAP // 2) // HOP
        last = len(lp) if end else len(lp) - (OVERLAP // 2) // HOP
        parts.append(lp[first:last])
        if end: return np.concatenate(parts)
        start += CHUNK - OVERLAP

# --pack calib: the calibration set (build_calibration.py) instead of the final test.
pack = sys.argv[sys.argv.index('--pack') + 1] if '--pack' in sys.argv else 'bench'
cases = json.load(open(os.path.join(ART, f'{pack}_cases.json')))
audio = np.load(os.path.join(ART, f'{pack}_audio.npz'))
out, blobs, off, infer, secs = [], [], 0, 0.0, 0.0
run(np.zeros(16000, np.float32))  # warm-up
for i, c in enumerate(cases):
    if screen and not c['screen']:
        continue
    w = audio[f'c{i}']
    t = time.time(); lp = frames(w).astype('<f4'); infer += time.time() - t; secs += len(w) / 16000
    c = dict(c, main=dict(offset=off, frames=int(lp.shape[0])), shifted=None)
    blobs.append(lp.ravel()); off += lp.size; out.append(c)
# 8 s benchmark (one clean ayah, repeated for a stable timing)
w8 = next(audio[f'c{i}'] for i, c in enumerate(cases) if c['set'] == 'clean' and len(audio[f'c{i}']) >= 16000 * 8)[:16000 * 8]
t = time.time()
for _ in range(3): run(w8)
t8 = (time.time() - t) / 3
os.makedirs(os.path.join(ART, 'results'), exist_ok=True)
np.concatenate(blobs).tofile(os.path.join(ART, 'results', tag + '.f32'))
json.dump(out, open(os.path.join(ART, 'results', tag + '.json'), 'w'))
perf = dict(tag=tag, model=model, threads=threads, cases=len(out), load_s=round(load_s, 2),
            peak_rss_mb=round(resource.getrusage(resource.RUSAGE_SELF).ru_maxrss / 1024),
            audio_s=round(secs, 1), infer_s=round(infer, 1), rtf=round(infer / secs, 3),
            eight_s_audio_s=round(t8, 2),
            size_mb=round(os.path.getsize(model) / 1e6, 1) if os.path.isfile(model) else None)
json.dump(perf, open(os.path.join(ART, 'results', tag + '.perf.json'), 'w'))
print(json.dumps(perf))
