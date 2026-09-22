# Tahfeez AI — Offline Mobile Architecture

How Tahfeez's bundled data reaches a local, queryable database on Android/iOS with no
network call, and what that costs in startup time and package size. See
`docs/PROJECT_BRIEF.md`'s "Offline requirement" for the product-level guarantee this
architecture exists to satisfy, and `docs/QURAN_DATA_PROVENANCE.md` for what each
resource actually is and its license status.

## 1. Startup flow

```
launch
  ↓
WidgetsFlutterBinding.ensureInitialized()
  ↓
BundledDatasetSeeder.seedIfNeeded()   (before runApp — see lib/app/bootstrap.dart)
  ↓
open local Drift/SQLite databases (QuranDatabase, TranslationDatabase, TafsirDatabase)
  ↓
runApp
```

This is a boot-time gate, not a lazy per-screen fetch: by the time the first frame
renders, the local databases are already open and (on a normal, non-first launch)
already contain everything they need — never "download Quran → wait → reader."

## 2. Avoiding a full JSON parse on every launch

The canonical Quran dataset (`assets/quran/quran_dataset.json`, ~9.9MB) and, in
dev/debug builds, the Mushaf dataset (`assets/quran/mushaf/kfgqpc_v2.json`, ~26MB) are
large enough that re-parsing them on *every* launch — even when nothing changed — would
be a real, measurable cost. `BundledDatasetSeeder` avoids this with a cheap-first check:

1. Read only `assets/quran/resource_manifest.json` (a few KB) — never the large files —
   to get each resource's current content hash.
2. Compare against a small marker string persisted in `BrowserStorage` (backed by
   `shared_preferences`) from the last successful import, plus a cheap DB read
   (`QuranRepository.getDatasetMetadata()`, a single-row query).
3. Only a mismatch (first launch, or the bundled dataset actually changed) triggers
   loading and parsing the large file(s) and running the import.

A normal subsequent launch therefore does: one small JSON parse (the manifest) plus a
handful of cheap key-value/single-row reads — never a multi-megabyte JSON parse. Once
imported, the *local SQLite database* is the trusted store; its own integrity does not
need re-verifying against the bundled asset on every single boot, only re-importing when
the bundled asset's own recorded version actually changes.

## 3. Failure isolation

Each seeded resource fails independently, matching `docs/PROJECT_BRIEF.md`'s
Quran-correctness priorities:

- **Canonical Quran**: a hash mismatch or integrity-validation failure is logged as
  critical and the import is skipped entirely — `QuranDatasetImporter` guarantees an
  all-or-nothing transaction, so a failure here can never leave a half-imported,
  partially-corrupt Quran on disk. An empty `QuranDatabase` (already a handled,
  pre-existing state throughout the reader/Mushaf/search UI) is always the safe
  fallback.
- **Each translation/tafsir**: fails independently — a broken German translation file
  never prevents the English translation, the tafsir, or the canonical Quran from
  seeding.
- **Mushaf line/token data** (dev/debug builds only, see below): a missing or
  hash-mismatched Mushaf asset is logged and skipped; canonical Quran/translations/tafsir
  seeding is unaffected either way. **Mushaf page rendering itself** no longer depends on
  this dataset (`docs/QURAN_ENGINE_MIGRATION.md`) — it comes from the Quran Engine page
  corpus (§4), which is bundled unconditionally, so the Mushaf reader no longer shows a
  "pending" state for missing page content the way it once did when the QPC V2 renderer
  depended on this same gated dataset.

## 4. What ships where — including one deliberate exception

| Resource | Bundled in every build? | Notes |
|---|---|---|
| Canonical Quran (Tanzil) | Yes | License-cleared, `docs/QURAN_DATA_PROVENANCE.md` §1-2 |
| Translations (EN/DE Rowwad) | Yes | License-cleared, §3-4 |
| Tafsir (Al-Muyassar) | Yes | License-cleared, §5 |
| Mushaf line/token structural data (`kfgqpc_v2.json`) | Dev/debug builds only | `SHIP_BLOCKED_LICENSE`, §7/§7a — still gated, unrelated to which engine renders Mushaf pages |
| **Quran Engine Mushaf page corpus** | **Yes — every build, including release** | `SHIP_BLOCKED_LICENSE`, still unresolved — shipped anyway by explicit product-owner decision; see below |
| *(QPC V2 page fonts, 604 files — historical)* | *(Removed)* | The renderer that used this font was deleted; no longer declared in `pubspec.yaml` at all (`docs/QURAN_ENGINE_MIGRATION.md`) |

**The Quran Engine page corpus is a deliberate exception to this file's otherwise
-consistent "`SHIP_BLOCKED_LICENSE` means dev/debug only" pattern.** Unlike the Mushaf
structural dataset above (still gated, `BundledDatasetSeeder` still refuses it at
`kReleaseMode`), the Quran Engine backend (`QuranEngineAndroidBackend`,
`QuranEngineWebBackend`) has no such refusal — Quran Engine is Tahfeez's only Mushaf
rendering backend, and rendering Mushaf pages at all requires this corpus. This was an
explicit, informed decision — the product owner was told concretely what removing the
gate meant (real release builds bundling and displaying KFGQPC-derived material without
cleared redistribution rights) and explicitly accepted that risk. It does not resolve
the redistribution question; it changes only whether Tahfeez ships the bytes while that
question stays open. Full record: `docs/QURAN_ENGINE_MIGRATION.md` §10;
resource-register entry: `docs/THIRD_PARTY_RESOURCES.md`.

## 5. Measured app size impact (this environment)

- Release APK: 116.7MB.
- Release AAB: 115.5MB.
- Release Web build: 180MB (`flutter build web --release`).
- All three include the full 604-page Quran Engine corpus (91MB on Android,
  ~91MB of the Web bundle) — bundled deliberately, not a gating failure (§4). The
  Mushaf structural dataset and every former QPC V2 asset are absent from these numbers,
  since none of them are declared in `pubspec.yaml` for a release build.
- These numbers were **not** measured on a physical device; only `flutter build`'s own
  output size on this Linux sandbox. Play Store/App Store post-processing (further
  compression, per-device APK splitting) was not exercised.

## 6. Web

Web has no hard offline requirement (`docs/PROJECT_BRIEF.md`). The same
`BundledDatasetSeeder`/repository interfaces are used — no separate web-specific data
path exists — so web behavior is identical in kind, just without the same offline
guarantee if a resource is missing. Unlike every other gated Mushaf resource, the Quran
Engine page corpus is now bundled into the Web build too (§4) — Web Mushaf rendering
"just works" from the same-origin bundled assets, with no separate hosting/CDN required
and no configuration.

## 7. Future optimization path (not implemented)

If the Quran Engine page corpus (91MB) or a future licensed replacement proves too large
for a real release, the natural next step is Android Play Asset Delivery (an on-demand
asset pack, fetched once and cached, near-zero base-install impact) and iOS On-Demand
Resources (the equivalent Apple mechanism) — both are official, first-party mechanisms
built for exactly this "large optional binary content, offline after one deliberate
fetch" case. Neither was implemented in this work. See
`docs/QURAN_DATA_PROVENANCE.md` §8's font-packaging comparison for the same reasoning
originally applied to the QPC V2 font package this corpus replaced.
