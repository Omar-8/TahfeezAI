# Tahfeez AI — Mushaf Rendering Architecture

This document covers how a printed Mushaf page actually reaches the screen: the
layout/token data pipeline, and the QPC V2 page-specific font system layered on top of
it. For where the underlying data comes from and its license status, see
`docs/QURAN_DATA_PROVENANCE.md` §7/§7a/§8 — this document is about the runtime
architecture, not provenance.

## 1. The rendering pipeline

```
MushafRepository (QuranRepository's Mushaf-scoped methods)
       ↓
MushafPage { pageNumber, lines: List<MushafLine> }
       ↓
for each MushafLine: MushafToken[] (via getLineTokens/getPageTokens,
       batched — never one query per token)
       ↓
QpcPageFontManager.ensureLoaded(mushafId, pageNumber)  — awaited before
       any Quran glyph text for that page is shown
       ↓
MushafPageLayoutEngine.layoutPage(..., fontFamily: <that page's real family>)
       ↓
FontMushafLineRenderer (CustomPainter, one TextPainter per token,
       painted with the loaded page font)
```

This is never `Text`/`RichText` with automatic wrapping. Every token's position is
computed explicitly by `MushafPageLayoutEngine` and painted at an explicit offset —
nothing here can silently reflow a word onto a different line, because no step in this
pipeline ever re-derives line membership from available width. Line membership comes
from exactly one place: the real QUL layout data (`MushafLine.firstTokenId`/
`lastTokenId`), immutable from the moment it is imported.

## 2. Canonical semantics vs. Mushaf presentation stay separate

`MushafToken.displayText` is QCF V2 glyph text — private-use/remapped-Unicode
codepoints meaningful only through that exact page's font (see §4). It is never treated
as, or substituted for, canonical Quran text. Search, copy/share, word-by-word
translation, and AI alignment all read from `AyahWord`/`Ayah` (Tanzil-sourced,
`lib/quran/domain/models/ayah_models.dart`) exclusively. A `MushafToken` only connects
to that canonical layer through its nullable `canonicalAyahId`/`canonicalWordIndex`
(non-null only for `MushafTokenType.quranWord` — never fabricated for a marker; see
`lib/quran/domain/models/mushaf_token_models.dart`).

## 3. Word/token identity for interaction

Every displayed token retains its identity through to the tap handler:

```
Canvas position (tap)
  → MushafWordPlacement (sourceTokenId, tokenType, canonicalAyahId?, canonicalWordIndex?)
  → MushafReaderScreen._showWordInfo
```

For a `quranWord` token, `_showWordInfo` opens the same word-detail sheet
(`lib/wbw/presentation/word_detail_sheet.dart`) the verse-by-verse reader uses, keyed by
the real `(ayahId, wordIndex)` — word-by-word, memorization, and future AI
current-word-highlighting all have a real Quran word to attach to. For an `ayahMarker`/
`otherMarker`/`unknown` token, the tap is a no-op: it renders in place (part of the
authentic printed line) but is not a recited Quran word, so no word lookup opens. The
page is never flattened into a bitmap — every token stays individually hit-testable.

## 4. The QPC V2 page-specific font system

QUL's KFGQPC V2 layout does not use one shared font: **each of the 604 pages has its
own font file**, and — critically — the *same* numeric codepoint draws a *different*
glyph depending on which page's font is loaded (verified directly:
`0xFC41` renders Al-Fatiha's first word under page 1's font and Al-Ikhlas's first word
under page 604's font). A page's `MushafToken.displayText` is therefore meaningless
without that exact page's font active.

### Generated manifest, not filename arithmetic

`tool/quran_data/build_qpc_fonts.dart` reads every `pN.ttf` in the real, vendored QPC V2
font package, parses each file's own embedded `name` table (a from-scratch, dependency-free
TTF parser, `tool/quran_data/src/ttf_inspector.dart` — no external tool assumed
available), and only accepts a page whose **embedded family name** matches the expected
`QCF2<page>` pattern — 604 files checked individually, not three spot checks generalized.
The result is `assets/quran/manifests/qpc_v2_fonts.json`
(`PageFontManifest`/`PageFontManifestEntry`,
`lib/quran/domain/models/page_font_manifest_models.dart`): for every page, its exact
asset path, verified font family, source filename, and content hash. Presentation code
never constructs a filename or family name itself — it only ever looks up a manifest
entry.

