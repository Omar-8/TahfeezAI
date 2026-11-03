// The Quran acoustic model in the browser: ONNX Runtime Web (WebAssembly,
// SIMD; threads where the page is cross-origin isolated), in this worker so
// the page never waits on it. What the phones' QuranAcousticModelChannel
// does, answering the same calls (web_acoustic_channel.dart forwards them):
// status, load, run, streamReset, streamRun, unload.
//
// The model (assets/models/quran_acoustic.onnx, 91 MB) is fetched once and
// kept in Cache Storage, checked against its manifest's SHA-256 when it
// arrives; later loads read it from there, offline too.
import * as ort from './ort/ort.wasm.min.mjs';

const MODEL = '../assets/assets/models/quran_acoustic.onnx';
const MANIFEST = '../assets/assets/models/quran_acoustic.json';
const CACHE = 'tahfeez-acoustic-model';

ort.env.wasm.wasmPaths = new URL('./ort/', import.meta.url).href;
ort.env.logLevel = 'error';

let manifest = null;
let session = null;
let stream = null; // [{name, dims, data, initial}]
let loading = null;

async function readManifest() {
  if (!manifest) {
    const response = await fetch(MANIFEST);
    if (!response.ok) throw new Error(`No manifest (${response.status})`);
    manifest = await response.text();
  }
  return manifest;
}

function simd() {
  // (v128.const and a SIMD op: SIMD is all ONNX Runtime Web ships now.)
  return WebAssembly.validate(new Uint8Array([0, 97, 115, 109, 1, 0, 0, 0, 1,
    5, 1, 96, 0, 1, 123, 3, 2, 1, 0, 10, 10, 1, 8, 0, 65, 0, 253, 15, 253,
    98, 11]));
}

async function status() {
  if (!simd()) {
    return { state: 'unsupported', detail: 'this browser has no WebAssembly SIMD' };
  }
  let text;
  try {
    text = await readManifest();
  } catch (e) {
    return { state: 'absent', searched: [MANIFEST] };
  }
  const bytes = JSON.parse(text).bytes;
  return {
    state: session ? 'loaded' : 'present',
    path: MODEL,
    bytes,
    manifest: text,
    provider: session ? 'cpu' : null,
  };
}

async function hex(buffer) {
  const digest = await crypto.subtle.digest('SHA-256', buffer);
  return [...new Uint8Array(digest)].map((b) => b.toString(16).padStart(2, '0')).join('');
}

// The model's bytes: from Cache Storage, else fetched (reporting progress),
// verified and kept.
async function modelBytes(expected, size, progress) {
  // Kept in Cache Storage where the browser allows it — not at all (a
  // private window, a full disk) is no reason not to run it.
  let cache = null;
  try {
    cache = await caches.open(CACHE);
  } catch (e) {
    cache = null;
  }
  const key = `${MODEL}?sha256=${expected}`;
  try {
    const cached = cache && await cache.match(key);
    if (cached) return { bytes: await cached.arrayBuffer(), downloaded: false };
    // Earlier versions' copies (and a part kept from a full disk).
    if (cache) for (const old of await cache.keys()) await cache.delete(old);
  } catch (e) {
    // A copy that cannot be read: downloaded again.
  }
  const response = await fetch(MODEL, { cache: 'no-store' });
  if (!response.ok) throw new Error(`Model download failed (${response.status})`);
  const reader = response.body.getReader();
  const bytes = new Uint8Array(size);
  let at = 0;
  let reported = 0;
  for (;;) {
    const { done, value } = await reader.read();
    if (done) break;
    if (at + value.length > size) throw new Error('Model larger than its manifest says');
    bytes.set(value, at);
    at += value.length;
    if (at - reported > size / 100) {
      reported = at;
      progress(at / size);
    }
  }
  if (at !== size) throw new Error(`Model is ${at} bytes, manifest says ${size}`);
  const hash = await hex(bytes.buffer);
  if (hash !== expected) throw new Error(`Model SHA-256 ${hash} does not match the manifest`);
  try {
    if (cache) {
      await cache.put(key, new Response(bytes, {
        headers: { 'Content-Type': 'application/octet-stream' },
      }));
    }
  } catch (e) {
    // No room to keep it (QuotaExceededError): used from memory this time,
    // downloaded again next time.
  }
  return { bytes: bytes.buffer, downloaded: true };
}

