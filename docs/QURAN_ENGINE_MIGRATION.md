# Quran Engine Mushaf Migration — status and architecture

Branch: `feature/quran-engine-migration`, created from `main` at
`746a290c4f73526a17c8221dadb54f48744dc3a3` (tagged
`pre-quran-engine-migration`). This is a **rendering backend migration**,
not a reader/data/navigation/translation/bookmarks/settings rewrite —
every product surface listed in §1 continues to work exactly as it does on
`main` today, because (per §3) the migration's one integration point sits
underneath all of them, not beside or in front of them.

**Status at a glance: Stage 1 in progress, not complete.** Quran Engine is
wired into the real production architecture as a selectable backend
(Android only so far), defaulting to the existing QPC V2 renderer
unchanged. This document is both the architecture record and an honest
punch list of what remains — see §9.

## 0. Safety record

- POC branch (`poc/quran-engine`) confirmed complete and committed
  (`4f88ad3`, "poc: Quran Engine full Mushaf evaluation").
- `main` confirmed stable before branching: `flutter analyze` clean,
  **453/453 tests passing**, tagged `pre-quran-engine-migration`.
- This branch created from that exact commit. The old QPC V2 renderer
  (`lib/features/mushaf/presentation/mushaf_page_view.dart` and everything
  under it) is untouched code, still the default, still fully reachable —
  nothing has been deleted.

## 1. Feature inventory (what must keep working)

Built from reading `lib/features/reader/` and `lib/features/mushaf/` in
full, not assumed:

| Area | Owning file(s) | Depends on rendering backend? |
|---|---|---|
| Mushaf entry point (in-place Reader mode switch) | `reader_screen.dart`'s `_MushafModeScaffold` | No — renders `MushafPager` |
| Mushaf entry point (Quran index "Page" tab → standalone route) | `mushaf_reader_screen.dart` | No — renders the *same* `MushafPager` |
| Previous/next page, swipe, two-page spread, web mouse/keyboard | `mushaf_pager.dart` | No — operates on `MushafPageView` instances by page number only |
| Jump to page / Surah / Juz / Hizb → Mushaf | `quran_location_routing.dart`, `page_index_tab.dart` et al. | No — resolves to `QuranLocation.page(mushafId, pageNumber)`, routes to the entry points above |
| Search result → Mushaf | Quran search + `goToQuranLocation` | No — same `QuranLocation.page` path |
| Reading history / last-read position | `RecentQuranLocationController` | No — stores a `QuranLocation`, not a render artifact |
| Bookmarks | (Milestone 11, not yet implemented on `main`) | No — designed to store canonical `QuranLocation`/ayah refs |
| Verse ↔ Mushaf position preservation | `reader_screen.dart`'s `_switchMode`/`_resolveMushafPageForAyah`/`_firstAyahOnCurrentMushafPage` | No — resolves via `QuranRepository.getPageForAyah`/canonical tokens, never touches the painter |
| Word tap → word-by-word sheet | `mushaf_pager.dart`'s `_showWordInfo` → `showWordDetailSheet` | **Yes, but only through `MushafTokenHitRect`** — see §3 |
| Ayah/word highlighting, masking | Not yet implemented on `main` for Mushaf mode (no memorization session exists yet) | New capability this migration adds, see §7 |
| Translation & tafsir sheet | `mushaf_translation_sheet.dart` | No — keyed by `(mushafId, pageNumber)`, resolves ayahs via canonical Mushaf-token data independent of which widget painted them |
| Word-by-word data | `wbw/presentation/word_detail_sheet.dart` | No — keyed by canonical `WordRef` |
| Reader appearance / themes (Light/Warm/Sepia/Dark/Black) | `mushaf_appearance_controller.dart` | **Yes — must be mapped per backend**, see §6 |
| Quran text boldness | `mushaf_text_boldness_controller.dart` | QPC-V2-specific (font-weight variant selection) — no Quran Engine equivalent; see §9 |
| Page number / live Surah-Juz title | `mushaf_page_title.dart` | No — derived from canonical page/Juz/Surah data |
| Reader chrome (app bar, translation button, reader-options sheet) | `reader_screen.dart`, `mushaf_reader_options_sheet.dart` | No |
| Light/dark app mode vs. Mushaf appearance | Deliberately separate systems already (`docs/DESIGN_DIRECTION.md`) | No |
| Memorization | Not yet implemented on `main` | Future capability this migration's highlight/mask API is designed for, see §7 |
| Audio hooks | Not yet implemented for Mushaf mode on `main` | Future capability the highlight API is designed for |
| Selection state / sharing | Verse-by-verse only today; no Mushaf-mode selection/share exists on `main` to preserve | N/A |

**Conclusion driving the whole design**: every existing feature operates
on `(mushafId, pageNumber)` or canonical `(ayahId, wordIndex)` — never on
the QPC renderer's internal render model. This is what makes a
single-widget substitution point possible instead of a wider rewrite.