### Lazy loading — `QpcPageFontManager`

`lib/features/mushaf/domain/qpc_page_font_manager.dart` defines the abstraction;
`lib/features/mushaf/data/font_loader_qpc_page_font_manager.dart` implements it against
`package:flutter/services.dart`'s `FontLoader` (not `dart:ui` directly — `FontLoader` is
a Flutter Engine helper class, not a `dart:ui` primitive; a common mix-up).

- **`ensureLoaded(mushafId, pageNumber)`** — returns a `PageFontHandle` once that page's
  font is registered. Concurrent calls for the same page share one underlying
  `Future` (an in-flight map keyed by `(mushafId, pageNumber)`), so five widgets
  requesting page 302 simultaneously trigger exactly one `FontLoader.load()`, not five.
- **`preloadAround(mushafId, pageNumber, {radius = 2})`** — fire-and-forget loads of the
  current page's ±1 and ±2 neighbors. Never awaited by a renderer; a slow or failing
  neighbor never delays or breaks the page actually on screen.
- **`isLoaded`/`fontFamilyFor`** — synchronous lookups; `fontFamilyFor` returns the
  manifest's family name whether or not the font has actually been loaded yet, so callers
  must still confirm `isLoaded` (or await `ensureLoaded`) before trusting it in a
  `TextStyle`.
- **No eviction.** Flutter has no supported production API to unregister a font family a
  `FontLoader` has already registered. Once a page's font loads, it stays loaded for the
  process's lifetime; the only lever this design has is controlling *which* pages get
  loaded in the first place (current page ± a small radius), not how long they persist.
  A very long, fast-scrolling session could accumulate many registered font families —
  this is a known, accepted characteristic of the platform, not a bug in this
  implementation. Real memory behavior was checked only within this sandboxed
  environment's `flutter_test` engine (no physical device); see the Milestone 9B/9C
  report for exact numbers and that caveat.

### Race safety under rapid swiping

`mushafPageFontProvider(mushafId, pageNumber)`
(`lib/features/mushaf/application/qpc_page_font_providers.dart`) wraps `ensureLoaded` as
its own Riverpod provider rather than an imperative call inside a widget's `build`.
Riverpod's own provider-family semantics give this the needed race safety for free: a
widget only ever watches the *current* page's provider instance, so if the app is swiped
from page 303 to 305 before 303's font finishes loading, nothing is still watching
303's provider when it resolves — it cannot overwrite what 305 already rendered.

### Rendering type is a real, explicit field

`Mushaf.renderingType` (`MushafRenderingType.pageSpecificGlyphFont` for QUL's KFGQPC V2,
`MushafRenderingType.unicodeText` reserved for a future plain-Unicode Mushaf source) is
checked once per page in `MushafPageView`: a `pageSpecificGlyphFont` Mushaf gates
rendering on `QpcPageFontManager`; a `unicodeText` Mushaf (not implemented by any real
source yet) would skip font-gating entirely, since it has no per-page font concept by
definition.

## 5. Line fitting never moves a word

`MushafPageLayoutEngine` (`lib/features/mushaf/domain/mushaf_page_layout_engine.dart`)
only ever adjusts, per line: font scale (within `[minScale, maxScale]`), inter-token
spacing, and centering vs. justification — never which tokens belong to the line, and
never automatic word wrap. `MushafWordMeasurer.measure` now takes the real `fontFamily`
being rendered with, so the justification math reflects the real glyph widths, not a
fallback font's metrics — presentation-only, still never affecting which words are on
which line.

## 6. Known limitations (honest, not hidden)

- Font load-latency/memory numbers in the milestone report were measured inside this
  sandboxed Linux environment's `flutter_test` engine, not a physical Android/iOS
  device — real-device numbers may differ, especially on lower-end hardware.
- No iOS build could be attempted in this environment (no macOS/Xcode available).
- The `kReleaseMode` gates described above stop the *app* from displaying gated content
  in a release build; they do **not** remove the asset bytes from a naively-built
  release package — see the release checklist in `docs/QURAN_DATA_PROVENANCE.md`.