const ORDER = ['sums', 'count', 'kv', 'conv', 'akv', 'aconv', 'valid'];

function flat(value, out = []) {
  if (Array.isArray(value)) for (const v of value) flat(v, out);
  else out.push(value);
  return out;
}

function streamSlots(config) {
  const names = Object.keys(config.state).sort((a, b) => {
    const i = ORDER.indexOf(a) < 0 ? 99 : ORDER.indexOf(a);
    const j = ORDER.indexOf(b) < 0 ? 99 : ORDER.indexOf(b);
    return i - j;
  });
  return names.map((name) => {
    const dims = config.state[name];
    const size = dims.reduce((n, d) => n * d, 1);
    const initial = config.initial && config.initial[name]
      ? Float32Array.from(flat(config.initial[name])) : null;
    return { name, dims, data: new Float32Array(size), initial };
  });
}

function streamReset() {
  if (!stream) throw new Error('Not a streaming model');
  for (const slot of stream) {
    if (slot.initial) slot.data.set(slot.initial);
    else slot.data.fill(0);
  }
}

async function load(progress) {
  if (session) return { provider: 'cpu', loadMs: 0, cached: true };
  const started = performance.now();
  const config = JSON.parse(await readManifest());
  const { bytes, downloaded } = await modelBytes(config.sha256.toLowerCase(), config.bytes, progress);
  const sessionStarted = performance.now();
  const threads = self.crossOriginIsolated
    ? Math.max(1, Math.min(4, (navigator.hardwareConcurrency || 2) - 1)) : 1;
  ort.env.wasm.numThreads = threads;
  session = await ort.InferenceSession.create(new Uint8Array(bytes), {
    executionProviders: ['wasm'],
    graphOptimizationLevel: 'all',
  });
  if (config.stream) {
    stream = streamSlots(config.stream);
    streamReset();
  }
  const now = performance.now();
  return {
    provider: 'cpu',
    loadMs: Math.round(now - started),
    sessionMs: Math.round(now - sessionStarted),
    downloaded,
    threads,
    inputs: session.inputNames,
    outputs: session.outputNames,
  };
}

function frames(tensor, started) {
  const [, frameCount, classes] = tensor.dims;
  const ms = Math.round(performance.now() - started);
  return { frames: frameCount, classes, logProbs: tensor.data, ms, cpuMs: ms };
}

async function run(samples) {
  if (!session) throw new Error('Acoustic model not loaded');
  const started = performance.now();
  const input = new ort.Tensor('float32', samples, [1, samples.length]);
  const out = await session.run({ [session.inputNames[0]]: input });
  return frames(out[session.outputNames[0]], started);
}

async function streamRun(samples, commit) {
  if (!session) throw new Error('Acoustic model not loaded');
  if (!stream) throw new Error('Not a streaming model');
  const started = performance.now();
  const feeds = { samples: new ort.Tensor('float32', samples, [1, samples.length]) };
  for (const slot of stream) feeds[slot.name] = new ort.Tensor('float32', slot.data, slot.dims);
  const out = await session.run(feeds);
  if (commit) {
    for (const slot of stream) slot.data.set(out[`${slot.name}_out`].data);
  }
  return frames(out.log_probs, started);
}

async function unload() {
  if (session) await session.release();
  session = null;
  stream = null;
}

// One call at a time, in order (a stream's chunks depend on each other).
let queue = Promise.resolve();

self.onmessage = (event) => {
  const { id, method, args } = event.data;
  queue = queue.then(async () => {
    try {
      let result;
      switch (method) {
        case 'status': result = await status(); break;
        case 'load':
          loading ??= load((fraction) => self.postMessage({ progress: fraction }));
          try { result = await loading; } finally { loading = null; }
          break;
        case 'run': result = await run(args.samples); break;
        case 'streamReset': streamReset(); result = null; break;
        case 'streamRun': result = await streamRun(args.samples, args.commit !== false); break;
        case 'unload': await unload(); result = null; break;
        case 'resetGuard': result = null; break;
        // (The phones report memory and battery; nothing to report here.)
        case 'stats': result = null; break;
        default: throw new Error(`Unknown method ${method}`);
      }
      const transfer = result && result.logProbs ? [result.logProbs.buffer] : [];
      self.postMessage({ id, result }, transfer);
    } catch (e) {
      self.postMessage({ id, error: `${e && e.message ? e.message : e}` });
    }
  });
};