## 2. Target architecture (implemented so far)

```
ReaderMode.mushaf (unchanged: reader_screen.dart, mushaf_reader_screen.dart)
       ↓
MushafPager (unchanged: page navigation, swipe, spread, gestures)
       ↓
MushafPageView   ← the ONE branch point (new)
       ├── MushafRenderBackend.qpcV2 (default, unchanged)
       │        ↓ existing pipeline, byte-for-byte untouched
       │        MushafPageLayoutEngine → MushafPageRenderModel → MushafPagePainter
       │
       └── MushafRenderBackend.quranEngine (new, Android only so far)
                ↓
                QuranEngineMushafPageContent (new widget)
                ↓
                mushafQuranEngineBackendProvider (new — the platform branch)
                ↓
                QuranEngineAndroidBackend → qvp_flutter's own QvpPageView
                (renders + hit-tests natively; Tahfeez reimplements nothing)
                ↓
                MushafTokenHitRect  ← the SAME type the QPC path already
                produces, so MushafPager._showWordInfo needs no change
```

Both branches report hits as `MushafTokenHitRect` (unchanged type) and are
selected by `MushafRenderBackendController`
(`lib/features/mushaf/application/mushaf_render_backend_controller.dart`),
defaulting to `qpcV2` and refusing to select `quranEngine` in a release
build — Stage 1's "old renderer stays available and default" requirement,
enforced in code, not just by convention.

## 3. The canonical Quran layer is unchanged

No change to `QuranRepository`, `AyahWord`, `Ayah`, translations, tafsir,
word-by-word data, search, or navigation. Quran Engine is used **only**
for: printed page representation, page/word geometry, hit testing, and
visual highlighting/masking — exactly the boundary the migration spec
requires (§4 of the request).

## 4. Stable ID adapter

