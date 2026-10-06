"""Acoustic model server for Quran Acoustic Verification.

Setup (once): ./setup.sh   — then run with .venv/bin/python server.py

Runs the phoneme CTC model and returns frame-level log-probabilities; the
app aligns and verifies them itself (lib/ai/acoustic/).

  python server.py [--port 8790] [--model teacher|onnx:<path>]

  GET  /v1/info    {"model", "vocabulary", "sampleRate", "frameMs"}
  POST /v1/frames  body: PCM16LE mono 16 kHz
                   -> float32 little-endian frames x classes,
                      headers X-Frames, X-Classes, X-Model-Ms

Long audio is processed in 20 s chunks overlapping by 2 s (the model's
memory grows with the square of the length).
"""
import argparse, json, os, sys, threading, time
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

import numpy as np

# The model's output classes (Quran Phonetic Script; 0 = CTC blank).
VOCAB = ['', 'ء', 'ب', 'ت', 'ث', 'ج', 'ح', 'خ', 'د', 'ذ', 'ر', 'ز', 'س', 'ش', 'ص', 'ض',
         'ط', 'ظ', 'ع', 'غ', 'ف', 'ق', 'ك', 'ل', 'م', 'ن', 'ه', 'و', 'ي', 'ا', 'ۦ', 'ۥ',
         'َ', 'ُ', 'ِ', '۪', 'ـ', 'ٲ', 'ڇ', 'ں', '۾', 'ۜ', 'ؙ']

CHUNK, OVERLAP, HOP = 16000 * 20, 16000 * 2, 640


class Model:
    def __init__(self, spec):
        self.lock = threading.Lock()
        if spec == 'teacher':
            import torch, torch.nn.functional as F
            from quran_muaalem import Muaalem
            torch.set_num_threads(os.cpu_count())
            m = Muaalem(model_name_or_path='obadx/muaalem-model-v3_2', device='cpu', dtype=torch.float32)
            self.id = 'obadx/muaalem-model-v3_2'

            def run(w):
                f = m.processor([w], sampling_rate=16000, return_tensors='pt')
                with torch.no_grad():
                    return F.log_softmax(m.model(**f, return_dict=False)[0]['phonemes'][0], -1).numpy()
        else:
            import onnxruntime as ort
            path = spec.split(':', 1)[1]
            s = ort.InferenceSession(path)
            self.id = os.path.basename(path)

            def run(w):
                return s.run(None, {'waveform': w[None].astype(np.float32)})[0][0]
        self._run = run

    def frames(self, w):
        with self.lock:
            if len(w) <= CHUNK:
                return self._run(w)
            parts, start = [], 0
            while True:
                lp = self._run(w[start:start + CHUNK])
                end = start + CHUNK >= len(w)
                first = 0 if start == 0 else (OVERLAP // 2) // HOP
                last = len(lp) if end else len(lp) - (OVERLAP // 2) // HOP
                parts.append(lp[first:last])
                if end:
                    return np.concatenate(parts)
                start += CHUNK - OVERLAP


def handler(model):
    class H(BaseHTTPRequestHandler):
        def _cors(self):
            self.send_header('Access-Control-Allow-Origin', '*')
            self.send_header('Access-Control-Allow-Methods', 'GET, POST, OPTIONS')
            self.send_header('Access-Control-Allow-Headers', 'Content-Type')
            self.send_header('Access-Control-Expose-Headers', 'X-Frames, X-Classes, X-Model-Ms')

        def do_OPTIONS(self):
            self.send_response(204)
            self._cors()
            self.end_headers()

        def do_GET(self):
            if self.path != '/v1/info':
                self.send_error(404)
                return
            body = json.dumps(dict(model=model.id, vocabulary=VOCAB, sampleRate=16000,
                                   frameMs=40), ensure_ascii=False).encode()
            self.send_response(200)
            self._cors()
            self.send_header('Content-Type', 'application/json; charset=utf-8')
            self.send_header('Content-Length', str(len(body)))
            self.end_headers()
            self.wfile.write(body)

        def do_POST(self):
            if self.path != '/v1/frames':
                self.send_error(404)
                return
            n = int(self.headers.get('Content-Length', 0))
            if n < 2 * 16000 // 4 or n > 2 * 16000 * 120:
                self.send_error(400, 'audio must be 0.25 s to 120 s of PCM16LE 16 kHz mono')
                return
            pcm = np.frombuffer(self.rfile.read(n), dtype='<i2').astype(np.float32) / 32768.0
            t = time.time()
            lp = model.frames(pcm).astype('<f4')
            ms = int((time.time() - t) * 1000)
            body = lp.tobytes()
            self.send_response(200)
            self._cors()
            self.send_header('Content-Type', 'application/octet-stream')
            self.send_header('Content-Length', str(len(body)))
            self.send_header('X-Frames', str(lp.shape[0]))
            self.send_header('X-Classes', str(lp.shape[1]))
            self.send_header('X-Model-Ms', str(ms))
            self.end_headers()
            self.wfile.write(body)
            print(f'{len(pcm) / 16000:5.1f} s audio -> {lp.shape[0]} frames in {ms} ms', flush=True)

        def log_message(self, *a):
            pass
    return H


def main():
    p = argparse.ArgumentParser()
    p.add_argument('--port', type=int, default=8790)
    p.add_argument('--host', default='127.0.0.1')
    p.add_argument('--model', default='teacher')
    a = p.parse_args()
    import socket
    probe = socket.socket()
    try:
        probe.bind((a.host, a.port))
    except OSError:
        sys.exit(f'Port {a.port} is already in use — is the server already running? '
                 f'Stop it, or use --port.')
    finally:
        probe.close()
    model = Model(a.model)
    model.frames(np.zeros(16000, np.float32))  # warm up
    print(f'acoustic server: {model.id} on http://{a.host}:{a.port}', flush=True)
    ThreadingHTTPServer((a.host, a.port), handler(model)).serve_forever()


if __name__ == '__main__':
    main()
