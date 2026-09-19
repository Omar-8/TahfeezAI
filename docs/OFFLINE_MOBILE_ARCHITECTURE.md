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
- **Mushaf** (dev/debug builds only, see below): a missing or hash-mismatched Mushaf
  asset is logged and skipped; canonical Quran/translations/tafsir seeding is
  unaffected either way, and the Mushaf reader shows an honest "pending" state rather
  than corrupted or approximate content.

## 4. What ships where, and the Mushaf/font exception

| Resource | Bundled in every build? | Notes |
|---|---|---|
| Canonical Quran (Tanzil) | Yes | License-cleared, `docs/QURAN_DATA_PROVENANCE.md` §1-2 |
| Translations (EN/DE Rowwad) | Yes | License-cleared, §3-4 |
| Tafsir (Al-Muyassar) | Yes | License-cleared, §5 |
| Mushaf line/token data | Dev/debug builds only | `SHIP_BLOCKED_LICENSE`, §7/§7a — see below |
| QPC V2 page fonts (604 files) | Dev/debug builds only | `SHIP_BLOCKED_LICENSE`, §8 — see below |

The Mushaf dataset and font package are declared as ordinary Flutter assets (required
for `rootBundle` to serve them to a local/debug build at all) but `BundledDatasetSeeder`
and `qpcPageFontManifestProvider` both refuse to import/load them when `kReleaseMode` is
true — the *app's own code* never displays this content in a release build. This is a
Dart-level runtime refusal, not a build-time asset exclusion: a real
`flutter build appbundle --release` performed during this work still produced a
204.9MB AAB containing the full font package and Mushaf dataset, because Flutter's
asset system has no built-in per-build-type exclusion without a product-flavor setup
(not implemented here — see `docs/QURAN_DATA_PROVENANCE.md`'s release checklist). A real
public release must resolve the redistribution question or remove/flavor-gate those
three `pubspec.yaml` asset lines before shipping.

## 5. Measured app size impact (this environment)

- Debug APK: 318MB (includes the ~200MB font package + ~26MB Mushaf dataset, both
  present because this is a debug build).
- Release AAB: 204.9MB (same gated assets are still physically present, per §4's
  caveat — the `kReleaseMode` gate stops the app from *using* them, not the build from
  *including* them).
- These numbers were **not** measured on a physical device; only `flutter build`'s own
  output size on this Linux sandbox. Play Store/App Store post-processing (further
  compression, per-device APK splitting) was not exercised.

## 6. Web

Web has no hard offline requirement (`docs/PROJECT_BRIEF.md`). The same
`BundledDatasetSeeder`/repository interfaces are used — no separate web-specific data
path exists — so web behavior is identical in kind, just without the same offline
guarantee if a resource is missing.

## 7. Future optimization path (not implemented)

If the ~130-200MB font package proves too large for a real release once licensing
clears, the natural next step is Android Play Asset Delivery (an on-demand asset pack,
fetched once and cached, near-zero base-install impact) and iOS On-Demand Resources
(the equivalent Apple mechanism) — both are official, first-party mechanisms built for
exactly this "large optional binary content, offline after one deliberate fetch" case.
Neither was implemented in this work, per explicit instruction to present the
packaging comparison before building anything more complex than lazy `FontLoader`
registration — see `docs/QURAN_DATA_PROVENANCE.md` §8's font-packaging comparison.
