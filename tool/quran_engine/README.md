# Quran Engine — vendoring tools

Used by `feature/quran-engine-migration` (originally written for the
evaluation on `poc/quran-engine`, see `docs/poc/QURAN_ENGINE_POC.md` for
that history). Nothing here runs at app runtime — these are offline
dev-tooling scripts, mirroring `tool/quran_data/`'s own conventions.

Pinned upstream:

- Engine source: `https://github.com/quran-ws/quran-engine`
  commit `a19ee9b16ec60689dfd9ef566c49d393f9a47459` (2026-09-11)
- Page-data release: `https://cdn.quran.ws/qvp/v0.3.0/` (`manifest.json`),
  release `quran-engine-pages-hafs-kfgqpc` v0.3.0, generated 2026-09-15,
  itself pinned to engine commit `55d732a4e98e976948014c6dd979e0d6cf94ee8b`
  (a different, later commit than the code commit above — the data release
  and the code repo version independently; both are recorded here exactly
  as fetched, not reconciled to a single number).

## Scripts

- `fetch_web_runtime.sh` — builds `qvp_ffi.wasm` from the pinned Rust source
  (`cargo build -p qvp-ffi --release --target wasm32-unknown-unknown`) and
  copies it alongside the pinned `web/qvp.js` into `web/quran_engine/`.
  Requires a Rust toolchain with the `wasm32-unknown-unknown` target
  (`rustup target add wasm32-unknown-unknown`).
- `fetch_page_data.sh` — downloads page data from the pinned data release,
  verifying each file's SHA-256 against the release's own `manifest.json`
  before writing it to `assets/quran/quran_engine/pages/`. Refuses to
  write any file that fails verification. Defaults to six representative
  pages (1, 2, 42, 106, 302, 604) plus `atlas.qva`; `--all` fetches the
  full 604-page corpus. **The full corpus is what Tahfeez ships** — see
  "Asset gating" below.

Both scripts are idempotent and never touch the production QPC V2
assets/renderer.

## Why vendored, not fetched live from cdn.quran.ws at build/run time

Vendoring with recorded hashes keeps a clear paper trail of exactly which
bytes were evaluated/integrated (see `docs/QURAN_ENGINE_MIGRATION.md`'s
licensing section), and avoids the app silently depending on Quran.ws's
own CDN infrastructure at runtime — a separate decision from evaluating
the engine itself, not something to fall into by default.

## Asset gating

**Unlike every other KFGQPC-derived Mushaf resource in this codebase**,
`assets/quran/quran_engine/pages/` (the full 604-page corpus) is declared
in `pubspec.yaml` for every build, including release, and is bundled on
both Android and Web with no `kReleaseMode` refusal — Quran Engine is
Tahfeez's production Mushaf rendering backend
(`docs/QURAN_ENGINE_MIGRATION.md`), and rendering Mushaf pages at all
requires this corpus. This corpus's public redistribution status is
exactly as unresolved as QPC V2's was; shipping it anyway in real release
builds was a deliberate product decision, made only after the specific
risk was explained and explicitly accepted — see
`docs/QURAN_ENGINE_MIGRATION.md`'s licensing section and
`docs/THIRD_PARTY_RESOURCES.md` for the full record. That decision does
not resolve the underlying provenance question; it only changes whether
the app ships the bytes while that question stays open.
