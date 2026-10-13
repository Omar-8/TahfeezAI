# TahfeezAI — Mushaf Rendering Architecture (SUPERSEDED — describes the removed QPC V2 renderer)

**This document is historical.** It describes the QPC V2 `CustomPainter`-based
line-shaping renderer (`MushafPageLayoutEngine`/`MushafPageRenderModel`/`MushafPagePainter`
and the page-specific `QpcPageFontManager`) that was Tahfeez's Mushaf rendering backend
through Milestone 9C. That renderer, and every file this document describes below, **has
since been deleted in full** and replaced by Quran Engine
(`quran-ws/quran-engine`) as Tahfeez's only Mushaf rendering backend — see
`docs/QURAN_ENGINE_MIGRATION.md`, whose §2 has the current architecture diagram and whose
§8a records exactly what was removed. Nothing below this notice reflects the current
codebase; it is kept only as a record of the design this migration replaced, since the
shaping-cost/caching decisions it documents (shape once per line, cache the render model,
one `CustomPainter` per page) were real, deliberate engineering choices worth preserving
the reasoning for, even though the specific classes no longer exist.

For where the Mushaf-mode Quran text/layout data itself comes from and its license
status (independent of which engine renders it), see `docs/QURAN_DATA_PROVENANCE.md`
§7/§7a/§8.

---

*Original document follows, describing the now-removed QPC V2 renderer:*

## 1. The rendering pipeline

Shaping happens once per **line**, not once per word — a page has 8–15 lines but can
have 100+ words, and Arabic text shaping (`TextPainter.layout()`) is real, non-trivial
engine cost that must not scale with word count:

```
MushafRepository (QuranRepository's Mushaf-scoped methods)
       ↓
MushafPageBundle { pageNumber, lines: List<MushafLine>, tokensByLineNumber }
       ↓
QpcPageFontManager.ensureLoaded(mushafId, pageNumber)  — awaited before
       any Quran glyph text for that page is shown
       ↓
MushafPageLayoutEngine.layoutPage(...)  — one pass over concatenated
       per-line text (joinMushafLineText) to decide each line's font
       scale/spacing; never measures per token
       ↓
buildMushafPageRenderModel  — shapes each line's full token sequence as
       ONE TextPainter (unconstrained maxWidth, so it structurally cannot
       wrap), then recovers every token's own on-screen rect from that one
       shaped paragraph via TextPainter.getBoxesForSelection — never by
       computing positions by hand
       ↓
MushafPageRenderModel { lines: List<MushafLineRenderModel>, size }
       — cached by a keepAlive Riverpod provider keyed on everything that
       actually changes what gets shaped (mushafId, pageNumber, viewport
       size, font, appearance colors, locale) — an unrelated widget
       rebuild reuses the same instance, never re-shapes
       ↓
MushafPagePainter — ONE CustomPainter for the whole page, wrapped in a
       RepaintBoundary, CustomPaint(isComplex: true, willChange: false).
       Painting only calls each line's already-shaped TextPainter.paint()
       at its precomputed offset — no shaping, measurement, or font
       loading happens on a scroll/paint frame.
```

This is never `Text`/`RichText` with automatic wrapping, and every line is laid out
with `maxWidth: double.infinity` specifically so it is structurally impossible for the
engine to wrap a line onto another visual row — line membership comes from exactly one
place, the real QUL layout data (`MushafLine.firstTokenId`/`lastTokenId`), immutable
from the moment it is imported. See `lib/features/mushaf/presentation/
mushaf_page_render_model.dart` and `mushaf_page_painter.dart` for the concrete
implementation, and `lib/features/mushaf/presentation/mushaf_layout_providers.dart` for
the caching provider.

## 2. Canonical semantics vs. Mushaf presentation stay separate

