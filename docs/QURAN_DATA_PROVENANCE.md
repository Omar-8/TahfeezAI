# TahfeezAI — Quran Data Provenance

This document records, per resource, exactly which upstream source Tahfeez's bundled
production Quran dataset comes from, its edition/version, its content hash, its
license/redistribution terms, and its current shipping status. It supersedes the
"planning only" status of `docs/DATA_RESOURCE_REQUIREMENTS.md` for the resources listed
below — those resources are now integrated, not just researched. `docs/DATA_RESOURCE_REQUIREMENTS.md`
itself has been updated to point here.

Per `docs/CLEAN_ROOM_RULES.md` and `CLAUDE.md`'s Quran-correctness rules: every resource
below is source-verified, none is AI-generated, canonical Quran text is never silently
edited, and normalized search text is kept structurally separate from canonical display
text (`lib/quran/domain/search_normalizer.dart`).

This dataset is built by `tool/quran_data/build_production_data.dart`, from sources
fetched by `tool/quran_data/fetch_sources.dart` plus the manually-vendored QUL layout file
at `tool/quran_data/sources/qpc-v2-15-lines.db.zip`. Re-running the build tool against the
same source snapshots reproduces byte-identical output — see "Reproducing this dataset"
at the end of this document.

---

## 1. Canonical Arabic Quran text — Tanzil Project

