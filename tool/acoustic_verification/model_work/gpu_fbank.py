"""GPU feature extraction for distillation: SeamlessM4TFeatureExtractor's
fbank (as in export_model.Fbank) computed on the GPU per clip, padded and
masked like the extractor. Checked against it by `python gpu_fbank.py data`."""
import math, sys, glob, time
import numpy as np
import torch


class GpuFbank(torch.nn.Module):
    def __init__(self, fe, device):
        # Extractor parity (padded frames, masks, values): `python gpu_fbank.py data`
        # on an RTX 3090 — max difference 2.5e-3 on unit-scale features (float32 vs
        # the extractor's float64), identical masks; 6-80 ms per batch vs 0.4-1.2 s.
        super().__init__()
        n = torch.arange(400, dtype=torch.float64)
        k = torch.arange(257, dtype=torch.float64)
        ang = 2 * math.pi * n[:, None] * k[None, :] / 512
        win = torch.tensor(fe.window, dtype=torch.float64)
        self.cos = (win[:, None] * torch.cos(ang)).float().to(device)
        self.sin = (win[:, None] * torch.sin(ang)).float().to(device)
        self.mel = torch.tensor(fe.mel_filters, dtype=torch.float32).to(device)
        self.offsets = torch.arange(400, device=device)
        self.device = device

    def one(self, wave):
        x = wave * 32768.0
        frames = (x.shape[0] - 400) // 160 + 1
        f = x[torch.arange(frames, device=self.device)[:, None] * 160 + self.offsets[None, :]]
        f = f - f.mean(dim=1, keepdim=True)
        f = torch.cat([f[:, :1] * 0.03, f[:, 1:] - 0.97 * f[:, :-1]], dim=1)
        re, im = f @ self.cos, f @ self.sin
        m = torch.log(torch.clamp((re * re + im * im) @ self.mel, min=1.192092955078125e-07))
        mean = m.mean(dim=0, keepdim=True)
        var = ((m - mean) ** 2).sum(dim=0, keepdim=True) / (m.shape[0] - 1)
        return (m - mean) / torch.sqrt(var + 1e-7)            # (frames, 80)

    def batch(self, waves):
        """(input_features (B, T/2, 160), attention_mask (B, T/2)) like the extractor."""
        mels = [self.one(torch.from_numpy(np.asarray(w, dtype=np.float32)).to(self.device))
                for w in waves]
        longest = max(m.shape[0] for m in mels)
        longest += longest % 2
        # Padding frames hold 1.0, as the extractor's (padding_value=1.0).
        x = torch.ones(len(mels), longest, 80, device=self.device)
        mask = torch.zeros(len(mels), longest, dtype=torch.long, device=self.device)
        for i, m in enumerate(mels):
            x[i, :m.shape[0]] = m
            mask[i, :m.shape[0]] = 1
        return x.reshape(len(mels), longest // 2, 160), mask[:, 1::2]


if __name__ == '__main__':
    from transformers import AutoFeatureExtractor
    sys.path.insert(0, '.')
    import distill_student as ds
    fe = getattr(ds.load_processor() if hasattr(ds, 'load_processor') else None, 'feature_extractor', None) \
        or AutoFeatureExtractor.from_pretrained('obadx/muaalem-model-v3_2')
    gpu = GpuFbank(fe, 'cuda')
    it = ds.batches(sys.argv[1], 120, 0)
    worst = 0
    for _ in range(6):
        items = next(it)
        ref = fe([x for x, _ in items], sampling_rate=16000, return_tensors='pt', padding=True)
        t = time.time(); x, mask = gpu.batch([x for x, _ in items]); torch.cuda.synchronize()
        tg = time.time() - t
        t = time.time(); fe([x for x, _ in items], sampling_rate=16000, return_tensors='pt', padding=True); tc = time.time() - t
        rx, rm = ref['input_features'], ref['attention_mask']
        assert rx.shape == x.shape, (rx.shape, x.shape)
        assert torch.equal(rm, mask.cpu()), 'mask differs'
        valid = rm.bool()
        d = (rx[valid] - x.cpu()[valid]).abs().max().item()
        pad = x.cpu()[~valid].abs().max().item() if (~valid).any() else 0
        refpad = rx[~valid].abs().max().item() if (~valid).any() else 0
        worst = max(worst, d)
        print(f'batch {len(items)} clips {tuple(x.shape)}: max diff {d:.2e}, pad gpu {pad} ref {refpad}, gpu {tg*1000:.0f} ms vs cpu {tc*1000:.0f} ms')
    print('WORST', worst)