`MushafToken.displayText` is QCF V2 glyph text — private-use/remapped-Unicode
codepoints meaningful only through that exact page's font (see §4). It is never treated
as, or substituted for, canonical Quran text. Search, copy/share, word-by-word
translation, and AI alignment all read from `AyahWord`/`Ayah` (Tanzil-sourced,
`lib/quran/domain/models/ayah_models.dart`) exclusively. A `MushafToken` only connects
to that canonical layer through its nullable `canonicalAyahId`/`canonicalWordIndex`
(non-null only for `MushafTokenType.quranWord` — never fabricated for a marker; see
`lib/quran/domain/models/mushaf_token_models.dart`).

## 2a. Three text/rendering layers, and why QPC Hafs was evaluated and rejected for Mushaf mode

Tahfeez deliberately keeps three separate Quran text/rendering layers, never collapsed
into one:

| Layer | Role | Font |
|---|---|---|
| **Tanzil** (`AyahWord`/`Ayah`) | Canonical semantic Quran — search, copy/share, references, integrity validation | Any Arabic-capable system font |
| **QPC Hafs** (`docs/QURAN_DATA_PROVENANCE.md` §16) | Verse-by-verse/Ayah mode's scalable Unicode display text | `UthmanicHafs_V22.ttf` |
| **QPC V2** (`MushafToken`, §2 above) | Authentic, page-faithful printed-Mushaf presentation | 604 page-specific glyph fonts (§4) |

All three map to the same stable `(surah, ayah, word)` identity but are never
substituted for one another — see §2 above for why `MushafToken.displayText` (QPC V2)
never leaks into canonical/search code, and `docs/QURAN_DATA_PROVENANCE.md` §16 for why
QPC Hafs display text never replaces `AyahWord` as the canonical source either.

**QPC Hafs was formally evaluated as a possible replacement for QPC V2 in Mushaf mode,
and rejected — a measured, intentional decision, not unfinished migration work.** A
compatibility audit (vendored `qpc-hafs-word-by-word.db` + `UthmanicHafs_V22.ttf`,
confirmed byte-identical to `uthmanic_hafs.ttf`) found:

- **Data compatibility: PASS.** `qpc-hafs-word-by-word.db`'s `words(id, surah, ayah,
  word, text)` table has the exact same `id` domain (1–83668) and identical
  `surah`/`ayah`/`word` values for every `id` as the QPC V2 word-by-word script already
  used to build the production Mushaf dataset — verified for all 83,668 rows, not
  sampled. Every `first_word_id`/`last_word_id` in the existing 15-line layout resolves
  against it with zero missing references, zero duplicates, and zero gaps across all 604
  pages.
- **Unicode rendering correctness: PASS, when correctly paired.** An earlier attempt to
  use `uthmanic_hafs.ttf` for verse-by-verse text found a real defect: U+06DF rendered as
  an oversized black circle. Re-tested against the QPC Hafs script's *own* text (which
  encodes the same phonetic phenomenon as U+0652 instead of U+06DF), the defect did not
  reproduce, and real-font-rendered spot checks across all 19 distinct Quranic annotation
  marks the corpus actually uses (U+06D6–U+06ED) showed no oversized/malformed glyphs.
  The original defect was a text/font mismatch (Tanzil text through a font paired with a
  different script), not an intrinsic font defect.
- **Page-faithful QPC V2 visual fidelity: FAIL / NOT EQUIVALENT.** Direct side-by-side
  rendering of the same pages (1 and 2) through the real production `p1.ttf` vs.
  `UthmanicHafs_V22.ttf` showed QPC Hafs is a clean, correct, but visually plainer,
  more generic Uthmani typeface — it does not reproduce QPC V2's more elaborate
  traditional Madinah-Mushaf letterforms or its per-page hand-tuned justification (QPC
  V2 uses 604 individually-kerned fonts specifically to achieve exact per-line
  justification; QPC Hafs is one reusable font and cannot match that).

Conclusion: QPC Hafs is the validated choice for verse-by-verse/Ayah mode (§16), but
Mushaf mode keeps QPC V2 as its authoritative renderer. Do not attempt this migration
again without new evidence changing the visual-fidelity finding above.

## 3. Word/token identity for interaction

Every displayed token retains its identity through to the tap handler — recovered from
the line's one shaped paragraph, never computed by hand:

```
Canvas position (tap)
  → MushafTokenHitRect (rect, sourceTokenId, tokenType, canonicalAyahId?, canonicalWordIndex?)
       — rect comes from TextPainter.getBoxesForSelection on the line's
         single shaped paragraph, one call per token's known character
         range within it
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

