"""Export a Quran phoneme CTC model to ONNX for on-device verification.

  python export_model.py <out dir> [teacher|mini]

teacher = obadx/muaalem-model-v3_2 (MIT); mini = sysofwan/hifzguide-muaalem-mini
(AGPL-3.0, training data CC BY-NC). The SeamlessM4T fbank front end is in
the graph: input waveform float32 [1, samples] (16 kHz, [-1, 1]), output
log_probs float32 [1, frames, 43] (40 ms frames). MatMul weights are 4-bit
block-quantized (weight-only), convolution weights float16.
"""
import math, os, sys
import numpy as np
import onnx
import torch
import torch.nn.functional as F
from onnx import TensorProto, helper, numpy_helper
from onnxruntime.quantization.matmul_nbits_quantizer import MatMulNBitsQuantizer
from onnxruntime.quantization.shape_inference import quant_pre_process


class Fbank(torch.nn.Module):
    """SeamlessM4TFeatureExtractor in ONNX-exportable torch ops."""

    def __init__(self, fe):
        super().__init__()
        n = torch.arange(400, dtype=torch.float64)
        k = torch.arange(257, dtype=torch.float64)
        ang = 2 * math.pi * n[:, None] * k[None, :] / 512
        win = torch.tensor(fe.window, dtype=torch.float64)
        self.register_buffer("cos", (win[:, None] * torch.cos(ang)).float())
        self.register_buffer("sin", (win[:, None] * torch.sin(ang)).float())
        self.register_buffer("mel", torch.tensor(fe.mel_filters, dtype=torch.float32))
        self.register_buffer("offsets", torch.arange(400))

    def forward(self, wave):
        x = wave[0] * 32768.0
        frames = (x.shape[0] - 400) // 160 + 1
        f = x[torch.arange(frames)[:, None] * 160 + self.offsets[None, :]]
        f = f - f.mean(dim=1, keepdim=True)
        f = torch.cat([f[:, :1] * 0.03, f[:, 1:] - 0.97 * f[:, :-1]], dim=1)
        re, im = f @ self.cos, f @ self.sin
        m = torch.log(torch.clamp((re * re + im * im) @ self.mel, min=1.192092955078125e-07))
        mean = m.mean(dim=0, keepdim=True)
        var = ((m - mean) ** 2).sum(dim=0, keepdim=True) / (m.shape[0] - 1)
        m = (m - mean) / torch.sqrt(var + 1e-7)
        even = (m.shape[0] // 2) * 2
        return m[:even].reshape(1, even // 2, 160)


class Wrapped(torch.nn.Module):
    def __init__(self, model, fe, teacher):
        super().__init__()
        self.fbank, self.model, self.teacher = Fbank(fe), model, teacher

    def forward(self, wave):
        feats = self.fbank(wave)
        mask = torch.ones(feats.shape[:2], dtype=torch.long)
        if self.teacher:
            logits = self.model(input_features=feats, attention_mask=mask, return_dict=False)[0]["phonemes"]
        else:
            logits = self.model(input_features=feats, attention_mask=mask).logits["phonemes"]
        return F.log_softmax(logits, dim=-1)


def conv_weights_to_fp16(model):
    g = model.graph
    targets = {n.input[1] for n in g.node if n.op_type == "Conv"}
    inits = {t.name: t for t in g.initializer}
    casts = []
    for name in targets:
        t = inits.get(name)
        if t is None or t.data_type != TensorProto.FLOAT or np.prod(t.dims) < 4096:
            continue
        g.initializer.remove(t)
        g.initializer.append(numpy_helper.from_array(numpy_helper.to_array(t).astype(np.float16), name + "_fp16"))
        casts.append(helper.make_node("Cast", [name + "_fp16"], [name], to=TensorProto.FLOAT))
    for node in reversed(casts):
        g.node.insert(0, node)


def main():
    out, which = sys.argv[1], (sys.argv[2] if len(sys.argv) > 2 else "teacher")
    os.makedirs(out, exist_ok=True)
    if which == "teacher":
        from quran_muaalem import Muaalem
        m = Muaalem(model_name_or_path="obadx/muaalem-model-v3_2", device="cpu", dtype=torch.float32)
        model, fe = m.model.eval(), m.processor
    else:
        from transformers import AutoFeatureExtractor, AutoModel
        repo = "sysofwan/hifzguide-muaalem-mini"
        model = AutoModel.from_pretrained(repo, trust_remote_code=True).eval()
        fe = AutoFeatureExtractor.from_pretrained(repo)
    fe = getattr(fe, "feature_extractor", fe)
    wrapped = Wrapped(model, fe, which == "teacher").eval()
    wave = (np.random.default_rng(0).standard_normal(16000 * 5) * 0.1).astype(np.float32)
    ref = fe(wave, sampling_rate=16000, return_tensors="pt")["input_features"]
    diff = float((ref - wrapped.fbank(torch.from_numpy(wave)[None])).abs().max())
    assert diff < 1e-3, f"in-graph features differ by {diff}"
    fp32 = os.path.join(out, f"{which}_fp32.onnx")
    final = os.path.join(out, f"{which}_q4.onnx")
    with torch.no_grad():
        torch.onnx.export(wrapped, (torch.from_numpy(wave)[None],), fp32,
                          input_names=["waveform"], output_names=["log_probs"],
                          dynamic_axes={"waveform": {1: "samples"}, "log_probs": {1: "frames"}},
                          opset_version=17, dynamo=False)
    del wrapped, model
    q = MatMulNBitsQuantizer(onnx.load(fp32, load_external_data=True), block_size=32, is_symmetric=True, bits=4)
    q.process()
    conv_weights_to_fp16(q.model.model)
    onnx.save(q.model.model, final)
    print(final, os.path.getsize(final) // 1_000_000, "MB")


if __name__ == "__main__":
    main()