Tahfeez already had exactly the "single tested adapter" concept the
migration spec asked for: `WordRef`/`VerseRef`
(`lib/quran/domain/models/quran_refs.dart`, pre-existing, used by
`showWordDetailSheet` and the reader's own mode-switch resolution). Rather
than inventing new `QuranAyahRef`/`QuranWordRef` types duplicating that
concept, **`QuranEngineRefAdapter`**
(`lib/features/mushaf/domain/quran_engine_ref_adapter.dart`) is the one
place Quran Engine's `"surah:ayah"`/`"surah:ayah:word"` key format is ever
parsed, translating directly to/from `WordRef`/`VerseRef`. Fully unit
tested (`test/features/mushaf/domain/quran_engine_ref_adapter_test.dart`,
9 cases, including round-trip and the first-word-of-the-Mushaf edge case).
No other file parses a Quran Engine key.

## 5. Engine version pinning

Unchanged from the POC's own pins (`tool/quran_engine/README.md`):
- Engine source: `quran-ws/quran-engine` commit
  `a19ee9b16ec60689dfd9ef566c49d393f9a47459`.
- Page-data release: `quran-engine-pages-hafs-kfgqpc` v0.3.0
  (`engine_commit: 55d732a4e98e976948014c6dd979e0d6cf94ee8b`, independently
  pinned, not reconciled to the code commit).
- Android wrapper: `qvp_flutter` v0.2.2 (pub.dev).
- Web wrapper: `qvp.js` + `qvp_ffi.wasm`, built reproducibly from the
  pinned source (byte-identical hashes across two independent builds).

Known upstream API drift between the pinned source commit and the
published `qvp_flutter` package (target builders moved to a separate `T`
class, `revealNext` simplified, hit field renames) is documented in
`docs/poc/QURAN_ENGINE_POC.md` §3 and already accounted for in the
production adapter — no undocumented local patch exists.

## 6. Theme mapping

`QuranEngineMushafBackend.buildView` takes `ink`/`paper` `Color`s directly
from `MushafAppearanceColors.text`/`.background` — the same theme values
(Light/Warm/Sepia/Dark/Black) already used by the QPC renderer, mapped at
the one call site in `QuranEngineMushafPageContent`, never hardcoded
inside a backend implementation. `qvp_flutter`'s `QvpPageView` applies
these via its own `defaultInk`/`paper` params (confirmed against the real
package source, not assumed). **Not yet mapped**: `headerInk` (the
Surah-header-specific tint QPC V2 exposes) — Quran Engine's own
Surah-header/decoration coloring API was not investigated as part of this
pass; see §9.

## 7. Highlight / mask API

`QuranEngineMushafBackend`/`QuranEngineMushafPage`
(`lib/features/mushaf/domain/quran_engine/quran_engine_mushaf_backend.dart`)
expose `highlightWord`/`highlightAyah`/`clearHighlights`/`maskWord`/
`maskAyah`/`revealNext`/`unmask`, all taking canonical `WordRef`/`VerseRef`
— ready for a future memorization/audio session controller to call, per
the migration spec's "moving highlight controller" requirement. **No such
controller exists yet** (memorization/audio don't have a Mushaf-mode
session on `main` to attach to) — this is the API surface, not a wired
feature; building `QuranHighlightController` is future work once a real
caller exists.

## 8. What was verified, and how

- `flutter analyze`: clean, whole project.
- `flutter test`: **465/465 passing** (453 pre-existing + 12 new: 9 for
  `QuranEngineRefAdapter`, 3 for `MushafRenderBackendController`).
- `flutter build apk --debug`: succeeds, with the six-page Quran Engine
  corpus vendored and the pubspec asset declared (gated exactly like QPC
  V2's own assets).
- **Not yet verified live**: no Android device was connected during this
  implementation pass (the real arm64 device used for the POC's own
  on-device verification had been disconnected by this point) — the
  Android backend has not been exercised through the *production* Reader
  UI at runtime, only compiled and unit-tested. The POC already proved
  the same underlying `qvp_flutter` integration renders and hit-tests
  correctly on real hardware (`docs/poc/QURAN_ENGINE_POC.md` §6); this
  pass promoted that code to the production architecture and abstraction
  but has **not independently re-confirmed it live through
  `MushafPager`/`ReaderMode.mushaf`**. Do the following before trusting
  this in production:
  ```dart
  // from a debug console / temporary code, never a release build:
  ref.read(mushafRenderBackendControllerProvider.notifier)
     .setBackend(MushafRenderBackend.quranEngine);
  ```
  then open Mushaf mode and check pages 1, 2, 42, 106, 302, 604 (302 has
  no vendored data — expect it to fail loudly, not silently show QPC
  content) plus a real word tap.
- Web build was not attempted this pass (no Web backend exists yet — see
  §9).

## 9. Honest status — what remains (do not treat this migration as done)

This is Stage 1 ("Engine integrated in production architecture, old QPC
still available internally"), and only partially even that:

- [x] Canonical stable-ID adapter, tested.
- [x] Backend-selection abstraction + controller, defaulting to QPC V2,
      release-mode-safe.
- [x] Android production backend, wired into the real `MushafPageView`.
- [x] Theme (ink/paper) mapping for Android.
- [x] Asset gating matching the existing QPC V2 convention exactly.
- [ ] **Live on-device re-verification through the production Reader UI**
      (not done this pass — see §8).
- [ ] **Web backend** — the POC's Web bridge (`quran_engine_web_bridge.dart`,
      `quran_engine_web_adapter.dart`) has not been promoted. Web Mushaf
      mode still only has QPC V2.
- [ ] **iOS** — no implementation attempted (no macOS/Xcode environment
      available in this sandbox, per the spec's explicit instruction not
      to fabricate iOS runtime success). `mushafQuranEngineBackendProvider`
      throws a clear, honest `UnsupportedError` for iOS today.
- [ ] Surah header / Bismillah / ayah marker **visual validation** against
      pages 1, 2, 106, 604 through Quran Engine specifically (the POC did
      this once, informally, via screenshot on pages 1 and 106 — not
      re-verified against this production code path).
- [ ] `headerInk` / decoration-specific theme mapping (§6).
- [ ] `QuranHighlightController` (§7) — API exists, no caller yet.
- [ ] Full 604-page automated structural load test (only 6 representative
      pages are vendored; a full corpus load test needs the full corpus,
      which raises the same licensing question as bundling it for
      production — not resolved).
- [ ] Golden/visual regression tests for the Quran Engine path.
- [ ] Feature parity acceptance matrix (the spec's own 40+-item checklist)
      — not formally run item-by-item; §1's inventory above is the
      analysis backing it, not a substitute for actually exercising each
      one against the Quran Engine backend live.
- [ ] `docs/ARCHITECTURE.md`, `docs/MUSHAF_RENDERING.md`,
      `docs/QURAN_DATA_PROVENANCE.md`, `docs/THIRD_PARTY_RESOURCES.md`,
      `docs/OFFLINE_MOBILE_ARCHITECTURE.md` have **not** been updated yet
      — this document exists alongside them, not merged into them, until
      the architecture is far enough along that doing so wouldn't need
      revising again immediately.
- [ ] No cleanup of the old QPC V2 renderer has been done or should be
      done yet — correctly, per the spec's own staging rules (removal is
      Stage 6, gated behind every acceptance item above).

## 10. Licensing (unchanged conclusion from the POC, repeated deliberately)

Quran Engine's own page data is **KFGQPC-derived with the same unresolved
redistribution status as Tahfeez's existing QPC V2 fonts** — confirmed by
the engine maintainers' own README statement (quoted in
`docs/poc/QURAN_ENGINE_POC.md` §8). Adopting Quran Engine as a rendering
backend does not, by itself, resolve Tahfeez's underlying Mushaf-data
licensing gap; it is a different technical delivery mechanism for
material with the same open legal question. The six vendored pages in
`assets/quran/quran_engine/pages/` are gated exactly like every other
KFGQPC-derived asset in this codebase (§6 above) and must not be treated
as cleared for public release.