## 5. Render-model prewarming — the font manager's counterpart for shaping

Loading a page's font (§4) is only half the cost of preparing a page for paint; the
other half — line-level shaping, `buildMushafPageRenderModel` — used to only happen
lazily, whenever some widget first watched `mushafPageRenderModelProvider` for that
page. `MushafPagePrewarmController`
(`lib/features/mushaf/presentation/mushaf_prewarm_controller.dart`) makes that shaping
happen proactively, on the same navigation window `QpcPageFontManager.preloadAround`
already uses, so a swipe's destination page never pays its own shaping cost on its own
first frame.

```
MushafPageView (the pager's one authoritative current page only —
see MushafPageView.isCurrentPage's doc comment for why every
pre-built neighbor widget must NOT also trigger this)
       ↓ (after the current frame, never synchronously from build)
MushafPagePrewarmController.prewarmAround(currentPage, ±1, ±2)
       ↓ priority 1: current page (awaited)
       ↓ priority 2: page ±1 (awaited together, after priority 1)
       ↓ priority 3: page ±2 (fire-and-forget — never delays 1/2)
mushafPageRenderModelPrewarmProvider(page)  — one per target page
       ↓ await that page's real data (mushafPageDataProvider)
       ↓ await that page's real font (mushafPageFontProvider) —
         font loads BEFORE shaping, never the other way around
mushafPageRenderModelProvider(page, ...)  — the same keepAlive
       cache MushafPageView itself reads; by the time a swipe
       lands, this is a synchronous cache hit, not a fresh build
```

- **Only the current page drives prewarming.** `PageView.builder`'s
  `allowImplicitScrolling`/`scrollCacheExtent` (`mushaf_pager.dart`) keep neighboring
  pages' `MushafPageView` widgets built too — if *every* one of them called
  `prewarmAround` with its own page number as "current," the controller's
  single-target tracking would thrash between competing pages every frame and never
  settle (a real bug, caught by a `pumpAndSettle` timeout during this work, not
  theoretical). `MushafPager` tracks its own authoritative current page and only marks
  that one `MushafPageView.isCurrentPage: true`.
- **Concurrency and dedup are free.** `mushafPageRenderModelPrewarmProvider` is a plain
  (auto-dispose) Riverpod family provider — two concurrent requests for the same
  `(mushafId, pageNumber, availableWidth, availableHeight)` share Riverpod's own one
  in-flight `Future`, never triggering the warm-up work twice. The value that actually
  needs to persist is `mushafPageRenderModelProvider`'s own `keepAlive` cache entry,
  which this populates as a side effect — the prewarm provider itself has no useful
  lifetime beyond that.
- **Staleness never corrupts cache state.** A rapid multi-page swipe bumps an internal
  generation counter, which stops *scheduling further tiers* for a now-superseded
  target — but every warm operation is keyed by its own explicit page number, never a
  shared mutable "current" slot, so a late-completing stale `Future` can only ever
  populate *its own* page's correct cache entry. Cross-page corruption (page N's model
  ending up associated with page N+1) is structurally impossible by this design, not
  merely tested against.