- **Source**: [tanzil.net](https://tanzil.net), the Tanzil Project's Uthmani text export.
- **Edition/version**: Uthmani, Version 1.1.
- **Downloaded from**: `https://tanzil.net/pub/download/index.php` (`quranType=uthmani`,
  `outType=txt-2`, `tatweel=true`, `marks=false`, `sajdah=false`, `rub=false`).
- **Content hash (SHA-256)**: `bf4f57b968d03f4131c070b1e285da9be0e0a108a21c910e872801ca273312c8`
- **License**: Tanzil's own text license (a CC-BY-3.0-style license). Verbatim copying is
  explicitly permitted with attribution; modification is explicitly forbidden ("CHANGING
  IT IS NOT ALLOWED"). Source: <https://tanzil.net/docs/text_license>.
- **Attribution required**: "This Quran text can be used in any website or application,
  provided that its source (Tanzil Project) is clearly indicated, and a link is made to
  tanzil.net."
- **Redistribution**: explicitly permitted for offline bundling in an application.
- **Modification**: **forbidden** — Tahfeez only ever performs one, documented,
  non-destructive transformation (see "Bismillah handling" below), never a content edit.
- **Maps to**: `Surahs`/`Ayahs`/`AyahWords` (script `tanzil_uthmani`, id 1) in
  `QuranDatabase`.
- **Status**: **integrated**. Bundled at `assets/quran/quran_dataset.json`.

### Bismillah handling (a documented parsing rule, not a text edit)

Tanzil's plain-text export prepends the Bismillah ("بِسْمِ اللَّهِ الرَّحْمَٰنِ
الرَّحِيمِ") to the *displayed* text of every surah's first ayah except At-Tawbah (surah
9) — a presentational convention of the export format, not part of that ayah's actual,
numbered verse content. For Al-Fatiha (surah 1), the Bismillah genuinely *is* verse 1.
For every other surah, Tahfeez's import tooling
(`tool/quran_data/src/tanzil_source.dart`) strips the leading four whitespace-delimited
tokens (the Bismillah's own word count, verified against all 114 surahs including two
orthographic variants at surah 95 and 97 that use a shadda on the first letter) from
ayah 1's word list before storing it, so:

- word counts and word indices match the verse's actual, traditionally-recognized content
  (e.g. Al-Baqarah 2:1 is stored as the single word "الٓمٓ", not five words);
- word indices stay compatible with a real Mushaf word dataset once one is available,
  since Mushaf layouts (including QUL's, §4 below) render the Bismillah as its own
  `basmallah` line, never as part of ayah 1's word range;
- **no character of the canonical text itself is altered or removed** — the Bismillah
  words are simply not double-counted as part of a different verse's content, exactly the
  same way a printed Mushaf visually separates them.

This rule, and the verification that it holds for every affected surah, is covered by
`test/quran_data/bundled_dataset_integrity_test.dart`.

## 2. Surah metadata, localized names, and structural navigation data — Tanzil Project

- **Source**: Tanzil's `quran-data.xml` metadata file.
- **Downloaded from**: `https://tanzil.net/res/text/metadata/quran-data.xml`.
- **Content hash (SHA-256)**: `8867c1d88191472adec9db694b3cd9f135b1a2ef580574d32cf888dcb22c5c7a`
- **License**: `cc-by` per the file's own `<quran ... license="cc-by">` root attribute;
  copyright "(C) 2008-2009 Tanzil.info".
- **Provides**: 114 Surahs (Arabic name, transliterated name, English meaning, revelation
  type/order, Ruku count, ayah count); 30 Juz, 60 Hizb, 240 Rub (quarter-Hizb), 7 Manzil,
  556 Ruku boundaries; 604 canonical page boundaries (Tanzil's own pagination, distinct
  from — and not used as — the Mushaf pagination in §4); 15 Sajdah verses.
- **Maps to**: `SurahLocalizations` (`ar` and `en` rows per surah), `Ayahs.juzNo/hizbNo/
  rubNo/manzilNo/rukuNo/sajdah`, `NavigationRanges` (juz/hizb/rub/manzil).
- **Derivation note**: Tanzil's `<hizbs>` element actually lists all 240 quarter-Hizb
  (Rub) boundaries; Tahfeez derives the 60 Hizb boundaries as every 4th entry, and uses
  the dedicated `<juzs>` element (not a derived value) for the 30 Juz boundaries. Every
  ayah's unit number is assigned by finding the latest boundary at or before it — verified
  against known chapter/unit counts in `test/quran_data/bundled_dataset_integrity_test.dart`.
- **Rukūʿ as thematic passages**: Mushaf appearance → "Colour thematic passages" tints
  each rukūʿ (`Ayahs.rukuNo`) in its own colour, never the same as its neighbour's
  (`lib/features/mushaf/application/mushaf_passages.dart`). No titles or other data added.
- **Sajdah**: the 15 `<sajda>` verses are also kept as a constant (`sajdahAyahs`,
  `lib/features/recitation/application/sajdah_reminder.dart`) for the Sujood al-Tilawah
  reminder after reciting one; checked equal to the file on 2026-10-10. (The bundled
  dataset's `Ayahs.sajdah` column is currently empty.)
- **Status**: **integrated**.

## 3. English translation — QuranEnc (Rowwad Translation Center)

- **Source**: [QuranEnc.com](https://quranenc.com), resource key `english_rwwad`.
- **Title**: "English Translation - Rowwad Translation Center", in cooperation with the
  Rabwah Dawah Association, the Islamic Content Service Association in Languages, and
  IslamHouse.com.
- **Version**: 1.0.19 (per QuranEnc's `/api/v1/translations/list` at integration time).
- **Downloaded from**: `https://quranenc.com/downloads/sqlite/english_rwwad.zip`.
- **Content hash (SHA-256, of the extracted `.sqlite` file)**:
  `77e2ede3d8e6d6b5c6e16ff78eda2d2b6cc0a6b7489c94a5dde4f7481f5fdee8`
- **Tahfeez identifiers**: `slug` `en-rowwad`; branding resource id
  `tahfeez.translation.en.rowwad`.
- **License**: QuranEnc's Terms and Policies (see §5 for the full text) — redistribution
  is permitted with attribution, no modification, version number retained, and update
  obligations. Never a generic "Quran data" license entry; recorded individually here and
  in `docs/THIRD_PARTY_RESOURCES.md`.
- **Footnotes**: modeled as separate structured `TranslationFootnote(marker, text)`
  entries, parsed from QuranEnc's `[n] text` footnote blob format — never permanently
  concatenated into the translation body. The visible translation text keeps its inline
  `[n]` markers exactly as QuranEnc provides them (the reader's footnote tap-to-reveal UI,
  `lib/quran/presentation/translation_block.dart`, depends on them being present).
- **Maps to**: `TranslationDatabase` via `TranslationRepository.installTranslation`.
- **Status**: **integrated**. Bundled at `assets/quran/translations/en_rowwad.json`.

## 4. German translation — QuranEnc (Rowwad Translation Center)

- **Source**: QuranEnc.com, resource key `german_rwwad`.
- **Version**: 1.0.15 (per QuranEnc's `/api/v1/translations/list` at integration time).
- **Downloaded from**: `https://quranenc.com/downloads/sqlite/german_rwwad.zip`.
- **Content hash (SHA-256)**: `32c6a6e0e45b4ece65f3b85094fa6f4c0a9b9bdc5c94a7933e8fe711efb5125e`
- **Tahfeez identifiers**: `slug` `de-rowwad`; branding resource id
  `tahfeez.translation.de.rowwad`.
- **License**: same QuranEnc Terms and Policies as §3.
- **Status**: **integrated**. Bundled at `assets/quran/translations/de_rowwad.json`.

## 5. Tafsir Al-Muyassar (Arabic) — QuranEnc

- **Source**: QuranEnc.com, resource key `arabic_moyassar`.
- **Title**: التفسير الميسر (At-Tafsir Al-Muyassar), compiled under the supervision of the
  King Fahd Complex for the Printing of the Holy Quran.
- **Downloaded from**: `https://quranenc.com/downloads/sqlite/arabic_moyassar.zip`.
- **Content hash (SHA-256)**: `eb384e586487b089b826375d3f705d07e775e0019325da405e0337a9f6b3da04`
- **Version**: QuranEnc publishes **no version number** for this resource via its public
  API (it is not listed under `/api/v1/translations/list` or `/api/v1/tafsirs/list`, only
  reachable via its direct download URL and its own browse page, neither of which display
  a version). Tahfeez does not fabricate one; it tracks this resource by content hash
  alone and records `version: "unversioned upstream..."` in the resource manifest,
  honestly reflecting what QuranEnc actually publishes.
- **Tahfeez identifiers**: `id` `ar-muyassar`; branding resource id
  `tahfeez.tafsir.ar.muyassar`.
- **License**: QuranEnc's Terms and Policies (§6 below applies to tafsir content too, per
  QuranEnc's own site-wide terms).
- **Never treated as canonical Quran text**: stored exclusively via
  `TafsirRepository`/`TafsirDatabase`, joined to canonical ayahs by `(chapterNo, verseNo)`,
  never merged into `AyahWords`.
- **Status**: **integrated**. Bundled at `assets/quran/tafsir/ar_muyassar.json`.

## 6. QuranEnc Terms and Policies (applies to §3–§5)

Extracted directly from QuranEnc's own in-page terms modal (`#terms_modal` on
<https://quranenc.com/en/home> — not a separate URL) at integration time:

> Contents of the translations can be downloaded and re-published, with the following
> terms and conditions:
> 1. No modification, addition, or deletion of the content.
> 2. Clearly referring to the publisher and the source (QuranEnc.com).
> 3. Mentioning the version number when re-publishing the translation.
> 4. Keeping the transcript information inside the document.
> 5. Notifying the source (QuranEnc.com) of any note on the translation.
> 6. Updating the translation according to the latest version issued from the source
>    (QuranEnc.com).
> 7. Inappropriate advertisements must not be included when displaying translations of
>    the meanings of the Noble Quran.

Tahfeez satisfies these by: never modifying verse text or footnotes (only presentation
formatting may change, per `CLAUDE.md`); recording "QuranEnc.com" as `source` on every
`TranslationBook`/`TafsirWork`; recording the version where QuranEnc publishes one;
keeping this provenance document and `docs/THIRD_PARTY_RESOURCES.md` up to date; and
re-running `tool/quran_data/build_production_data.dart` against freshly fetched sources
whenever a resource needs updating (obligation 6).

## 7. Mushaf page/line layout — QUL KFGQPC V2 (Madinah Mushaf, 1421H print)

- **Source**: QUL — Quranic Universal Library (qul.tarteel.ai / Tarteel AI / Digital
  Khadeeja Foundation).
- **Edition**: KFGQPC V2, the 1421H-print Madinah Mushaf layout, Hafs 'an Asim, 604 pages,
  15 lines per page.
- **File**: `qpc-v2-15-lines.db`, manually provided by the project owner and vendored at
  `tool/quran_data/sources/qpc-v2-15-lines.db.zip`.
- **Content hash (SHA-256, of the extracted `.db` file)**:
  `e4df98f35dd3b8927ff096337c8739e0f0b12c8ba622834c345eaa4c3e28dd8c`
- **Why this file is vendored rather than fetched by tooling**: QUL gates this download
  behind a required user login (`data-url="/users/sign_in?..."` on its own download
  buttons) and, per QUL's own documentation, exposes no public API ("coming soon") as of
  integration time. `tool/quran_data/fetch_sources.dart` therefore cannot fetch it
  automatically; a developer recreating this dataset must obtain the file manually from
  QUL and place it at the path above before running
  `tool/quran_data/build_production_data.dart`.
- **Verified structure** (via `tool/quran_data/src/mushaf_layout_source.dart`, checked
  continuously by `test/quran_data/qul_layout_source_test.dart` against the real vendored
  file): `info` table declares `'QCF V2 ( 1421H print )'`, 604 pages, 15 lines/page;
  `pages` table has exactly 9,046 rows — 114 `surah_name` header lines, 112 `basmallah`
  lines (every surah except Al-Fatiha and At-Tawbah), and 8,820 `ayah` text lines; every
  page's line numbers are contiguous starting at 1 (pages 1–2 have 8 lines each, every
  other page has 15).
- **The companion word/script dataset — now supplied and verified compatible**: this
  file's `ayah` lines carry bare integer `first_word_id`/`last_word_id` references into a
  *separate* QUL "Quran script/word database" resource that resolves each id to its
  actual surah/ayah/word-position and glyph text. The project owner obtained this
  resource (§7a below) and a full read-only compatibility audit (604 pages, every word-id
  reference, global monotonicity, per-ayah word counts cross-checked against the
  canonical Tanzil dataset) confirmed the two files are genuinely built from the same
  underlying word sequence. See §7a for the resource itself and §7b for what that audit
  found.
- **Production import — complete**: `tool/quran_data/src/mushaf_import.dart` combines
  this layout with §7a's word-by-word data through `MushafTokenClassifier` and writes the
  result to `assets/quran/mushaf/kfgqpc_v2.json`: **1 Mushaf, 9,046 `MushafLine` rows,
  83,668 `MushafToken` rows** (77,433 `quranWord`, 6,235 `ayahMarker`, 0 `otherMarker`,
  0 `unknown`). The full canonical+Mushaf dataset passes `DatasetIntegrityValidator`
  (including the Mushaf-specific token/line-range/canonical-mapping checks added for this
  import). Verified deterministic: two independent runs against the same source files
  produced a byte-identical output file. Generated-dataset SHA-256:
  `e222f50aca11c320466a7a6a8a8348a0aaa13e1236c7e57b7945fde935f9ead8`.
- **Why this output is a separate, non-bundled asset**: `assets/quran/mushaf/kfgqpc_v2.json`
  is **not** declared in `pubspec.yaml`'s `assets:` list, so it is never packaged into a
  real app build. This is deliberate: QUL's redistribution terms for the layout and
  word-by-word resources are still `SHIP_BLOCKED_LICENSE` (unverified, not assumed), so
  the data is generated and fully tested for local development purposes — proving the
  pipeline is correct — without yet being distributed as part of the shipped app. This is
  the "release gate" `tool/quran_data/build_production_data.dart` records as
  `mushafReleaseGate` in the resource manifest. Once QUL's terms are confirmed, wiring
  this file into `pubspec.yaml` and `BundledDatasetSeeder` is the only remaining step —
  no further data engineering is needed.
- **What Tahfeez has built**: the replaceable layout-reading architecture
  (`lib/quran/domain/mushaf_data_source.dart`) plus the token-classification layer
  (§7c) plus this production import (`tool/quran_data/src/mushaf_import.dart`) plus
  updated `MushafRepository`-style read APIs (`QuranRepository.getLineTokens`/
  `getPageTokens`, replacing the earlier `getWordsForLine`/`getWordsForPage`, which could
  not represent a line containing a marker token) plus a Mushaf renderer
  (`lib/features/mushaf/`) now wired end-to-end against real `MushafToken` data instead
  of `AyahWord`. No synthetic or placeholder Mushaf content has been generated anywhere,
  at the explicit, repeated instruction of the project owner.
- **License**: **unverified**. Per QUL's own FAQ, "the resources available on QUL vary in
  their copyright status... review the licensing terms for each resource" — there is no
  blanket grant, and QUL's platform/codebase being MIT-licensed does **not** extend to
  this specific data resource. The specific redistribution terms for this exact layout
  file have not been independently confirmed (QUL's resource-specific license page is
  only reachable after the same login gate that blocks automated fetching).
- **Status**: `SHIP_BLOCKED_LICENSE`. The data itself is now fully understood and
  verified compatible (§7a/§7b) — the only remaining blocker for this resource is that
  its redistribution terms have not been independently verified. Per this project's
  rules: this is recorded honestly as blocked, **not** assumed permitted, and **not**
  silently marked "MIT" because QUL's software repository happens to be MIT. Resolving
  this requires the project owner's direct QUL account access to the resource's own
  license/terms page.

### Update 2026-10-11: licence

QUL's team answered for all its layouts, this one included (`mushaf-layout/10`,
2026-05-06, https://github.com/TarteelAI/quranic-universal-library/issues/596):
free for personal and commercial use; bundling, offline use, modification and
conversion to other formats allowed; attribution optional ("Data provided by
QUL" appreciated). The underlying Mus'haf al-Madinah is the King Fahd
Complex's, whose published usage rights allow free use "in websites, software,
and other similar intermediates". Status: **permitted** (was
`SHIP_BLOCKED_LICENSE`). Evidence in full: `docs/THIRD_PARTY_RESOURCES.md`,
"Mushaf licensing, 2026-10-11".

## 7a. Quran script/word-by-word dataset — QUL KFGQPC V2 Glyph (word IDs)

- **Source**: QUL, resource "QPC V2 Glyph - Word by Word"
  (`https://qul.tarteel.ai/resources/quran-script/61`).
- **File**: `qpc-v2.db` (table `words`), manually provided by the project owner and
  vendored at `tool/quran_data/sources/qpc-v2-word-by-word.db.zip`.
- **Content hash (SHA-256, of the extracted `qpc-v2.db` file)**:
  `4bf9549dfcfd367d4d4b151bd58b51af63b677d1c980cf5e52541c2f981d7e6d` (computed by
  `QulKfgqpcV2WordByWordSource.readInfo()`, `tool/quran_data/src/mushaf_wbw_source.dart`).
  Vendored zip hash: `a766a033cad47b36f00f493f5f0541d5f07e1336857eaa6feba92465af3f68bb`.
- **Schema**: `words(id INTEGER, location TEXT, surah INTEGER, ayah INTEGER, word INTEGER,
  text TEXT)`. `id` is the exact value §7's `pages.first_word_id`/`last_word_id` reference;
  `location` is `surah:ayah:word`; `text` is QCF V2 glyph text (see §8).
- **Why vendored rather than fetched by tooling**: same login gate as §7 — confirmed by
  inspecting the resource's own download links, which redirect to `/users/sign_in`.
- **License**: **unverified**, same status and reasoning as §7 (`SHIP_BLOCKED_LICENSE`).

### Update 2026-10-11: licence

No licence stated by QUL (checked 2026-10-11: resource page, FAQ, GitHub).
**Owner decision 2026-10-11: shipped with attribution** ("Data provided by
QUL", and the King Fahd Complex), on the strength of QUL's consistent answers
(layouts free for commercial use, #596; QUL's datasets available for
commercial use, #803) and the Complex's usage rights, which cover its QCF V2
glyph codes. See `docs/THIRD_PARTY_RESOURCES.md`, "Mushaf licensing,
2026-10-11".

## 7b. Compatibility audit and the ayah-marker finding

A full read-only audit (no import performed) confirmed §7 and §7a are genuinely built
from the same underlying word sequence:

- 604 pages; `words` has exactly 83,668 rows, ids contiguous 1..83,668, no duplicates.
- Every one of the 8,820 `ayah` lines' `first_word_id`/`last_word_id` resolves to a real
  `words` row; zero unresolved references, zero reversed ranges.
- Zero gaps between consecutive ayah-lines' word-id ranges across the entire book — the
  layout's final `last_word_id` (83,668) exactly equals `words`' max `id`.
- `location` is internally consistent with `surah`/`ayah`/`word` for all 83,668 rows.

**Finding**: QUL's per-ayah token count is exactly one more than the canonical Tanzil
word count, for 6,235 of the Quran's 6,236 ayahs (verified by exact arithmetic:
`83,668 − 77,433 canonical words = 6,235`). This is the small ayah-end/verse-number
ornament every printed ayah carries, occupying its own id immediately after the ayah's
real words — not a data error. The sole exception is ayah 37:130, which has no such
token (all 4 of its tokens are real words, matching the canonical count exactly) — a
genuine, singular anomaly in the authentic data, detected structurally by
`MushafTokenClassifier` rather than hardcoded. See §7c for how Tahfeez represents this.

Real-word-to-canonical mapping was verified at the count and positional-order level
exhaustively (every ayah's tokens sort identically by id and by word-position; every
ayah's real-word count, once its trailing marker is excluded, exactly matches the
canonical `AyahWord` count for that ayah). It was **not** possible to independently
verify glyph-level text *content* equality, since QUL's text is font-remapped codepoints
rather than plain Unicode, and the one plain-Unicode word-by-word resource sharing this
numbering scheme ("KFGQPC Hafs script - Word by word", resource 312) is also
login-gated and has not been obtained.

## 7c. `MushafToken` — a separate Mushaf-rendering token model

Per explicit product decision, QUL's word-id stream is **not** imported into canonical
`AyahWord` rows (an ayah-end marker is not Quran text and must never be counted as a
word, searched, or included in word-by-word/AI alignment). Instead:

- `lib/quran/domain/models/mushaf_token_models.dart` — `MushafToken` (fields:
  `mushafId, sourceTokenId, sequenceIndex, tokenType, displayText, surahNumber?,
  ayahNumber?, sourceWordPosition?, canonicalWordIndex?, canonicalAyahId?`) and
  `MushafTokenType` (`quranWord | ayahMarker | otherMarker | unknown`).
  `sourceTokenId` preserves QUL's `id` exactly. `canonicalWordIndex`/`canonicalAyahId`
  are set only for `quranWord` tokens — a marker never receives a fabricated canonical
  reference. No `canonicalAyahWordId` field exists: `AyahWord` has no surrogate key, so
  `canonicalAyahId` + `canonicalWordIndex` together are already the complete join key.
- `lib/quran/domain/mushaf_token_classifier.dart` — `MushafTokenClassifier`, which
  derives each ayah's token classification *from the data itself* (comparing that ayah's
  QUL token count against its canonical word count — exact match → all `quranWord`;
  exactly one more → all but the last are `quranWord`, the last is `ayahMarker`; anything
  else → every token for that ayah is `unknown`, with a reported warning). This is a
  direct, nullable mapping (validated reliable by §7b's audit), not a separate mapping
  table — per instruction, a separate `MushafTokenCanonicalWordMap` table is reserved for
  if a future source's mapping proves non-1:1.
- `test/quran_data/qul_word_by_word_source_test.dart` runs this classifier against the
  real vendored `qpc-v2.db` and the real bundled canonical dataset, asserting exactly the
  numbers above (6,235 `ayahMarker`, 77,433 `quranWord`, 0 `unknown`, 0 `otherMarker`,
  every `quranWord` token's canonical reference resolves to a real `AyahWord`).
- **Built**: `tool/quran_data/src/mushaf_import.dart` (the production import combining
  §7's layout with this classifier) and `MushafTokens`/updated `MushafLines` Drift tables
  (`lib/quran/data/tables/mushaf_tables.dart`) that store the result — see §7's "Production
  import — complete" note for row counts and hashes.

## 8. Quran script/glyph font — KFGQPC/QCF V2

- **What it is**: the glyph font QUL's KFGQPC V2 layout is typeset against — confirmed to
  be genuinely page-by-page: the project owner obtained "QPC V2 Font.ttf.bz2" (actually a
  zip), which contains 604 individual TTF files (`p1.ttf`..`p604.ttf`, ~198MB
  uncompressed, ~130MB compressed), named `QCF2001`..`QCF2604` internally. A pure-Dart TTF
  `name`-table parser (`tool/quran_data/src/ttf_inspector.dart`, no external tool
  dependency) verified **all 604** files' embedded family names against their filename's
  page number — not just spot-checked — with zero mismatches. Inspecting each font's
  `cmap` table directly confirmed the earlier CDN-based finding: the *same* numeric
  codepoint (e.g. `0xFC41`) is deliberately reused across different pages' fonts to draw
  *different* glyphs (verified: it renders Al-Fatiha's first word on page 1's font and
  Al-Ikhlas's first word on page 604's font) — a line's `MushafToken` text is only
  meaningful when rendered through that exact page's own font file.
- **Generated font package**: `tool/quran_data/build_qpc_fonts.dart` copies the 604
  unmodified files to `assets/quran/fonts/qpc_v2/pN.ttf` and writes a generated,
  per-file-verified manifest to `assets/quran/manifests/qpc_v2_fonts.json`
  (`PageFontManifest`/`PageFontManifestEntry`,
  `lib/quran/domain/models/page_font_manifest_models.dart`) mapping every page to its
  exact asset path, verified font family, source filename, and content hash. Neither the
  font files nor the manifest are hand-written; both are regenerated deterministically
  from the real vendored package. The font *files* are gitignored
  (`assets/quran/fonts/`) for the same reason as the Mushaf dataset (§7); the *manifest*
  is committed, since it carries no copyrighted content, only structural metadata and
  hashes (the same reasoning that already applies to `resource_manifest.json`).
- **Rendering architecture**: `QpcPageFontManager` (`lib/features/mushaf/domain/
  qpc_page_font_manager.dart`, implemented by `FontLoaderQpcPageFontManager` in
  `lib/features/mushaf/data/`) lazily registers one page's font via `dart:ui`/
  `package:flutter`'s `FontLoader` only when that page is actually viewed — never all 604
  at startup. Concurrent requests for the same page share one in-flight load (verified by
  a real-engine test, `test/features/mushaf/data/font_loader_qpc_page_font_manager_test.dart`);
  ±2 neighboring pages preload in the background without blocking the current page.
  `MushafPageView` never renders Quran glyph text before that page's real font is
  confirmed loaded — no fallback/previous-page font is ever substituted, per explicit
  instruction; a brief loading state (or an honest "font packaging pending" message when
  no manifest is bundled at all) is shown instead.
- **Status**: `SHIP_BLOCKED_LICENSE`. Obtaining, verifying structure, and building a
  correct rendering pipeline around these files is **not** the same thing as clearing
  their redistribution — that has not happened. QUL's own FAQ places fonts under the same
  "review per resource, no blanket grant" rule as every other dataset category, and the
  official font resource page's own download links are login-gated.
  `docs/reference/05_MUSHAF_SPEC.md` already recorded, before this milestone, that a
  reference-app KFQPC-style font must never simply be copied into Tahfeez; this finding
  is consistent with that and extends it to QUL's redistribution of the same font family.
  Per instruction, this blocker is recorded honestly rather than worked around by
  silently substituting an unrelated font and calling the Mushaf layer "done."
- **The runtime gate is a Dart-code refusal, not a build-time exclusion — a known, real
  gap**: `BundledDatasetSeeder` and `qpcPageFontManifestProvider` both refuse to
  import/load this content when `kReleaseMode` is true, so *the app itself* never
  displays it in a release build. This does **not** remove the asset bytes from a
  naively-built release package: a real `flutter build appbundle --release` performed
  during this work produced a 204.9MB AAB that still physically contains the full font
  package and Mushaf dataset (Flutter's asset system has no built-in per-build-type
  exclusion without a product-flavor setup, which was not implemented — see the release
  checklist below). Any real public release **must** either clear the redistribution
  question or remove/flavor-gate the three asset lines in `pubspec.yaml` before building;
  do not treat the `kReleaseMode` code gate alone as sufficient for a store submission.

## 9. Tahfeez-generated data — search indexes

Arabic/translation/Surah search indexes (`lib/quran/data/tables/search_index_tables.dart`,
Milestone 10) are derived entirely from the canonical/translation data above at
index-build time, contain no independently-licensed content, and are not a data
provenance concern — see `docs/ARCHITECTURE.md` §21 for their own design rationale.

## 10. Surah header decorative font — QUL Surah Header (color)

- **Source**: QUL's official Surah Header font and its own ligature/JSON mapping,
  manually provided by the project owner and vendored at
  `tool/quran_data/sources/QCF_SurahHeader_COLOR-Regular.ttf.zip` and
  `tool/quran_data/sources/ligatures.json.zip`.
- **Content hash (SHA-256, of the extracted files)**: font
  `731cdc14a3e50669ffd44c06335ce269665e22cb75db39ca137527e29c516308`; ligature JSON
  `c4480a1fb616685421ada1f9cbd36187c1c27c01d8d78d27a866858fdaf5c4f7`.
- **What the font actually is**: embedded family `QCF_SurahHeader_COLOR`, 124 glyphs, a
  **COLRv0/CPAL color font** (6 palettes, 120 base color-glyph records) — confirmed via
  `tool/quran_data/src/ttf_inspector.dart`, extended this milestone to parse `cmap`
  (format 4 and format 12 subtables) and read `COLR`/`CPAL`/`GSUB` table presence, not
  assumed from the filename. Each of QUL's 114 `surah-N` ligature-JSON entries maps to
  **exactly one** real Arabic Presentation-Forms-A codepoint (e.g. `surah-1` →
  `U+FC45`) that the font's own `cmap` resolves to a real glyph — verified for all 114
  entries, not sampled. The font has **no `GSUB` table**: each surah's complete
  frame+name artwork is a single pre-composed color glyph behind one codepoint, not a
  ligature substitution assembled at shaping time — so no shaping engine is needed to
  render it correctly, only a correct `cmap` lookup.
- **Rendering — confirmed working, not just theoretically supported**: a real
  `flutter test` render (Skia, software rendering) of this font at its real codepoint
  produces the *complete*, correctly-colored decorative frame+name artwork, matching a
  real printed Mushaf's Surah-header banner — see
  `test/features/mushaf/presentation/goldens/mushaf_page_1.png`. This directly resolves
  the open question this milestone was asked to test: whether a QUL color Surah Header
  font renders correctly under Flutter/Skia. It does, at least under Skia's software
  rasterizer on Linux; this has **not** additionally been confirmed on a real Android/iOS
  device, and COLR palette selection (the font's 6 palettes) is not currently
  controllable from `dart:ui`'s `TextStyle` API — Tahfeez always gets palette 0, the
  font's own default.
- **Built**:
  - `tool/quran_data/src/surah_header_font_package.dart` /
    `tool/quran_data/build_surah_header_font.dart` — verifies all 114 ligature-JSON
    entries against the real font's `cmap` and writes
    `assets/quran/manifests/surah_header_glyphs.json` (committed; no copyrighted content)
    plus the copied, unmodified font at
    `assets/quran/fonts/qcf_surah_header/QCF_SurahHeader_COLOR-Regular.ttf` (gitignored,
    same as the QPC V2 page fonts).
  - `lib/quran/domain/models/surah_header_glyph_models.dart` /
    `lib/quran/data/surah_header_glyph_manifest_codec.dart` — the manifest model and its
    decoder, mirroring `PageFontManifest`'s established pattern.
  - `lib/features/mushaf/application/surah_header_font_providers.dart` —
    `surahHeaderGlyphManifestProvider`, which loads the manifest and registers the font
    via `FontLoader`; refuses to load in `kReleaseMode`, same `SHIP_BLOCKED_LICENSE` gate
    as §8.
  - `lib/features/mushaf/presentation/mushaf_page_render_model.dart` —
    `_buildDecorativeSurahHeaderLine` shapes the single glyph codepoint at a reference
    size, then uniform-scales it (`scale = min(targetWidth / naturalWidth, lineHeight /
    naturalHeight)`, one factor for both axes — aspect ratio is always exactly
    preserved) to occupy 96% of the line's available width (the middle of a 94–98%
    target band, leaving an even safety margin so it never touches or crosses the page's
    own content margins) or as much of it as the authoritative `surah_name` line's own
    height allows, whichever binds first — never distorted to force the target if height
    is the limit. Falls back to the previous plain localized-name text
    (`isDecorative: false`) when the manifest isn't bundled. The localized chapter name
    is always carried as `semanticLabel`, exposed as a real accessibility node via
    `MushafPagePainter.semanticsBuilder` — the visible glyph is never the semantics
    source of truth, verified by
    `test/features/mushaf/presentation/mushaf_page_render_model_test.dart` and a
    real-semantics-tree assertion in `mushaf_reader_screen_test.dart`.
  - **Monochrome presentation**: the font's own embedded COLR/CPAL color layers are
    never edited, removed, or re-encoded — `MushafPagePainter` instead wraps the header
    glyph's paint call in a real `Canvas.saveLayer` with
    `Paint()..colorFilter = ColorFilter.mode(headerInk, BlendMode.srcIn)`, the Canvas
    -level equivalent of a widget-tree `ColorFiltered` (necessary here since this line is
    painted directly onto a `CustomPainter`'s canvas, not through a widget). This
    preserves every glyph layer, frame detail, and antialiased edge — only the *color*
    each pixel is painted with changes, never the shape. `headerInk` is a new semantic
    field on `MushafAppearanceColors` (`lib/features/mushaf/domain/mushaf_appearance.dart`),
    one value per appearance (light/warm/sepia/dark/black), distinct from body text
    color, never a single hard-coded color across themes. Verified via real pixel
    decomposition (not just a visual diff) for all of Al-Fatihah, Al-Baqarah,
    Al-Ma'idah, Al-Kahf, Maryam, Ya-Sin, Ar-Rahman, Al-Ikhlas, and An-Nas, plus a
    multi-transition page, in
    `test/features/mushaf/presentation/mushaf_surah_header_monochrome_test.dart`
    (confirms every non-background pixel is a valid alpha blend of the exact ink color —
    no trace of the font's own green/gold/pink artwork survives), with representative
    visual goldens across three themes in
    `mushaf_surah_header_monochrome_golden_test.dart`. The `saveLayer` this requires is
    real, non-free offscreen-composition cost, but only runs inside `paint()`, which the
    page's `RepaintBoundary`+`willChange: false` does not re-invoke on every
    scroll/composite frame for an otherwise-unchanged page — reasoned about, not measured
    on a real device; see `docs/MUSHAF_RENDERING.md`'s known limitations.
  - Decorative artwork is used **only** on the Mushaf page itself; every other surface
    (index, search, navigation, bookmarks, home) already renders plain localized names
    through entirely separate code paths untouched by this work.
- **License**: **unverified**, same reasoning and status as §7/§7a/§8 — QUL's
  resource-specific terms have not been independently confirmed.
- **Status**: `SHIP_BLOCKED_LICENSE`. Fully built, verified against all 114 surahs, and
  confirmed to render correctly; not shipped in a release build for the same
  redistribution reason as §8.

## 11. Bismillah decorative font — QCF2BSML (KFGQPC V2) — investigated, NOT wired in

- **Source**: `QCF2BSML.ttf`, from the KFGQPC V2 package, manually provided by the
  project owner at `tool/quran_data/sources/QCF2BSML.ttf` (SHA-256
  `457cd1bf2174e9c10b31eab25bc5eda20c12abbafe5f47bdea473c64036f411e`).
- **What was verified, and what that rules out**: embedded family `QCF2BSML`; 718
  `cmap` entries spanning ASCII, Latin-1 Supplement, the basic Arabic block, Arabic
  diacritics, Arabic-Indic digits, and Arabic Presentation Forms A/B. **`U+FDFD`
  ("Arabic Ligature Bismillah Ar-Rahman Ar-Raheem") is absent from this font's `cmap`**
  — the "just use U+FDFD" assumption this milestone was explicitly told not to make is
  confirmed wrong, not just unconfirmed. The font has `morx`/`feat`/`prop`/`just`
  tables (Apple Advanced Typography) and no `GSUB` table.
- **What was tested, and what it showed**: a real `flutter test` render (`FontLoader`
  + `TextPainter`/`Text`, real Skia engine) of the font against the app's own
  already-canonical Bismillah text (`bismillahText` provider, sourced from Al-Fatiha
  1:1 — never a fresh literal) produced **empty "tofu" glyph boxes for every basic
  Arabic letter and every Arabic-Presentation-Forms-B codepoint tested**, including
  ones confirmed present in the `cmap`. A control render of three plain ASCII Latin
  letters (`'ABC'`, arbitrarily chosen as a sanity check) instead produced a
  **complete, correctly-shaped, fully-diacritized Arabic phrase** — proving this font
  uses the *same* per-arbitrary-codepoint, one-glyph-per-word encoding scheme as the
  ordinary QCF2NNN page fonts (§8: "the same numeric codepoint is deliberately reused
  across different pages' fonts to draw different glyphs"), not a plain-Arabic-text
  font that a shaping engine (AAT or otherwise) turns into real letterforms. Plain
  canonical Unicode Bismillah text is therefore **not** valid input for this font —
  that assumption is now disproven, not merely unverified.
- **The blocker**: rendering the Bismillah correctly with this font requires knowing
  the *specific* arbitrary codepoint sequence its own author assigned to
  "بِسْمِ اللَّهِ الرَّحْمَٰنِ الرَّحِيمِ" — exactly the kind of per-font word→codepoint
  mapping the ordinary QCF2NNN pages get from the companion `qpc-v2-word-by-word.db`
  (§7a). **No equivalent word-by-word/mapping resource for QCF2BSML has been
  provided.** `qpc-v2-word-by-word.db`'s `words` table was directly re-checked for any
  non-standard `location` values that might represent a standalone Bismillah insertion
  (as opposed to an ordinary `surah:ayah:word` reference): none exist — exactly
  83,668 contiguous rows, all normally addressed, with no room for an additional 112×4
  Bismillah-only entries. Per this milestone's explicit instruction not to "manufacture
  `first_word_id`/`last_word_id` values for these lines," and given the strict
  Quran-correctness rules in `CLAUDE.md`, this codebase does **not** attempt to
  reverse-engineer the mapping by visually matching candidate glyphs to known word
  shapes — that would risk shipping a subtly wrong rendering of text that appears 112
  times, based on a guess rather than a verified source.
- **Forensic search of the provided package — confirmed empty, not just unchecked**: a
  follow-up read-only search covered every file the project owner provided (not just
  the font in isolation): the "QPC V2 Font.ttf.bz2" package (verified to contain
  exactly 604 page-font files and nothing else), both QUL SQLite databases' complete
  schemas (`qpc-v2-15-lines.db`: `pages`/`info` only; `qpc-v2.db`: `words` only — no
  additional table), and a literal-string search of every source file for `QCF2BSML`,
  `BSML`, `BASMALA`, `BISMILLAH`, `بسملة`, `بسم`. Only the font's own embedded `name`
  table matches (its own family name). The font's `post` table (format 2.0, all 606
  glyphs) was also fully dumped: glyphs 0–474 use standard Adobe Arabic glyph names
  (`behinitialarabic`, `noonjeemisolatedarabic`, etc. — ordinary *letter*-level AAT
  font glyph names), while the higher glyph range that includes the composite
  word-glyphs found by the earlier rendering test (475–605) are all **unnamed**
  (Mac-standard-slot placeholders or empty strings) — meaning even the font's own
  authors (Harf Information Technology, per its `name` table) never recorded a semantic
  label for these glyphs; the word→codepoint mapping lived only in their internal
  production tooling and was never shipped with this file, in any form.
- **What is needed to unblock this**: a QUL (or other verified official KFGQPC)
  resource that maps the standalone Bismillah insertion's word sequence to
  `QCF2BSML`'s own codepoints — the same kind of resource §7a already provides for
  every ordinary page. Until that exists, `QCF2BSML.ttf` remains unwired.
- **Status**: investigated, **not wired into the render pipeline**. No code change was
  made to shape text through this font — shipping a fabricated or guessed glyph mapping
  for text repeated 112 times across the Mushaf was judged a worse outcome than leaving
  it unwired. **Superseded as the active Bismillah rendering plan**: §14 below
  (`quran_common.ttf`) is now the active mechanism, replacing what had been a plain
  -system-font fallback at the time this section was written.

## 14. Bismillah + Surah-header title frame font — QuranApp's `quran_common.ttf`

- **Source**: `quran_common.ttf`, vendored from a local checkout of
  AlfaazPlus/QuranApp (`app/src/main/res/font/quran_common.ttf`) — a public,
  GPLv3-licensed reference application studied for behavior only, per
  `docs/CLEAN_ROOM_RULES.md` (no Kotlin/Compose code was ported; the visual
  composition was reimplemented independently in Flutter).
- **Content hash (SHA-256)**: `63675d54764c3e0acd3875e191dc6f0af1339ddbd53a1df7fcebbaabebc918fa`.
- **What was verified, directly against the real file — never assumed**: embedded
  family `quran-common`; both codepoints this project actually uses are confirmed
  present in its real `cmap` table: U+E000 (the decorative title-frame glyph,
  QuranApp's own `QuranGlyphs.Special.TITLE_FRAME`) and U+FDFD (the decorative
  Bismillah glyph, `QuranGlyphs.Special.BISMILLAH`) — the same "do not assume U+FDFD"
  discipline §11 already established, here resolved by inspection rather than ruled
  out. The font's table directory has **no `COLR`/`CPAL`** — an ordinary, single-color
  outline font, confirmed by direct inspection, not assumed from its filename or
  purpose — so no `saveLayer`/`ColorFilter` monochrome treatment is needed to use it;
  color is baked in at shape time via ordinary `TextStyle.color`, exactly like normal
  text.
- **Built**: `tool/quran_data/src/quranapp_font_package.dart` /
  `tool/quran_data/build_quranapp_special_fonts.dart` verify both codepoints against
  the real `cmap` and write `assets/quran/manifests/quran_common_font.json`
  (committed; no copyrighted content) plus the copied, unmodified font at
  `assets/quran/fonts/quranapp/quran_common.ttf` (gitignored, same treatment as every
  other vendored font in this document).
  `lib/features/mushaf/application/quranapp_special_font_providers.dart` loads the
  manifest and registers the font via `FontLoader`; refuses to load in `kReleaseMode`,
  same gate as every other resource in this document.
- **Rendering — the active mechanism**: `lib/features/mushaf/presentation/
  mushaf_page_render_model.dart`'s `_buildDecorativeBismillahLine` (Bismillah) and
  `_buildQuranAppSurahHeaderLine` (the frame half of the Surah header, §15 covers the
  name half) — both reimplemented independently from studying QuranApp's
  `compose/components/reader/Bismillah.kt`/`ChapterTitle.kt`/`ChapterIcon.kt` and
  `utils/quran/QuranGlyphs.kt`/`compose/theme/Type.kt` for behavior only, never a
  ported Kotlin/Compose file. Sizing is expressed as ratios against this project's own
  `MushafPageLayoutEngine.baseFontSize` (QuranApp's reference 36sp/46sp against this
  project's reference 28 — see those functions' own doc comments), never a hard-coded
  logical-pixel constant, so both glyphs scale with the page's real, already-calibrated
  font scale. Both glyphs shrink to fit their line's authoritative box (never adding
  line height, never moving surrounding lines) and are centered.
- **Superseded**: replaces the plain-system-font Bismillah fallback that was this
  project's only implementation before this milestone (that fallback still exists, now
  correctly demoted to the dev-only state used while this font isn't bundled at all).
- **License**: **unverified**. QuranApp's repository-level `LICENSE` is GPLv3; per
  `docs/CLEAN_ROOM_RULES.md`'s explicit instruction not to assume a repository's
  license extends to every third-party resource it contains, this is **not** assumed
  to cover redistribution of this specific font file, and no separate font
  license/attribution file exists anywhere in the QuranApp repository (checked
  directly: only its repo-level `LICENSE`, no per-font `NOTICE`/license file next to
  `app/src/main/res/font/`).
- **Status**: `SHIP_BLOCKED_LICENSE`. Fully built, verified, and confirmed rendering
  correctly for all 10 representative surahs this milestone named plus the Bismillah
  glyph itself; not shipped in a release build pending redistribution clearance.

## 15. Surah-name calligraphy font — QuranApp's `suracon.ttf`

- **Source**: `suracon.ttf`, vendored from the same local AlfaazPlus/QuranApp checkout
  (`app/src/main/res/font/suracon.ttf`) — same clean-room basis as §14.
- **Content hash (SHA-256)**: `cbda233eed3177c473793b513b9b55f219937ab0ffcc494f35c70750c690014c`.
- **What was verified, directly against the real file**: embedded family `suracon`; all
  114 Surah-name codepoints *and* the shared prefix codepoint from QuranApp's own
  `utils/quran/QuranGlyphs.kt` (`Chapter.icons`, studied as factual character-map data —
  never ported as code) are confirmed present in the font's real `cmap` table — 0
  missing, not sampled. No two surahs (or the prefix) collide on the same codepoint. No
  `COLR`/`CPAL` — an ordinary outline font, same as §14, so no color-treatment is
  needed.
- **Built**: `tool/quran_data/src/quranapp_font_package.dart`'s
  `buildSuraconGlyphManifest` verifies every codepoint and writes
  `assets/quran/manifests/suracon_glyphs.json` (committed) plus the copied font at
  `assets/quran/fonts/quranapp/suracon.ttf` (gitignored).
  `lib/features/mushaf/application/quranapp_special_font_providers.dart` loads and
  registers it, same `kReleaseMode` gate as §14.
- **Rendering**: `_buildQuranAppSurahHeaderLine` overlays the Surah name glyph
  concatenated with the shared prefix glyph (name first, then prefix — the same order
  QuranApp's own `ChapterIcon.kt` concatenates them) on top of the §14 title frame,
  scaled proportionally to it (QuranApp's fixed 46sp:30sp frame:name ratio, preserved
  as a ratio rather than two independently-sized constants) and shifted down from the
  frame's own vertical center by a proportional amount (QuranApp's fixed 8dp shift,
  likewise converted to a ratio of the frame's own rendered size).
- **Superseded**: replaces the QUL Surah Header COLR font (§10) as the active Surah
  -header mechanism. §10's font/manifest/provider/render-model code is deliberately
  **not deleted** — kept as an unused development resource per explicit instruction,
  pending a decision on whether to remove it entirely — but
  `mushaf_layout_providers.dart` no longer watches or supplies its resolver, so it
  never runs in production any more.
- **License**: **unverified**, same reasoning and status as §14 — GPLv3 at the
  repository level does not automatically extend to this specific font file, and no
  separate font license exists in the checkout.
- **Status**: `SHIP_BLOCKED_LICENSE`. Fully built, verified against all 114 surahs, and
  confirmed rendering correctly (including real pixel-level ink verification, not just
  a visual diff) for Al-Fatihah, Al-Baqarah, Al-Ma'idah, Al-Kahf, Maryam, Ya-Sin,
  Ar-Rahman, Al-Ikhlas, Al-Falaq, and An-Nas; not shipped in a release build pending
  redistribution clearance.

## 16. Verse-by-verse Quran text font — QuranApp's `uthmanic_hafs.ttf`

- **Source**: `uthmanic_hafs.ttf` ("KFGQPC HAFS Uthmanic Script"), vendored from the same
  local AlfaazPlus/QuranApp checkout as §14/§15
  (`app/src/main/res/font/uthmanic_hafs.ttf`) — same clean-room basis: studied and
  vendored as a font resource only, no Kotlin/Compose code ported.
- **Content hash (SHA-256)**: `aa68bffce289b4c0ebac68e90502eb69e42356abcd1603cb2b8e99c2c723f145`.
- **Why this font, and not the §8 QCF V2 page fonts**: the verse-by-verse reader displays
  the canonical `AyahWord` text (real Unicode Arabic codepoints, script-independent), never
  a specific Mushaf page's `MushafToken` text. §8's QCF V2 files are page-specific
  private-use-area glyph fonts — a given codepoint only draws the right glyph when paired
  with *that exact page's* font file (see §8's own finding), so rendering canonical Arabic
  text through one would produce wrong or blank glyphs. `uthmanic_hafs.ttf` is an ordinary
  Uthmanic-Hafs-style Arabic text font — real Unicode cmap coverage, real `GSUB`/`GPOS`
  shaping tables for correct Arabic contextual forms and diacritic positioning — so it can
  shape any canonical Arabic string, not just one page's pre-arranged glyph run. Using it
  is how "the same font of the verses in Mushaf mode" is honored in spirit (the same
  Uthmanic Hafs calligraphy style) without the page-specific-glyph mismatch that would
  result from literally reusing a §8 file outside its own page context.
- **What was verified, directly against the real file**: embedded family
  `KFGQPC HAFS Uthmanic Script`; the font's table directory has `GSUB`/`GPOS`/`kern` (real
  Arabic shaping support) and **no `COLR`/`CPAL`** — an ordinary, single-color outline
  font, same treatment as §14/§15.
- **Built**: `tool/quran_data/src/quranapp_font_package.dart`'s
  `buildQuranTextFontManifest` (a generic family+hash verifier — no per-codepoint check is
  needed for an ordinary text font, unlike §14/§15's private-use glyphs) writes
  `assets/quran/manifests/uthmanic_hafs_font.json` (committed) plus the copied,
  unmodified font at `assets/quran/fonts/quranapp/uthmanic_hafs.ttf` (gitignored, same
  treatment as every other vendored font in this document).
  `lib/features/mushaf/application/quranapp_special_font_providers.dart`'s
  `uthmanicHafsFontManifestProvider` loads the manifest and registers the font via
  `FontLoader`, same `kReleaseMode` refusal gate as §14/§15.
- **Also distributed as**: `UthmanicHafs_V22.ttf` (the file name QUL's own official QPC
  Hafs font package uses) — vendored separately during the §17 compatibility audit and
  confirmed **byte-for-byte identical** (same SHA-256 above) to this file. The two names
  refer to the exact same font; this document treats them as one resource.
- **Rendering history — the original defect was a text/font mismatch, not a font defect
  (corrected finding)**: an earlier attempt to wire this font into `VerseBlock`/
  `BismillahDivider`/`word_detail_sheet.dart` rendered real canonical **Tanzil** `AyahWord`
  text through it and found a reproducible defect — U+06DF ARABIC SMALL HIGH ROUNDED ZERO,
  as it appears in the real word "أُو۟لَٰٓئِكَ" (2:5's "أُولَٰئِكَ"), painted as an
  oversized, full-height black circle instead of a small positioned mark. That wiring was
  reverted and every affected call site fell back to the plain system Arabic font (see
  git history for that change). A later compatibility audit (§17) re-tested this font
  against its **own paired script** (QPC Hafs word-by-word, not Tanzil) and found the
  defect does not reproduce: that script encodes the same phonetic phenomenon as 2:5:1
  differently (U+0652 plain sukun, never U+06DF — U+06DF does not occur anywhere in the
  83,668-word QPC Hafs corpus), and real-font rendering of one sample word for all 19
  distinct Quranic annotation marks (U+06D6–U+06ED) the corpus actually uses showed no
  oversized/malformed glyphs. **Conclusion: this font is not defective — it was rendering
  text encoded for a different script.** Per this project's own explicit "do not render
  arbitrary Tanzil text through the QPC Hafs font and assume correctness" rule (learned
  from this exact incident), the font is approved for use **only** when paired with its
  own QPC Hafs script (§17), never with Tanzil `AyahWord` text directly.
- **Status**: not yet wired into production rendering. The font, manifest, and provider
  infrastructure are built and verified; what remains is importing the §17 script into the
  app's data layer and pointing verse-by-verse-mode call sites at it instead of Tanzil
  text (canonical word identity/tap-targets stay on `AyahWord` regardless — see §17).
- **License**: **unverified** — GPLv3 at AlfaazPlus/QuranApp's repository level is not
  assumed to cover this specific font file, and separately, QUL's own distribution of the
  identical `UthmanicHafs_V22.ttf` carries QUL's own "review per resource, no blanket
  grant" terms (see §17). `SHIP_BLOCKED_LICENSE` either way.

## 17. Verse-by-verse Quran display script — QUL "QPC Hafs" word-by-word dataset

- **Source**: `qpc-hafs-word-by-word.db`, manually vendored from QUL (Quran Complex/King
  Fahd Glorious Quran Printing Complex's own "Hafs" Unicode word-by-word export), the
  same "manually supplied, not auto-fetched" basis as every other QUL resource in this
  document (§7/§7a/§8) — QUL's downloads are account/login-gated.
- **Vendored as**: `tool/quran_data/sources/qpc-hafs-word-by-word.db.zip` (SHA-256
  `64b59c7ae3dae32f3650c534cb5a40c91089e0a6319372ded9500181a3cc6a47`), containing
  `qpc-hafs-word-by-word.db` (SHA-256
  `e1cf266ed47a56e58100c08f69499f635f84c97233318cc53daf17200fb9048e`) — gitignored, same
  treatment as `qpc-v2-word-by-word.db.zip` (§7a).
- **Schema**: a single table, `words(id, location, surah, ayah, word, text)` — the exact
  same shape as §7a's own `words` table.
- **What was verified, directly against the real file, for all 83,668 rows (not
  sampled)**: `id` ranges 1–83668 in both this table and §7a's QPC V2 word-by-word table,
  contiguous, no duplicates; every `id`'s `(surah, ayah, word)` is identical between the
  two tables — only `text` differs (this table's real Unicode Arabic vs. §7a's
  page-specific glyph codepoints). Cross-checked against §7's 15-line layout's
  `first_word_id`/`last_word_id` ranges: zero missing references, zero duplicate word
  usages, zero gaps, across all 8,820 `ayah`-type lines on all 604 pages — a perfect,
  deterministic partition. (This check was performed as part of evaluating — and
  rejecting — a QPC V2→QPC Hafs Mushaf-mode migration; see
  `docs/MUSHAF_RENDERING.md` §2a for that decision. This resource's own data quality was
  not in question; only whether it should *replace* QPC V2 for the Mushaf page body.)
- **Rendering — validated when paired with its own font**: see §16's "Rendering history"
  bullet for the full account. In short: this script's own text, rendered through
  `uthmanic_hafs.ttf`/`UthmanicHafs_V22.ttf`, does not reproduce the U+06DF defect found
  when a *different* script (Tanzil) was rendered through the same font — this script
  encodes the relevant phenomenon differently (plain sukun, not U+06DF), and real-font
  rendering of all 19 distinct Quranic annotation marks this corpus uses showed no
  defects.
- **A caveat this project's import handles explicitly, not by assumption**: this script's
  `word` numbering counts ayah-end markers (the Arabic-Indic ayah number, e.g. `٥`) as
  their own "word" entries — it is **not** always a simple "canonical count + 1" away from
  `AyahWord`'s own word count for the same ayah. `tool/quran_data/build_qpc_hafs_display.dart`
  validates every one of the 6,236 canonical ayahs against this script directly (not by
  formula): 6,235 ayahs have exactly one extra trailing word (the marker) and are imported;
  **one ayah — 37:130 — does not** and is excluded rather than guessed. Real cause,
  confirmed by inspection: Tanzil's canonical text splits the compound name "الياسين" into
  two words ("إِلْ"/"يَاسِينَ"), while this script keeps it as one word
  ("إِلۡ يَاسِينَ") — a genuine cross-source word-segmentation difference, not a data
  error in either source. Canonical word identity/tap-targets/audio-highlighting always
  read from `AyahWord`'s own `(ayahId, wordIndex)`, never this script's `word` column —
  see `docs/ARCHITECTURE.md` §25's `QuranDisplayRepository` design note.
- **Imported**: `tool/quran_data/build_qpc_hafs_display.dart` writes
  `assets/quran/quran_display/qpc_hafs_display_words.json` — 6,235 ayahs' worth of
  ordered word lists (37:130 excluded, recorded in the manifest's own `excludedAyahIds`),
  each list exactly as long as that ayah's real `AyahWord` count, so
  `QuranDisplayRepository.displayWordsForAyah(ayahId)![i]` and `AyahWord`s for that ayah at
  index `i` are always guaranteed to refer to the same word. Same gitignored/
  license-gated/`kReleaseMode`-refusal treatment as `assets/quran/mushaf/kfgqpc_v2.json`
  (§7) — see `.gitignore`'s own comment for this path, and
  `lib/features/reader/application/quran_display_providers.dart`.
- **Wired into rendering**: `lib/features/reader/presentation/widgets/verse_block.dart`
  and `bismillah_divider.dart` use `QuranDisplayRepository` + `uthmanicHafsFontManifestProvider`
  (§16) together — only when *both* a validated word list (same length as the ayah's real
  word count) and the font are available; otherwise falling back to the pre-existing
  canonical-text/system-font rendering, per-ayah. Word tap, word-by-word translation, and
  the verse's own copy/share text all continue to read `AyahWord` directly, unaffected by
  which text is visually painted.
- **Status**: `SHIP_BLOCKED_LICENSE`. Imported, validated, and wired into verse-by-verse
  rendering; `kReleaseMode` refuses to load it in a release build, same as every other
  QUL-sourced resource in this document, until redistribution is cleared.

---

## Reproducing this dataset

```
dart run tool/quran_data/fetch_sources.dart        # Tanzil + QuranEnc, live network
dart run tool/quran_data/build_production_data.dart # writes assets/quran/*.json
```

The QUL layout and word-by-word files must already exist at
`tool/quran_data/sources/qpc-v2-15-lines.db.zip` and
`tool/quran_data/sources/qpc-v2-word-by-word.db.zip` (both committed to this repository,
since neither can be re-fetched automatically — see §7/§7a) for the Mushaf layer
(`assets/quran/mushaf/kfgqpc_v2.json`) to build; if either is absent the build still
succeeds for the canonical/translation/tafsir layers and reports the Mushaf layer as
`SHIP_BLOCKED_MISSING_SOURCE`. The QPC V2 font package is **not** committed (see §8) and
is not required by this build at all. Re-running the commands against the same upstream
state reproduces byte-identical output for every file, Mushaf included (verified: two
independent runs produced an identical `assets/quran/mushaf/kfgqpc_v2.json` hash); every
hash in this
document was produced this way and is re-checked by
`test/quran_data/bundled_dataset_integrity_test.dart`,
`test/quran_data/qul_layout_source_test.dart`, and
`test/quran_data/qul_word_by_word_source_test.dart` on every test run.

## Summary table

| Resource | Source | Status |
|---|---|---|
| Canonical Arabic Quran text | Tanzil Project | Integrated |
| Surah metadata + navigation (Juz/Hizb/Rub/Manzil/Ruku/Sajdah) | Tanzil Project | Integrated |
| English translation (Rowwad) | QuranEnc | Integrated |
| German translation (Rowwad) | QuranEnc | Integrated |
| Tafsir Al-Muyassar (Arabic) | QuranEnc | Integrated |
| Mushaf page/line layout (KFGQPC V2) | QUL | Imported (9,046 lines); `SHIP_BLOCKED_LICENSE` for redistribution, not shipped |
| Quran script/word-by-word dataset (word id resolution) | QUL | Imported (83,668 tokens); `SHIP_BLOCKED_LICENSE` for redistribution, not shipped |
| Mushaf glyph font (QCF V2) | QUL | Imported into `assets/quran/fonts/qpc_v2/` + verified manifest (dev builds only); `SHIP_BLOCKED_LICENSE`; not committed to git |
| Surah header decorative font (QUL Surah Header, color) | QUL | Imported + verified for all 114 surahs, confirmed rendering correctly; kept only as an **unused development resource** (superseded by `suracon.ttf`, §15) — `SHIP_BLOCKED_LICENSE`; not committed to git |
| Bismillah decorative font (QCF2BSML) | QUL/KFGQPC | Investigated only — **not wired into rendering**: no verified word→codepoint mapping exists for this font (see §11) |
| Bismillah + title-frame font (`quran_common.ttf`) | AlfaazPlus/QuranApp | Imported + verified; **the active Bismillah/Surah-header-frame mechanism**; `SHIP_BLOCKED_LICENSE`; not committed to git |
| Surah-name calligraphy font (`suracon.ttf`) | AlfaazPlus/QuranApp | Imported + verified for all 114 surahs; **the active Surah-header-name mechanism**; `SHIP_BLOCKED_LICENSE`; not committed to git |
| Verse-by-verse Quran text font (`uthmanic_hafs.ttf` / `UthmanicHafs_V22.ttf`) | AlfaazPlus/QuranApp + QUL (identical file) | Imported + verified; validated defect-free when paired with its own QPC Hafs script (§17); **wired into verse-by-verse rendering**; `SHIP_BLOCKED_LICENSE` |
| Verse-by-verse Quran display script (QPC Hafs word-by-word) | QUL | Vendored, fully audited (83,668 words, 100% match against QPC V2's own word IDs), and **imported + wired into verse-by-verse rendering** (6,235 of 6,236 ayahs; 37:130 excluded, a genuine word-segmentation difference); `SHIP_BLOCKED_LICENSE` (§17) |
| Mushaf page rendering — QCF V2 glyph font (§8) | QUL | **Removed.** The QPC V2 renderer that loaded this font was deleted (`docs/QURAN_ENGINE_MIGRATION.md`); no longer bundled in any build |
| Mushaf page rendering — Quran Engine page corpus | Quran.ws (`quran-ws/quran-engine`) | Imported (full 604-page corpus); `SHIP_BLOCKED_LICENSE` — **same unresolved status as the QCF V2 font it replaced, but shipped anyway in every build including release**, by explicit, recorded product-owner decision. See `docs/QURAN_ENGINE_MIGRATION.md` §10 for exactly what was communicated and accepted, and `docs/THIRD_PARTY_RESOURCES.md` for the resource-register entry. This is the one deliberate exception to this table's otherwise-consistent "`SHIP_BLOCKED_LICENSE` means not shipped" pattern. |

## Release checklist — QUL resource redistribution

**One exception to this whole checklist, recorded here so it is never missed**: the Quran
Engine Mushaf page corpus (`assets/quran/quran_engine/pages/`, Tahfeez's production Mushaf
rendering backend since `docs/QURAN_ENGINE_MIGRATION.md`) carries the exact same
`SHIP_BLOCKED_LICENSE` status as every resource below, but **is** bundled in real release
builds on both Android and Web, with no `kReleaseMode` gate and no build-flavor exclusion.
This was a deliberate, informed decision by the product owner, made only after the specific
redistribution risk was explained and explicitly accepted — see
`docs/QURAN_ENGINE_MIGRATION.md` §10 for the exact exchange. It does not resolve this
resource's license status, and it does not change how every *other* resource in this
checklist must still be handled: the rule below ("no build should reach public distribution
until cleared") still applies to everything else in this file.

**A second exception (owner decision, 2026-10-09)**: the KFGQPC V2 Mushaf layout and
word-by-word data (`assets/quran/mushaf/kfgqpc_v2.json`, §7/§7a) is likewise bundled and
imported in every build, release included — the former `kReleaseMode` gate in
`BundledDatasetSeeder` is removed, because memorization, listening and Hifz need each ayah's
page. Its licence status is unchanged (unverified); the fonts (§8) remain unshipped.

**Do not mark any of these "YES" without source documentation** (an email, a QUL account
license page, or written confirmation from Tarteel AI/Digital Khadeeja Foundation) — never
inferred from CDN accessibility, successful download, or QUL's own MIT-licensed platform
code. The same standard applies to the AlfaazPlus/QuranApp-sourced fonts below: their
repository's GPLv3 license is never assumed to cover these specific font files without
separate, explicit confirmation.

- [ ] QPC V2 layout redistribution cleared (§7)
- [ ] QPC V2 word/script data redistribution cleared (§7a)
- [ ] QPC V2 font redistribution cleared (§8)
- [ ] Surah header decorative font redistribution cleared (§10) — moot unless this
      unused development resource is ever reactivated
- [ ] `quran_common.ttf` redistribution cleared (§14)
- [ ] `suracon.ttf` redistribution cleared (§15)
- [ ] `uthmanic_hafs.ttf`/`UthmanicHafs_V22.ttf` redistribution cleared (§16) — validated
      defect-free when correctly paired (§17), **wired into verse-by-verse rendering**;
      still blocked on license, not on rendering
- [ ] QPC Hafs word-by-word script redistribution cleared (§17) — data fully audited,
      compatible, imported, and **wired into verse-by-verse rendering**; blocked on
      license, not on data quality
- [ ] If any of the above is unresolved: `pubspec.yaml`'s gated asset lines
      (`assets/quran/mushaf/kfgqpc_v2.json`, `assets/quran/manifests/uthmanic_hafs_font.json`,
      `assets/quran/fonts/quranapp/uthmanic_hafs.ttf`,
      `assets/quran/quran_display/qpc_hafs_display_words.json`) have been removed, or moved
      behind a build flavor that a public release build does not include — the
      `kReleaseMode` code-level refusal in `BundledDatasetSeeder`/
      `uthmanicHafsFontManifestProvider`/`qpcHafsDisplayManifestProvider` is **not
      sufficient by itself** (see §8's note on the 204.9MB test release AAB that still
      contained similar gated assets, back when the now-removed QPC V2 font package was
      still declared). The QPC V2 font/manifest lines this bullet used to also list
      (`assets/quran/manifests/qpc_v2_fonts.json`, `assets/quran/fonts/qpc_v2/`,
      `assets/quran/manifests/surah_header_glyphs.json`, `assets/quran/fonts/qcf_surah_header/`,
      `assets/quran/manifests/quran_common_font.json`, `assets/quran/manifests/suracon_glyphs.json`)
      have since been removed from `pubspec.yaml` entirely, along with the renderer that
      loaded them (`docs/QURAN_ENGINE_MIGRATION.md`) — moot now, not merely unchecked.
      **`assets/quran/quran_engine/pages/` is deliberately NOT on this list** — see the
      exception note above this checklist.
- [ ] A `flutter build appbundle --release` (or `ipa`) intended for real distribution has
      been inspected to confirm the gated assets above are actually absent, not just unused
      (this does not apply to the Quran Engine corpus, which is expected to be present —
      see the exception note above)

Until every applicable box above is checked, no build of Tahfeez produced from this
codebase should be uploaded to the Play Store, App Store, or any other public
distribution channel.
