# Tahfeez AI — Quran Data Provenance

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
- **The missing piece — a companion word/script dataset**: this file's `ayah` lines carry
  only bare integer `first_word_id`/`last_word_id` references into a *separate* QUL
  "Quran script/word database" resource that resolves each id to its actual
  surah/ayah/word-index and glyph text. **That companion file has not been supplied.**
  Without it, `first_word_id`/`last_word_id` cannot be turned into real
  `MushafLine.startAyahId/startWordIndex/endAyahId/endWordIndex` values.
- **What Tahfeez has built regardless**: the full replaceable architecture this layout
  will populate once the word dataset arrives —
  `lib/quran/domain/mushaf_data_source.dart` (`MushafDataSource`, `RawMushafLayout`,
  `MushafWordIdResolver`, `resolveMushafLines`) and
  `tool/quran_data/src/mushaf_layout_source.dart` (`QulKfgqpcV2MushafDataSource`, which
  already reads and structurally validates the real file above). No synthetic or
  placeholder Mushaf line/word content has been generated anywhere, at the explicit,
  repeated instruction of the project owner — the `Mushafs`/`MushafLines` tables remain
  empty in the shipped dataset until the real companion file is imported through this
  same architecture.
- **License**: **unverified**. Per QUL's own FAQ, "the resources available on QUL vary in
  their copyright status... review the licensing terms for each resource" — there is no
  blanket grant, and QUL's platform/codebase being MIT-licensed does **not** extend to
  this specific data resource. The specific redistribution terms for this exact layout
  file have not been independently confirmed (QUL's resource-specific license page is
  only reachable after the same login gate that blocks automated fetching).
- **Status**: `SHIP_BLOCKED_PENDING_WORD_DATA` (missing companion dataset) **and**
  `SHIP_BLOCKED_LICENSE` (redistribution terms not yet independently verified). Per this
  project's rules: this is recorded honestly as blocked, **not** assumed permitted, and
  **not** silently marked "MIT" because QUL's software repository happens to be MIT.
  Resolving either blocker requires the project owner's direct QUL account access.

## 8. Quran script/glyph font — KFGQPC/QCF V2

- **What it is**: the private-use-area glyph font QUL's KFGQPC V2 layout is typeset
  against (each Mushaf page has its own font subset — confirmed via QUL's own CDN URL
  pattern, e.g. `https://static-cdn.tarteel.ai/qul/fonts/quran_fonts/v2/woff2/p574.woff2`).
- **Status**: `SHIP_BLOCKED_LICENSE`. Not downloaded, not bundled, not used anywhere in
  Tahfeez. Its redistribution terms are a **separate** license gate from the layout data
  itself (§7) and have not been researched to a shippable standard — QUL's own FAQ places
  fonts under the same "review per resource, no blanket grant" rule as every other
  dataset category. `docs/reference/05_MUSHAF_SPEC.md` already recorded, before this
  milestone, that a reference-app KFQPC-style font must never simply be copied into
  Tahfeez; this finding is consistent with that and extends it to QUL's redistribution of
  the same font family. Per instruction, this blocker is recorded honestly rather than
  worked around by silently substituting an unrelated font and calling the Mushaf layer
  "done" — the 15-line layout integration itself is not abandoned because of this; it
  simply cannot render real glyphs yet, and currently cannot render anything at all
  because §7's word dataset is also missing.

## 9. Tahfeez-generated data — search indexes

Arabic/translation/Surah search indexes (`lib/quran/data/tables/search_index_tables.dart`,
Milestone 10) are derived entirely from the canonical/translation data above at
index-build time, contain no independently-licensed content, and are not a data
provenance concern — see `docs/ARCHITECTURE.md` §21 for their own design rationale.

---

## Reproducing this dataset

```
dart run tool/quran_data/fetch_sources.dart        # Tanzil + QuranEnc, live network
dart run tool/quran_data/build_production_data.dart # writes assets/quran/*.json
```

The QUL layout file must already exist at
`tool/quran_data/sources/qpc-v2-15-lines.db.zip` (it is committed to this repository,
since it cannot be re-fetched automatically — see §7). Re-running both commands against
the same upstream state reproduces byte-identical `assets/quran/*.json` output; every
hash in this document was produced this way and is re-checked by
`test/quran_data/bundled_dataset_integrity_test.dart` and
`test/quran_data/qul_layout_source_test.dart` on every test run.

## Summary table

| Resource | Source | Status |
|---|---|---|
| Canonical Arabic Quran text | Tanzil Project | Integrated |
| Surah metadata + navigation (Juz/Hizb/Rub/Manzil/Ruku/Sajdah) | Tanzil Project | Integrated |
| English translation (Rowwad) | QuranEnc | Integrated |
| German translation (Rowwad) | QuranEnc | Integrated |
| Tafsir Al-Muyassar (Arabic) | QuranEnc | Integrated |
| Mushaf page/line layout (KFGQPC V2) | QUL | `SHIP_BLOCKED_PENDING_WORD_DATA`, `SHIP_BLOCKED_LICENSE` |
| Quran script/word dataset (word id resolution) | QUL | Not yet supplied |
| Mushaf glyph font (QCF V2) | QUL | `SHIP_BLOCKED_LICENSE` |
