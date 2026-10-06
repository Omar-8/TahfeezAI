"""Writes continuous recitation as 16 kHz mono PCM16LE for the on-device
benchmark (integration_test/acoustic_model_android_test.dart): Ya-Sin 36:1-12,
one reciter, from the model benchmark's clean ayahs. Development only; not
shipped (recording rights: see docs/THIRD_PARTY_RESOURCES.md).

  .venv/bin/python device_bench_audio.py <bench dir> <out.pcm> [--reciter 0]
"""
import argparse, json
from pathlib import Path
import numpy as np

p = argparse.ArgumentParser()
p.add_argument('bench'); p.add_argument('out'); p.add_argument('--reciter', type=int, default=0)
a = p.parse_args()
cases = json.load(open(Path(a.bench) / 'bench_cases.json'))
audio = np.load(Path(a.bench) / 'bench_audio.npz')
clips = {}
for i, c in enumerate(cases):
    if c['set'] == 'clean':
        clips.setdefault(c['ayahId'], []).append(i)
parts = []
for ayah in range(36001, 36013):
    parts += [audio['c%d' % clips[ayah][a.reciter]], np.zeros(4800, np.float32)]
x = np.concatenate(parts)
pcm = (np.clip(x, -1, 1) * 32767).astype('<i2')
Path(a.out).write_bytes(pcm.tobytes())
print(a.out, f'{len(x) / 16000:.1f} s')
