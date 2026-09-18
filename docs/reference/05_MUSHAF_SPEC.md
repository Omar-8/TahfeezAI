# 05 — Mushaf Specification (Reference Behavior)

> Source: `com.quranapp.android.db.entities.quran.{MushafEntity,MushafMapEntity}`,
> `com.quranapp.android.compose.components.reader.Mushaf.kt`,
> `com.quranapp.android.utils.reader.atlas.*`, `com.quranapp.android.utils.reader.QuranTextMeasurer`.
> Behavior only. Pixel-level Mushaf page styling (ruled-page ornament, page-border art) is
> reference-only per `docs/CLEAN_ROOM_RULES.md`.

## 1. Mushaf metadata model

A **Mushaf** (`MushafEntity`) is a distinct pagination/typesetting of the Quran, identified by:
- `mushafId` (int, primary key)
- `mushafCode` (string, unique) — e.g., an Uthmani-Hafs 15-line code, an Indopak code, a KFQPC
  variant code. Exact code values are `NEEDS_VERIFICATION` (not enumerated in the entity file
  itself; resolved at runtime via `QuranScriptUtils`/`toQuranMushafId`).
- `noOfPages` (int) — total physical pages in this Mushaf's pagination (classically 604 for the
  standard 15-line Uthmani Mushaf, but the schema does not hard-code this — it is fully data
  driven per Mushaf, which is exactly what "variable-line support" in `FEATURES.md` requires).
- `linesPerPage` (int) — the Mushaf's fixed line count per page (e.g., 15 lines is a common
  standard; other scripts/editions may use a different fixed count).

Multiple Mushafs coexist in the same `QuranDatabase` at once (one row per script/edition), keyed
by `mushafId`; a user's selected script + script variant resolves to a single active `mushafId`
via `toQuranMushafId(scriptCode, scriptVariant)`.

## 2. Page → line mapping (`mushaf_map`)

Each row of `MushafMapEntity` describes **one physical line on one page of one Mushaf**:

| Column | Meaning |
|---|---|
| `mushafId` + `pageNumber` + `lineNumber` | composite primary key |
| `lineType` | `MushafLineType`: `surah_name`, `ayah`, or `basmallah` |
| `isCentered` | whether this line should be horizontally centered rather than justified — used for chapter-heading lines, Bismillah lines, and (per classical Mushaf typesetting convention) the last line(s) of a Surah or other short lines |
| `startAyahId` / `startWordIndex` | first word this line contains (nullable — null for a pure surah-name or Bismillah line) |
| `endAyahId` / `endWordIndex` | last word this line contains |
| `surahNo` | convenience denormalized chapter number for a `surah_name` line |

This is the authoritative source of "where does each printed line begin and end," including
mid-verse line breaks (a single ayah can span, begin, or end mid-line — the `startWordIndex`/
`endWordIndex` pair captures partial-verse lines precisely). **Line types**:

- `surah_name` — a full line dedicated to the chapter's name/heading ornament.
- `basmallah` — a full line for "In the name of Allah…" before a chapter (never present before
  Chapter 9, and Chapter 1 includes it as its own verse 1 rather than a separate `basmallah` line
  — `NEEDS_VERIFICATION` on exact row-level treatment for Chapter 1, but this matches the reader's
  own Bismillah-insertion rule in verse-by-verse mode, see `docs/reference/04_READER_SPEC.md` §13).
- `ayah` — a line of Quran text (whole verses and/or partial verses).

## 3. Foreign keys and referential behavior

- `mushaf_map.mushafId → mushafs.mushafId`, cascade on delete/update (deleting a Mushaf removes
  its whole page map).
- `mushaf_map.startAyahId` / `endAyahId → ayahs.ayahId`, `SET_NULL` on delete — if the underlying
  Quran text dataset were ever repaired/replaced ayah-by-ayah, page-map rows degrade gracefully
  (become boundary-less markers) rather than being deleted outright, preserving page/line
  structure integrity. This is a deliberate resilience design worth carrying into Tahfeez's own
  schema.

## 4. Rendering pipeline (Mushaf / "Reading" mode)