- **Bounded memory.** `MushafPagePrewarmController` tracks which pages it believes are
  warmed and evicts (`ref.invalidate`) any whose cache entry falls outside
  `[currentPage - 2, currentPage + 2]` once a new page becomes current —
  `mushafRenderModelWindowRadius`, kept as one named constant so the prewarm radius and
  the retention radius can never drift apart. This applies only to
  `mushafPageRenderModelProvider` (the heavy one: many `TextPainter`s and hit-rect
  lists) — never `mushafPageDataProvider` (cheap, kept for the app's lifetime, per its
  own doc comment) and never font registration (fonts are never unloaded — see §4's
  "No eviction" note, which still applies unchanged).
- **Disposal races are expected, not bugs.** Every `await` inside the prewarm chain is
  followed by a `ref.mounted` check before any further `ref` use — the widget tree (and
  so this whole provider scope) can legitimately be torn down mid-prewarm (navigating
  away, backgrounding the app) while a lower-priority tier is still in flight; that must
  return quietly, never throw.
- **What this doesn't do.** No `ui.Picture`-level page caching (a further "second
  stage" some specifications describe) — this is scoped to line-level shaping plus
  render-model memoization; revisit only if real-device profiling shows it's still
  needed. No font unloading (deliberately never attempted — see §4).
- **What was NOT measured.** This mechanism's correctness (ordering, dedup, staleness,
  window bounds) is proven by
  `test/features/mushaf/presentation/mushaf_prewarm_controller_test.dart`, entirely at
  the provider level. Whether it actually produces smooth scrolling on a real device has
  **not** been measured — see §8's "Known limitations." A passing unit test here is not
  a claim about real frame timing.

## 6. Line fitting never moves a word

`MushafPageLayoutEngine` (`lib/features/mushaf/domain/mushaf_page_layout_engine.dart`)
only ever adjusts, per line: font scale (within `[minScale, maxScale]`), inter-token
spacing, and centering vs. justification — never which tokens belong to the line, and
never automatic word wrap. It measures each line's tokens as one or two concatenated
strings (`joinMushafLineText`), never once per token — `MushafWordMeasurer.measure`
takes the real `fontFamily` being rendered with, so the justification math reflects the
real glyph widths, not a fallback font's metrics — presentation-only, still never
affecting which words are on which line. `TextStyle.wordSpacing` *adds to* however wide
the font renders a bare separator character rather than replacing it, so the renderer
measures that separator's own width and subtracts it before passing a value to
`wordSpacing` — see `MushafLineLayout.spacing`'s doc comment for the full reasoning;
getting this wrong does not overflow visibly with most fonts (a real page font's space
is a thin sliver) but is a real correctness issue regardless of font.

## 7. Special lines: Surah headers and Bismillah

A `MushafLine` is one of three `MushafLineType`s, each rendered through a genuinely
different mechanism inside `buildMushafPageRenderModel`
(`mushaf_page_render_model.dart`) — never all through the ordinary Quran-word path:

- **`quranText`** — the ordinary path described above.
- **`surahHeader`** — QUL's layout data carries no glyph/word range for this line (it's
  a heading, not recited text), only a `surahNo`. The **active** mechanism
  (`_buildQuranAppSurahHeaderLine`) is a layered composition reimplemented
  independently from studying AlfaazPlus/QuranApp's own `ChapterTitle.kt`/
  `ChapterIcon.kt` (behavior only — never ported code, per
  `docs/CLEAN_ROOM_RULES.md`): a decorative title frame (`quran_common.ttf`, U+E000,
  `SHIP_BLOCKED_LICENSE` — see `docs/QURAN_DATA_PROVENANCE.md` §14) uniform-scaled (one
  scale factor for both axes — aspect ratio always exactly preserved) to reach ~96% of
  the line's available width or the authoritative line height's limit, whichever binds
  first, with the calligraphic Surah name + shared prefix glyph (`suracon.ttf`, §15)
  overlaid on top — sized proportionally to the frame and shifted down from its center,
  both as ratios of QuranApp's own reference proportions, never hard-coded logical
  -pixel constants. Both glyphs are tinted via ordinary `TextStyle.color` at shape
  time — neither font is a color font (no `COLR`/`CPAL`), so unlike the QUL mechanism
  below, no `saveLayer`/`ColorFilter` is needed at all, a real, cheaper paint path.
  Without both fonts bundled, it falls back to plain localized text
  (`isDecorative: false`), a dev-only, clearly non-final state.
  The QUL Surah Header decorative color font mechanism
  (`_buildDecorativeSurahHeaderLine`, `docs/QURAN_DATA_PROVENANCE.md` §10) is **kept as
  an unused development resource** — its code, tests, and assets are not deleted, but
  `mushaf_layout_providers.dart` no longer supplies its resolver, so it never runs in
  production. Whichever mechanism is active, the localized chapter name is always
  carried as `semanticLabel` and exposed as a real accessibility node via
  `MushafPagePainter.semanticsBuilder` — the visible glyph is never the semantics
  source of truth.
