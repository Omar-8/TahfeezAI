"""Writes the manifest an on-device acoustic model needs (quran_acoustic.json).

The app only loads a model whose manifest matches what it expects (format,
16 kHz, 43 classes in the app's vocabulary order, 40 ms frames) and whose
SHA-256 and size match the file — see lib/ai/acoustic/acoustic_model_manifest.dart.

  python3 model_manifest.py <model.onnx> [--id ID] [--max-window 20] [--out DIR]
      [--stream stream.json]   # a streaming model (model_work/stream_model.py --export)
"""
import argparse, hashlib, json, re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]

def vocabulary():
    """The app's phoneme classes, read from its source (one truth)."""
    src = (ROOT / 'lib/ai/acoustic/quran_phonetic_reference.dart').read_text('utf-8')
    body = src[src.index('const quranPhoneticVocabulary'):]
    body = body[:body.index('];')]
    return re.findall(r"'([^']*)'", body)

def main():
    p = argparse.ArgumentParser()
    p.add_argument('model')
    p.add_argument('--id')
    p.add_argument('--max-window', type=float, default=20)
    p.add_argument('--out')
    p.add_argument('--stream', help="a streaming export's stream.json: chunking and state")
    a = p.parse_args()
    model = Path(a.model)
    digest = hashlib.sha256()
    with model.open('rb') as f:
        for block in iter(lambda: f.read(1 << 20), b''):
            digest.update(block)
    vocab = vocabulary()
    assert len(vocab) == 43, len(vocab)
    manifest = {
        'id': a.id or model.stem,
        'format': 1,
        'sample_rate': 16000,
        'classes': len(vocab),
        'vocabulary': vocab,
        'frame_ms': 40,
        'max_window_seconds': a.max_window,
        'sha256': digest.hexdigest(),
        'bytes': model.stat().st_size,
        'licence': 'MIT (obadx/muaalem-model-v3_2); training audio rights unverified',
        'experimental': True,
    }
    if a.stream:
        # Chunk by chunk with the state carried (see the app's StreamingAcousticModel):
        # chunk_samples of audio and overlap_samples after it per run.
        cfg = json.loads(Path(a.stream).read_text('utf-8'))
        manifest['stream'] = {k: cfg[k] for k in
                              ('chunk_s', 'left_s', 'chunk_samples', 'overlap_samples', 'state', 'initial')}
    out = Path(a.out) if a.out else model.parent
    out.mkdir(parents=True, exist_ok=True)
    (out / 'quran_acoustic.json').write_text(json.dumps(manifest, ensure_ascii=False, indent=1), 'utf-8')
    print(out / 'quran_acoustic.json', manifest['sha256'], manifest['bytes'])

if __name__ == '__main__':
    main()