Implemented as a `HorizontalPager` (one page per swipe) inside `ReaderLayoutPageMode`:

1. A `MushafSession` (view-model-held) tracks: current page number, page count, and a `layout`
   descriptor (script code + derived settings such as whether the script uses ruled-page
   decoration).
2. For each page, `QuranPageItem(pageNo, juzNo, lines, cacheKey)` is built from a list of
   `QuranPageLineItem`s, one of:
   - `Title(lineNo, chapterNo)` — renders a chapter heading line.
   - `Bismillah(lineNo)` — renders a Bismillah line.
   - `Text(lineNo, centered, words, atlasPlacements, layout)` — renders one line of Arabic words,
     annotated with per-word Atlas glyph placement data (§5) and a fitted `TextStyle` + optional
     `centeredGap` computed specifically for that line's width and centering needs.
3. **Line fitting**: each `Text` line carries its own computed `MushafLineLayout` (a fitted
   `TextStyle` sized so that specific line's word content exactly fills the available content
   width, the way a physical Mushaf's typesetting justifies each line edge-to-edge) — this is the
   `QuranTextMeasurer`'s responsibility: measuring/binary-searching a font size (within min/max
   bounds, capped by `MUSHAF_FONT_WIDTH_DP_MAX`) per line so every line of a given page reads at a
   visually consistent, page-filling size, matching classical Mushaf typesetting rather than a
   single fixed font size for the whole page.
4. Page building runs off the Compose UI thread but is keyed by a `MushafPageMeasurementKey`
   (page number, content width in px, density, font scale, and a style hash) so that page layouts
   are cached and only recomputed when a dependency (screen width rotation, font-scale
   accessibility setting, text-size preference) actually changes — an important performance
   pattern, since text-fitting math is expensive per line.
5. Content width is clamped by `MUSHAF_FONT_WIDTH_DP_MAX` even on very wide screens, so Mushaf
   text never stretches to an unreadable line width — directly satisfying
   `docs/DESIGN_DIRECTION.md`'s "constrained reading width" guidance for desktop/tablet.

## 5. Atlas-based glyph rendering (why it exists)

The reference app renders Mushaf Arabic text using a **prerasterized glyph atlas** rather than
(or in addition to) live font shaping, for pixel-perfect adherence to a specific Mushaf's
typesetting at any zoom level and for consistent rendering across devices/OS font-shaping engines.
This is the system Tahfeez's own optional Milestone 7B mirrors conceptually (not by code reuse).

Key pieces:
- **`AtlasBundleEntity`** (`bundle_key` primary key) — one row per downloadable/prebuilt "atlas
  bundle" (a specific script+resolution combination), storing two JSON blobs: `metaJson`
  (manifest: texture pages, glyph index, etc.) and `layerJson` (rendering-layer configuration,
  e.g., ink-color layering for multi-color Mushaf markings such as Waqf signs, if applicable —
  `NEEDS_VERIFICATION` on exact layer semantics).
- **`AtlasWordShapeEntity`** (`bundle_key`+`word`+`page` primary key) — per-word glyph placement
  data (`placementsJson`) either scoped to a specific Mushaf page (when a word's shape/ligature
  choice can differ by page-typesetting context) or global-to-a-word when `page ==
  ATLAS_PAGE_NONE (-1)`.
- **Bundle lifecycle**: `AtlasManager` imports a bundle from a ZIP (`atlas.json` manifest +
  texture PNG pages) either from a bundled app asset (`atlas/<scriptKey>/6x.zip`, i.e. a
  prebuilt/bundled resolution) or a user-triggered download (`AtlasDownloadManager`,
  `AtlasDownloadWorker`), storing PNG texture files on disk under the app's private downloaded-
  data directory and the manifest/placement rows in `ExternalQuranDatabase` (a separate,
  independently-versioned Room database from the canonical `QuranDatabase` — see
  `docs/reference/06_DATA_MODEL_SPEC.md`).
- **`QuranAtlasLoader` / `QuranAtlasBundle` / `QuranAtlasTextureStore`** — runtime loading and
  in-memory caching of a bundle's textures once imported, keyed by `bundleKey`.