- **`bismillah`** — QUL's layout data carries no glyph/word range for this line either
  (confirmed: empty `first_word_id`/`last_word_id` for every `basmallah` row). The
  **active** mechanism (`_buildDecorativeBismillahLine`) renders `quran_common.ttf`'s
  U+FDFD glyph, sized as a ratio of the page's own calibrated font scale (QuranApp's
  reference 36sp against this project's reference base font size — never a hard-coded
  36 logical pixels), centered, and shrunk to fit its line's authoritative box without
  ever adding line height or moving surrounding lines. The real canonical Bismillah
  text (`bismillahText` provider, sourced from Al-Fatiha 1:1 — never a fresh literal)
  is exposed as a real accessibility node — the private-use glyph itself is never the
  semantics source of truth. Without `quran_common.ttf` bundled, it falls back to that
  same canonical text in a plain system font — a dev-only, clearly non-final state, not
  a fabricated substitute. A separate, dedicated `QCF2BSML.ttf` font was investigated
  but is **not** wired into rendering at all: it uses the same per-arbitrary-codepoint,
  one-glyph-per-word encoding as the ordinary QCF2NNN page fonts (confirmed by direct
  rendering tests, not assumed), and no companion word-by-word mapping resource for it
  has been provided — see `docs/QURAN_DATA_PROVENANCE.md` §11 for the full
  investigation and why guessing that mapping was rejected rather than attempted.

## 8. Known limitations (honest, not hidden)

- Font load-latency/memory numbers in the milestone report were measured inside this
  sandboxed Linux environment's `flutter_test` engine, not a physical Android/iOS
  device — real-device numbers may differ, especially on lower-end hardware.
- No iOS build could be attempted in this environment (no macOS/Xcode available).
- The `kReleaseMode` gates described above stop the *app* from displaying gated content
  in a release build; they do **not** remove the asset bytes from a naively-built
  release package — see the release checklist in `docs/QURAN_DATA_PROVENANCE.md`.
- Mushaf scroll-performance frame timing (UI-thread vs. raster-thread slow frames) has
  only been evaluated via widget/golden tests in this sandboxed environment — never via
  `flutter run --profile` or a release APK on a real Android device. Scrolling
  smoothness should not be treated as verified in production until that measurement is
  actually taken.
- Both the active (`quran_common.ttf`/`suracon.ttf`) and unused-development-resource
  (QUL COLR) special-line rendering have been confirmed correct only via Skia's
  software rasterizer on Linux (`flutter test`); neither has additionally been
  confirmed on a real Android/iOS device.
- `quran_common.ttf`/`suracon.ttf`'s redistribution terms are unverified
  (`SHIP_BLOCKED_LICENSE`, `docs/QURAN_DATA_PROVENANCE.md` §14/§15) — AlfaazPlus/
  QuranApp's repository-level GPLv3 is not assumed to cover these specific font files.
- A dedicated `QCF2BSML.ttf` (KFGQPC) font remains investigated but unwired — see §7
  above for why.