- **`AtlasAyahRasterizer`** — the component that turns a verse's word sequence + glyph placements
  into actual draw calls / bitmap composition for a Compose `Canvas`, given an `AtlasGlyphPlacement`
  per word (position/scale/texture-region reference).
- **Fallback**: `QuranWordText`/`QuranTextWbw` compose paths exist as non-atlas (text-shaping-
  based) rendering, implying the atlas path is an enhancement layered over a baseline
  text-rendering capability rather than the only way to render Quran text — Tahfeez should treat
  atlas/glyph-bitmap rendering as an optional, later enhancement over a correct baseline text
  renderer, consistent with the milestone kit's guidance that Milestone 7B is optional and should
  only be attempted after the "regular Mushaf renderer is already correct and stable."

## 6. Ruled-page decoration

`mushafShowsRuledPageDecoration()` (an extension keyed off script code) toggles whether a page
renders classical ruled/framed-page ornamentation. This is a decorative, script-dependent toggle
— Tahfeez may choose whether/how to offer an equivalent ornament toggle, but should not copy the
specific ornament artwork per `docs/CLEAN_ROOM_RULES.md`.

## 7. Scripts and variants

`FEATURES.md` lists three script families: **Uthmani Hafs**, **Indopak**, and **KFQPC (v1 and
v2)**. Each script maps to one or more Mushaf rows (a script can have multiple *variants*, e.g.
different KFQPC versions render as different `mushafCode`s / different atlas bundles). Selecting a
script + variant in Settings (`docs/reference/10_SETTINGS_SPEC.md`) changes the active
`mushafId`, which changes: page count, lines-per-page, the whole page/line map, and (for
atlas-rendered scripts) which atlas bundle must be present.

**Resource-provenance flag**: the cloned reference repository's `inventory/quran_scripts/` and
`inventory/fonts/` directories contain a full KFQPC-style, per-page, private-use-area glyph
encoding of the canonical Quran text (see `docs/reference/09_OFFLINE_RESOURCES_SPEC.md` §5 and
`docs/reference/18_VISUAL_REFERENCE_NOTES.md`'s licensing notes). **Do not copy these font or
glyph-mapping files into Tahfeez.** Tahfeez must independently source or license any Quran
script/font it uses, and must verify redistribution rights before shipping any script asset —
this is exactly the kind of dependency `docs/CLEAN_ROOM_RULES.md` requires recording in
`docs/THIRD_PARTY_RESOURCES.md` before use.

## 8. Touch mapping

Per-word tap targets in Mushaf mode reuse the same `AyahWordEntity`/word-index model as
verse-by-verse WBW taps (`docs/reference/04_READER_SPEC.md` §14), meaning a tap on an atlas-
rendered glyph must be hit-tested against that word's `AtlasGlyphPlacement` bounding region rather
than against a plain text layout — this is a materially harder tap-target problem than
verse-by-verse mode's WBW tap handling, since the glyph position comes from prerasterized
placement data rather than live text layout metrics. Exact hit-testing algorithm is
`NEEDS_VERIFICATION` (not directly inspected).

## 9. Page-level data needed by chrome

The reader's sticky header (`docs/reference/04_READER_SPEC.md` §3) computes, per current page:
chapter name(s) present on the page (`getChapterNamesOnMushafPage`), the page's Juz number
(`getJuzForMushafPages`), and all Hizb numbers touching the page (`getHizbForMushafPages` — a page
can span more than one Hizb boundary, hence a list, deduplicated and sorted). These are derived
from `mushaf_map` + `navigation_ranges` joins, not stored redundantly per page.

## 10. Definition-of-done cross-check for Tahfeez

Per `docs/CLEAN_ROOM_RULES.md`, Tahfeez's own Mushaf implementation (a later milestone) must
achieve equivalent *capability* — variable line count, accurate line-break fidelity to a chosen
script's real typesetting, correct Bismillah/Surah-header line handling, and page/Juz/Hizb
chrome — using an independently sourced/licensed Quran dataset and independently written Flutter
rendering code, not this schema's exact table names or this atlas system's exact file formats.
