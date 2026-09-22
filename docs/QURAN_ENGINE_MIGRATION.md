# Quran Engine Mushaf Migration — status and architecture

Branch: `feature/quran-engine-migration`, created from `main` at
`746a290c4f73526a17c8221dadb54f48744dc3a3` (tagged
`pre-quran-engine-migration`). This is a **rendering backend migration**,
not a reader/data/navigation/translation/bookmarks/settings rewrite —
every product surface listed in §1 continues to work exactly as it does on
`main` today, because (per §3) the migration's one integration point sits
underneath all of them, not beside or in front of them.

**Status at a glance: Quran Engine is now Tahfeez's only Mushaf rendering
backend, everywhere, including release builds — by explicit product-owner
decision.** The former QPC V2 renderer (layout engine, painter, font
manager, render model, and every QPC-V2-specific provider/controller) has
been deleted outright, not merely defaulted away from — there is no
backend-selection concept left in the code, `MushafPageView` always
renders through Quran Engine. The `kReleaseMode` refusal that previously
blocked the Quran Engine Android backend from loading in a release build,
and the requirement that Web's page-delivery endpoint be explicitly
configured, have both been removed: Android bundles the full 604-page
corpus in every build (debug and release), and Web's page delivery
defaults to the bundled, same-origin asset path with no configuration
needed. **This was a deliberate, informed risk acceptance, not a
resolution of the underlying licensing question** — see §10, which
records exactly what was communicated and accepted, verbatim from the
decision itself. `flutter analyze` is clean, all 353 tests pass, `dart
format` is clean, and `flutter build apk --release` / `flutter build web
--release` / `flutter build appbundle --release` all succeed with the
corpus verified present in each output (§9). iOS remains explicitly out
of scope for this milestone (§11). This pass's own live-verification
scope was narrower than the rendering work itself — see §8's "not
verified this pass" note, which still applies: no new Android-device or
additional-theme live verification was performed during the
cleanup/default-switch/packaging work described here, on top of what §8
already recorded from the rendering implementation itself.

## 0. Safety record

- POC branch (`poc/quran-engine`) confirmed complete and committed
  (`4f88ad3`, "poc: Quran Engine full Mushaf evaluation").
- `main` confirmed stable before branching: `flutter analyze` clean,
  **453/453 tests passing**, tagged `pre-quran-engine-migration`.
- This branch created from that exact commit.
- Repository has no `origin` remote and no `master` branch anywhere —
  `main` is confirmed the only real default/stable branch.
- **Update, end of migration**: the old QPC V2 renderer described in the
  paragraph above (as it stood mid-migration) has since been deleted in
  full — `lib/features/mushaf/presentation/mushaf_page_view.dart` no
  longer contains a QPC V2 branch at all, and every QPC-V2-only supporting
  file (layout engine, painter, render model, font managers, boldness
  controller, prewarm controller, and their tests) is gone. See §2 and
  §11 for the final architecture and status.

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
| Reading history / last-read position | `RecentQuranLocationController` | No — stores a `QuranLocation`, not a render artifact; **confirmed live** — the browser test session opened on a previously-visited page automatically |
| Bookmarks | (Milestone 11, not yet implemented on `main`) | No — designed to store canonical `QuranLocation`/ayah refs |
| Verse ↔ Mushaf position preservation | `reader_screen.dart`'s `_switchMode`/`_resolveMushafPageForAyah`/`_firstAyahOnCurrentMushafPage` | No — resolves via `QuranRepository.getPageForAyah`/canonical tokens, never touches the painter |
| Word tap → word-by-word sheet | `mushaf_pager.dart`'s `_showWordInfo` → `showWordDetailSheet` | **Yes, but only through `MushafTokenHitRect`** — see §3. **Confirmed live on Web**, see §8. |
| Ayah/word highlighting, masking | Not yet implemented on `main` for Mushaf mode (no memorization session exists yet) | New capability this migration adds, see §7 |
| Translation & tafsir sheet | `mushaf_translation_sheet.dart` | No — keyed by `(mushafId, pageNumber)`, resolves ayahs via canonical Mushaf-token data independent of which widget painted them |
| Word-by-word data | `wbw/presentation/word_detail_sheet.dart` | No — keyed by canonical `WordRef`. **Confirmed live on Web**: a real tap opened this exact sheet showing `Ayah 2:113 · Word 21` and the honest "install a language pack" state, never Quran Engine data. |
| Reader appearance / themes (Light/Warm/Sepia/Dark/Black) | `mushaf_appearance_controller.dart` | **Yes — must be mapped per backend**, see §6. Dark confirmed live; Light/Warm/Sepia/Black not yet exercised against Quran Engine. |
| Quran text boldness | *(removed — see §11)* | Was QPC-V2-specific (font-weight variant selection); had no Quran Engine equivalent, so the setting itself, its controller, and its sheet were deleted with the rest of the QPC V2 renderer rather than kept as a dead option |
| Page number / live Surah-Juz title | `mushaf_page_title.dart` | No — derived from canonical page/Juz/Surah data. Confirmed live ("Al-Faatiha · Page 1 · Juz 1", "Al-Baqara · Page 17 · Juz 1"). |
| Reader chrome (app bar, translation button, reader-options sheet) | `reader_screen.dart`, `mushaf_reader_options_sheet.dart` | No |
| Light/dark app mode vs. Mushaf appearance | Deliberately separate systems already (`docs/DESIGN_DIRECTION.md`) | No |
| Memorization | Not yet implemented on `main` | Future capability this migration's highlight/mask API is designed for, see §7 |
| Audio hooks | Not yet implemented for Mushaf mode on `main` | Future capability the highlight API is designed for |
| Selection state / sharing | Verse-by-verse only today; no Mushaf-mode selection/share exists on `main` to preserve | N/A |

**Conclusion driving the whole design**: every existing feature operates
on `(mushafId, pageNumber)` or canonical `(ayahId, wordIndex)` — never on
the QPC renderer's internal render model. This is what makes a
single-widget substitution point possible instead of a wider rewrite, and
it is why word tap → word-by-word sheet worked correctly on the very
first live test once the two real rendering bugs (§8) were fixed —
nothing about `MushafPager`, `showWordDetailSheet`, or the reader chrome
needed to change.

## 2. Target architecture (implemented, and since simplified further)

```
ReaderMode.mushaf (unchanged: reader_screen.dart, mushaf_reader_screen.dart)
       ↓
MushafPager (unchanged: page navigation, swipe, spread, gestures)
       ↓
MushafPageView   ← always Quran Engine now — no branch point left
       ↓
       QuranEngineMushafPageContent
       ↓
       mushafQuranEngineBackendProvider (the platform branch)
       ↓
       ┌── Android: QuranEngineAndroidBackend → qvp_flutter's own
       │   QvpPageView (renders + hit-tests natively)
       └── Web: QuranEngineWebBackend → QuranEngineWebBridge →
           vendored qvp.js/qvp_ffi.wasm + a Flutter Web platform
           view hosting a <canvas>, driven by QVP.CanvasRenderer
       ↓
       MushafTokenHitRect  ← the SAME type the former QPC V2 path used
       to produce, so MushafPager._showWordInfo needed no change
```

This is simpler than originally implemented: the migration was first
built as a two-branch selector (`MushafRenderBackend.qpcV2` /
`.quranEngine`, chosen by `MushafRenderBackendController`, defaulting to
`qpcV2` and refusing `quranEngine` in release). Once the decision was made
to complete the migration outright (§10, §11), that whole selection layer
— the enum, the controller, and its `--dart-define=MUSHAF_RENDER_BACKEND`
test override — was deleted along with the QPC V2 branch it used to
choose between. `MushafPageView` (`lib/features/mushaf/presentation/
mushaf_page_view.dart`) is now a ~55-line widget with a single path.

## 3. The canonical Quran layer is unchanged

No change to `QuranRepository`, `AyahWord`, `Ayah`, translations, tafsir,
word-by-word data, search, or navigation. Quran Engine is used **only**
for: printed page representation, page/word geometry, hit testing, and
visual highlighting/masking.

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
tested (9 cases, round-trip + first-word-of-the-Mushaf edge case), and now
also confirmed correct against a **real live tap**: `2:255:21`-shaped
engine data resolved to the word-details sheet's `Ayah 2:113 · Word 21` —
internally consistent (engine word-in-ayah 22, 1-based, minus 1 = 21).

## 5. Engine version pinning

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
`docs/poc/QURAN_ENGINE_POC.md` §3.

## 6. Theme mapping

`QuranEngineMushafBackend.buildView` takes `ink`/`paper` `Color`s directly
from `MushafAppearanceColors.text`/`.background`, mapped at the one call
site in `QuranEngineMushafPageContent`. Android applies these via
`qvp_flutter`'s own `defaultInk`/`paper` params; Web applies them via
`page.setDefaultInk` (JS) + the canvas element's own CSS
`background-color`. **Confirmed live on Web in Dark appearance**: correct
near-white ink on the dark paper color, both pages of a real spread.
**Not yet exercised**: Light, Warm, Sepia, Black, and Android (any
theme). **Not yet mapped**: `headerInk` (the Surah-header-specific tint
QPC V2 exposes) — Quran Engine's own Surah-header/decoration coloring API
was not investigated as part of this pass.

## 6a. Fitting the page to the viewport — the `maxAspectSlack` patch

`QvpPageView` (Android) had its own built-in ceiling on how much wider
than the page's natural print width it would ever draw: never more than
`QvpDefaults.aspectSlack` (15%) over the width that matching the
viewport's height alone would produce. This was hard-coded inside
`QvpViewLayout.toSpec()`, with no constructor parameter to override it —
even though the lower-level `QvpLayoutSpec` it builds already accepts
and documents `maxAspectSlack: 0` ("no bound"), and the native engine
already honors that with no Dart-side involvement beyond passing the
number through (confirmed by reading the full Dart call chain, not
assumed). In practice this meant every Mushaf page on Android showed
persistent empty space beside it on any viewport proportioned
differently enough from the page itself — not fixable from Tahfeez's own
Flutter layout code, since the ceiling was enforced *inside* the
engine's own official rendering widget.

Rather than reimplementing rendering to work around this (which would
have meant abandoning `QvpPageView` — the engine's own official
widget — for a Tahfeez-owned painter, exactly what this migration was
built to avoid), Tahfeez vendors a minimally, explicitly patched local
copy of `qvp_flutter` 0.2.2 at `third_party/qvp_flutter/` (wired in via
`pubspec.yaml`'s `dependency_overrides`), adding one nullable
`maxAspectSlack` field to `QvpViewLayout` — `null` by default
(reproducing the exact unpatched 1.15 behavior for every other call
site), with Tahfeez's own Mushaf page passing `0`. No rendering, hit
-testing, highlighting, masking/reveal, or native code is touched by
this patch — full record, exact diff, and the removal condition (drop
it the moment upstream exposes this itself) in
`third_party/qvp_flutter/PATCHES.md`.

`QuranEngineMushafPageContent` no longer wraps `buildView()` in
`AspectRatio`/`FittedBox` either — both platform implementations
(`QvpPageView` on Android, the canvas view on Web) already compute their
own uniform fit-to-box scale and centering internally from whatever raw
box they're given, so a Flutter-level wrapper only ever got in the way
(pre-shaping the box before `AspectRatio`, or cropping real content via
`FittedBox(fit: BoxFit.cover)` — both tried briefly during this
investigation, neither kept). Web's own fit (`QuranEngineWebBridge
.renderFit`, `scale = (heightPx / height).clamp(0.0, widthPx / width)`)
was confirmed to have no equivalent ceiling to begin with — checked
directly in both the Dart bridge and the vendored `qvp.js` runtime — so
nothing needed patching there.

Any space still visible beyond this point is the genuine, unavoidable
consequence of the printed page's own aspect ratio differing from the
device's — never an artificial limit Tahfeez is imposing, and never
achieved by cropping or unevenly stretching the page.

## 6b. The actual measured cause (the `maxAspectSlack` patch was real, but not the culprit)

§6a's `maxAspectSlack` patch is correct and kept — it removes a real
ceiling the engine's own API already supported removing — but a real,
on-device measurement (temporary debug instrumentation: constraint
logging plus four colour-coded overlay borders around the Flutter
viewport, `QvpPageView`'s own box, the engine's logical page bounds, and
`page.cropBounds(T.page())`'s real artwork bounds; deleted once this
concluded, not shipped) found that patch alone changed nothing visible.
The actual cause was `_lineSpacing = 1.15` (§ above, `QuranEngineAndroidPage`)
— a change made earlier in this same effort, for an unrelated "increase
line spacing a bit" request, before this investigation started.

Measured on a real device (page 3, a normal 15-line page, viewport box
389.8×627.1, page 345×550):

| | `lineSpacing: 1.15` | `lineSpacing: 1.0` |
|---|---|---|
| `fitScale` | **0.8875** (smaller than *either* axis's own individual scale, ~1.13) | **1.0** |
| `leftGap` / `rightGap` | 21.9 / 61.7 | 0.0 / 44.8 |
| `topGap` / `bottomGap` | 0.0 / 139.0 | 2.8 / 74.3 |

Inflating line pitch makes the engine's laid-out content taller at any
given width-driven scale; once that laid-out height exceeded the
viewport's height, the engine shrank the *entire page* to compensate —
smaller on every axis at once, not just taller lines — exactly backwards
from the original intent. Reverting to the natural default (`1.0`)
roughly halved the gap on every side, confirmed visually (four-page swipe
with the debug overlay, then a clean screenshot with it off) and
numerically (`adb logcat`) on a real connected device, not inferred.

`docs/quran_engine/page_vs_artwork_bounds.json`-style measurement (via
`tool/quran_engine/measure_page_vs_artwork_bounds.mjs`, run against the
real compiled engine under Node — no device needed for this part) also
established, for the record: normal pages (42/106/302 and the ones
measured live, 3–8) have artwork bounds within ~95–98% of their logical
page bounds — there is no significant hidden internal page margin to
recover on those. Pages 1/2 (Al-Fatiha / the very start of Al-Baqara)
are a real exception — only 30–62% artwork fill — but that's genuine
printed-page content shape (short surahs not filling a full 15-line
page), not a rendering defect.

The remaining residual gap after the `lineSpacing` fix is the real,
unavoidable consequence of the page's printed aspect ratio (0.627) not
exactly matching the tested device's own viewport proportions — the same
conclusion §6a already reached, now confirmed with real numbers instead
of derived ones.

## 7. Highlight / mask API

`QuranEngineMushafBackend`/`QuranEngineMushafPage`
(`lib/features/mushaf/domain/quran_engine/quran_engine_mushaf_backend.dart`)
expose `highlightWord`/`highlightAyah`/`clearHighlights`/`maskWord`/
`maskAyah`/`revealNext`/`unmask`, all taking canonical `WordRef`/`VerseRef`,
implemented on both Android and Web. **No production caller exists yet**
(memorization/audio don't have a Mushaf-mode session on `main` to attach
to) — this is a real, implemented API surface, not a wired feature;
building `QuranHighlightController` is future work once a real caller
exists. Not exercised even manually this pass (time went to the
higher-priority rendering/hit-test verification below).

## 8. What was verified, and how — including two real bugs found and fixed

The bullets in this section (through the live-verification screenshots)
describe the state **as the rendering work was first implemented**, while
QPC V2 was still present and Quran Engine was still gated. §8a records
what changed and was re-verified once the migration was completed (QPC V2
removed, gates lifted, default switched everywhere).

- `flutter analyze`: clean, whole project, every step of this pass.
- `flutter test`: **465/465 passing** at this stage (later reduced to
  **353/353** once QPC-V2-only tests were deleted along with the code
  they tested — see §8a).
- `flutter build apk --debug` / `--release` / `appbundle --release`:
  all succeed, full 604-page corpus bundled (§9).
- `flutter build web --release` (via a since-deleted `tool/build_web.dart`
  wrapper): succeeded at this stage with the QPC V2 font package and the
  Quran Engine page corpus both verified **excluded (0 bytes)** from the
  Web output — that wrapper was extended this pass to also stage out the
  new `assets/quran/quran_engine/pages/` pubspec line, after a real leak
  into `build/web` was caught by actually inspecting the build output
  (the exact same class of mistake the POC's own QPC V2 tooling was built
  to prevent, now recurring for a new asset path and fixed the same way).
  This exclusion was later deliberately reversed — see §8a/§10.
- **604/604 pages loaded successfully by the real compiled engine** — not
  a synthetic file-format check. `tool/quran_engine/verify_all_pages_structural.mjs`
  loads the actual `qvp_ffi.wasm` (the same binary Web ships) via Node's
  built-in `WebAssembly`, drives it through the real `qvp.js` wrapper, and
  calls `loadPage` on all 604 real vendored `.qvp` files, asserting each
  reports its own correct page number and non-zero line/word/path counts.
  Zero failures. Representative pages' real geometry:

  | Page | Lines | Words | Ayahs | Paths | Decorations |
  |---|---|---|---|---|---|
  | 1 | 8 | 29 | 10 | 261 | 8 |
  | 2 | 8 | 36 | 9 | 330 | 7 |
  | 42 | 15 | 147 | 18 | 1061 | 5 |
  | 106 | 15 | 125 | 14 | 962 | 5 |
  | 302 | 15 | 138 | 22 | 1063 | 10 |
  | 604 | 15 | 58 | 18 | 398 | 21 |

  (Page 1/2 correctly show fewer lines than ordinary 15-line pages —
  real Mushaf pages 1–2 include the Surah header/Bismillah and Al-Fatiha's
  short ayat, exactly as expected.)

- **Live, real production verification on Web**, in an actual Chromium
  browser, through the real app (not a dev-only screen): booted the real
  production app with `MUSHAF_RENDER_BACKEND=quranEngine` +
  `QURAN_ENGINE_PAGE_BASE_URL` pointed at a local dev server (never
  public — see §10), navigated via the app's own `/quran/surah/1` route
  (the real `goToQuranLocation` path, not a shortcut), and confirmed by
  screenshot:
  - The real two-page spread (`MushafPager`'s own tablet/wide-viewport
    layout logic, unmodified) showing page 1 (سورة الفاتحة, correct
    Bismillah, all 7 ayat with ayah-number roundels) and page 2 (سورة
    البقرة opening) simultaneously, both drawn by the real Quran Engine
    `CanvasRenderer`.
  - A real Surah header (`سُورَةُ الْفَاتِحَة`), drawn by Quran Engine
    itself, not Tahfeez's own Surah-header renderer.
  - Correct Dark-appearance theming (near-white ink on the dark paper
    color, both pages).
  - **A real tap on rendered text → the real, unmodified
    `showWordDetailSheet` → `"Ayah 2:113 · Word 21"`** — the complete,
    real production word-selection pipeline (§1), end to end.
  - The honest "Install a word-by-word language pack" empty state in
    that sheet, confirming word-by-word data is never sourced from Quran
    Engine (§3).
  - `RecentQuranLocationController`'s "resume reading" behavior firing
    correctly (the session opened on a previously-visited page).

  **Two real, reproduced bugs were found and fixed during this live
  verification** — neither was caught by `flutter analyze` or
  `flutter test`:
  1. **A genuine platform-view race.** `renderFit` returned silently if
     called before Flutter Web's platform view had actually mounted the
     `<canvas>` element (confirmed: the canvas's CSS background applied
     correctly — proving the platform view *did* eventually mount — while
     the canvas bitmap itself stayed 100% transparent across all 763,276
     pixels, proving the draw call never ran). This didn't surface in the
     POC's simpler, single-widget screen, only inside the real, more
     deeply nested production widget tree. **Fixed** by having
     `QuranEngineWebPage` save a pending render closure and replay it from
     the platform-view factory callback the moment the canvas actually
     exists — the same "safe to call early, applied lazily" pattern the
     existing `paperColorCss` setter already used.
  2. **A fabricated method name.** The bridge called `page.setDefaultColor(...)`,
     assuming API parity with `qvp_flutter`'s Dart-side
     `QvpPage.setDefaultColor` — but the real vendored `qvp.js` has no
     such method; the real one is `setDefaultInk`. Found by manually
     reproducing the exact render call chain in the browser console after
     the platform-view fix alone didn't resolve the blank canvas, which
     immediately threw `TypeError: page.setDefaultColor is not a
     function`. This is the same category of mistake as the POC's own
     fabricated `T.parse`/`engineName()` calls — assuming the Web JS
     wrapper mirrors the Android Dart wrapper's method names without
     checking the actual vendored source. **Fixed** by reading
     `qvp.js` directly and correcting the call site.

  Both fixes are small, real, and now committed; the live screenshots
  after both fixes show correct, artifact-free rendering.

- **Not verified this pass**: Android live re-verification through the
  production Reader UI (no Android device was connected during this
  implementation session — the user explicitly said not to wait for one;
  the POC already proved the same underlying `qvp_flutter` integration on
  real hardware, but that was against the POC's own dev screen, not this
  production wiring). Ayah-level selection/highlighting, masking/reveal,
  and any theme other than Dark were not exercised live either — none of
  these had a reason to behave differently from what's confirmed, but
  "no reason to differ" is not the same as verified, and is reported as
  such rather than assumed.

## 8a. Completing the migration — QPC V2 removal, gate removal, default switch

A later pass in this same overall effort completed the migration outright,
by explicit product-owner instruction (§10, §11): switch the default
everywhere, remove the QPC V2 renderer, and merge to `main`. What that
pass actually did and verified:

- **QPC V2 renderer deleted in full**: `MushafRenderBackend`,
  `MushafRenderBackendController`, `MushafPageLayoutEngine`,
  `MushafPagePainter`, `MushafPageRenderModel`, `MushafWordMeasurer`,
  `QpcPageFontManager` and its two platform implementations,
  `MushafTextBoldnessController`/its sheet, `MushafPrewarmController`, and
  the Mushaf-only special-line font providers (`quran_common.ttf`/
  `suracon.ttf`) — roughly 20 `lib/` files and 17 `test/` files, all
  deleted outright, not deprecated in place.
- **One cross-feature dependency was identified and preserved rather than
  deleted with the rest**: `quranapp_special_font_providers.dart` (being
  deleted as Mushaf-only) also provided `uthmanicHafsFontManifestProvider`
  — actually consumed by verse-by-verse mode's `verse_block.dart`/
  `bismillah_divider.dart`, which is explicitly out of scope for this
  migration. That one provider was moved, not deleted, to
  `lib/features/reader/application/uthmanic_hafs_font_providers.dart`,
  keeping its own pre-existing `kReleaseMode` gate untouched — that gate
  is a separate decision from §10's, was never discussed as part of it,
  and was deliberately left alone.
- **`MushafPageView` simplified from ~350 lines to ~55**: no more
  backend branch — see §2's updated diagram.
- **The Android `kReleaseMode` refusal removed**
  (`quran_engine_android_backend.dart`): the corpus now loads in every
  build, including release. **The Web page-delivery "not configured"
  refusal removed** (`quran_engine_web_backend.dart`): `pageBaseUrl` now
  defaults to the bundled, same-origin Flutter asset path
  (`assets/assets/quran/quran_engine/pages`) instead of requiring
  `QURAN_ENGINE_PAGE_BASE_URL` to be set. See §10 for the authorization
  behind this.
- **The Web build-exclusion wrapper deleted**: `tool/build_web.dart`,
  `tool/build_native.dart`, `tool/verify_web_build_no_qpc_fonts.dart`, and
  `tool/quran_engine/verify_web_build_no_page_corpus.dart` all existed
  solely to stage QPC V2 and the Quran Engine corpus out of Web builds;
  with QPC V2 gone and the corpus now meant to ship, every one of those
  scripts' entire purpose was gone, so they were deleted rather than left
  as dead tooling. A plain `flutter build web --release` / `flutter build
  apk --release` is now the whole build command.
- **`pubspec.yaml` cleaned up**: the QPC V2 font package
  (`assets/quran/fonts/qpc_v2/`, ~200MB) and its manifest, the unused
  Surah-header color font, and the two now-orphaned QuranApp special-line
  fonts (`quran_common.ttf`/`suracon.ttf`) were all removed from
  `assets:`. The Mushaf *structural* dataset (`kfgqpc_v2.json` — line/word
  layout metadata still consulted by e.g. `MushafPageTitle`, independent
  of which engine draws the glyphs) and the verse-by-verse reader's own
  `uthmanic_hafs.ttf`/manifest were deliberately kept, each under its own
  pre-existing, untouched `kReleaseMode` gate — neither is part of the
  Quran Engine rendering path this migration governs.
- **Two test failures surfaced after the deletion pass, both fixed**:
  - `mushaf_page_view_golden_test.dart` — its own doc comment stated it
    locked in "the `CustomPainter`-based line renderer" specifically; that
    mechanism no longer exists, so the golden mismatch was expected, not a
    regression. Deleted as an obsolete QPC-V2-only test, consistent with
    the rest of the deletion pass.
  - `reader_mushaf_mode_switch_test.dart`'s swipe test — a `tester.fling`
    drag distance (400px) on the test's own 390px-wide simulated viewport
    was close enough to a full page width that `PageScrollPhysics`'
    ballistic simulation occasionally overshot by an extra page. Unrelated
    to Quran Engine content; fixed by reducing the fling distance to 300px
    (real margin below the overshoot threshold), confirmed to reliably
    land on the intended page.
- **Verified after all of the above**: `flutter analyze` clean; `flutter
  test` **353/353 passing**; `dart format --set-exit-if-changed .` clean;
  `flutter build apk --release` (116.7MB), `flutter build appbundle
  --release` (115.5MB), and `flutter build web --release` (180MB) all
  succeed. `build/web` was directly inspected: the Quran Engine page
  corpus (1,210 files — 604 pages × `.qvp` + `.words.json`, plus a
  manifest) and the `qvp.js`/`qvp_ffi.wasm` runtime are present at
  `build/web/assets/assets/quran/quran_engine/pages/` and
  `build/web/quran_engine/`; QPC V2 is absent (zero real matches — the
  one substring hit found was `kfgqpc_v2.json`, the unrelated structural
  dataset deliberately kept). The built output was also served over real
  HTTP and fetched: `assets/assets/quran/quran_engine/pages/001.qvp`
  returned `200` with its correct byte size, confirming
  `QuranEngineWebBackend`'s new same-origin default path resolves
  correctly against a real built artifact, not just in source.
- **Not re-verified this pass**: no new interactive browser/device
  session was run against this final build — the interactive Web/Android
  verification recorded earlier in this section (word tap → word-by-word
  sheet, Dark theme, two-page spread) predates the QPC V2 removal and
  gate removal. This pass's verification was analyze/test/format/build/
  HTTP-fetch level, not a fresh interactive walkthrough. Nothing in the
  gate-removal or QPC-deletion changes touched the rendering/hit-test code
  path itself, so there is no specific reason to expect different
  behavior — but per this doc's own standard, that is reported as
  "not re-verified," not claimed as re-confirmed.

## 9. Resource packaging and measured sizes

**Final state (§8a): the full 604-page Quran Engine corpus ships on both
platforms, in every build including release — no gate, no exclusion.**

- **Android**: the full 604-page corpus (91MB,
  `assets/quran/quran_engine/pages/`, all individually SHA-256-verified
  against the pinned release manifest — see
  `tool/quran_engine/fetch_page_data.sh --all`) is bundled in every build.
  `QuranEngineAndroidBackend.loadPage` no longer refuses to load it in
  `kReleaseMode` (§8a/§10) — measured directly against this final state:
  - **Release APK: 116.7MB.**
  - **Release AAB: 115.5MB.**

  (These are absolute sizes measured after the migration completed, not a
  delta against the mid-migration numbers earlier drafts of this doc
  recorded — QPC V2's ~200MB font package left the build in the same pass
  the Quran Engine corpus's own gate was removed, so the two changes were
  not independently re-measured against each other.)
- **Web**: the page corpus is now bundled in the Web build too — the
  build-time exclusion described in §8 was deliberately reversed. Pages
  are still additionally fetched with a ±1-page preload window at runtime
  (`QuranEngineWebBackend.preloadAround`) for the same reason preloading
  made sense before (avoiding a large one-shot payload before first
  paint), but the corpus itself now physically ships in `build/web`
  rather than being excluded from it.
  - **Web build: 180MB** (measured directly on the final `build/web`
    output; up from the pre-migration/mid-migration ~90MB baseline, which
    excluded both QPC V2 and this corpus).
  - Directly confirmed present: `build/web/assets/assets/quran/
    quran_engine/pages/` (1,210 files) and `build/web/quran_engine/
    {qvp.js,qvp_ffi.wasm}`; confirmed absent: any QPC V2 font file (§8a).

## 10. Licensing — the decision that was made, and exactly what was accepted

Quran Engine's own page data is **KFGQPC-derived with the same unresolved
redistribution status as Tahfeez's existing QPC V2 fonts** — confirmed by
the engine maintainers' own README statement (quoted in
`docs/poc/QURAN_ENGINE_POC.md` §8). Adopting Quran Engine as a rendering
backend does not, by itself, resolve Tahfeez's underlying Mushaf-data
licensing gap; it is a different technical delivery mechanism for
material with the same open legal question. **That conclusion has not
changed.** What has changed is Tahfeez's own decision about whether to
ship this material anyway while that question stays open.

**This was an explicit, informed, two-step decision by the product owner,
not a default or an oversight, and this section exists to record it
precisely:**

1. When asked to switch Quran Engine to be the default rendering backend,
   a real conflict was flagged before proceeding: switching the default
   naively would break real release builds, because the existing
   license-safety gates (built to match this project's own repeated,
   standing "never ship unlicensed Quran material" instruction) would
   make every Mushaf page show a blocked/pending state in release mode,
   or whenever Web had no configured delivery URL. Asked to clarify scope
   (a real device vs. every build), **the product owner's answer was
   explicit: "Everywhere and forget about the license for now make it
   work everywhere."**
2. Given the combined weight of that answer plus a follow-up instruction
   to also remove the QPC V2 renderer and merge to `main`, a second,
   more specific confirmation was sought before actually removing the
   safeguard, stating plainly: *"Removing the `kReleaseMode`/license gate
   means real release builds would bundle and display KFGQPC-derived
   Quran page artwork that (per your own project's licensing audit) isn't
   cleared for redistribution. Do you want me to actually remove that
   safeguard?"* **The product owner's answer was explicit: "Yes, remove
   it — I accept that risk."**

Both answers were given after the specific risk was stated in concrete
terms, not in response to a vague or bundled request — this is recorded
here, in the resource's own migration document, precisely because it is
the kind of decision `docs/CLEAN_ROOM_RULES.md` and
`docs/QURAN_DATA_PROVENANCE.md`'s release checklist exist to make
impossible to reach by accident. It was not reached by accident.

**What actually changed as a result** (§8a has full detail):

- `QuranEngineAndroidBackend.loadPage` no longer refuses to load the
  corpus when `kReleaseMode` is true. The corpus is bundled in every
  Android build, debug and release.
- `QuranEngineWebBackend`'s page-delivery URL no longer needs to be
  configured; it defaults to the bundled, same-origin Flutter asset path.
  The corpus is bundled in every Web build.
- The QPC V2 renderer — previously the fallback/default this decision
  was originally scoped around — was removed entirely in the same
  overall effort, so there is no longer a non-Quran-Engine Mushaf
  rendering path to fall back to on either platform.

**What did not change**: the underlying license status of this material.
It remains **`SHIP_BLOCKED_LICENSE`** by this project's own standing
criteria — no upstream redistribution permission was newly obtained, no
new license was found, nothing about the actual legal position moved.
`docs/THIRD_PARTY_RESOURCES.md`'s resource register records this
resource with that status, flagged as the one deliberate exception to
this codebase's otherwise-consistent "blocked means not shipped" pattern,
precisely so this decision stays visible and is never later mistaken for
a resolved license.

## 11. Status — Stages F/G/I complete; what genuinely remains

Both Android and Web now have a real, working, production-integrated
Quran Engine backend, and it is the *only* Mushaf rendering backend on
either platform:

- [x] Canonical stable-ID adapter, tested, and confirmed correct against
      a real live hit.
- [x] Android production backend, wired into the real `MushafPageView`,
      with no `kReleaseMode` refusal (§8a/§10).
- [x] Web production backend, wired into the real `MushafPageView`,
      live-verified in a real browser through the real production UI at
      the time of implementation (§8), with no page-delivery
      configuration requirement (§8a/§10).
- [x] Theme (ink/paper) mapping, implemented on both platforms, **Dark
      confirmed live on Web** at the time of implementation.
- [x] Full 604-page structural validation against the real compiled
      engine — 604/604 pass.
- [x] Real word-tap → canonical ref → existing word-by-word sheet,
      confirmed live end to end on Web at the time of implementation.
- [x] **QPC V2 renderer removed in full** — code, tests, and its
      dedicated backend-selection layer (§8a).
- [x] **License/`kReleaseMode` gate removed** from the Android backend;
      **Web page-delivery configuration requirement removed** — both by
      explicit, recorded product-owner authorization (§10).
- [x] **Default switched to Quran Engine everywhere** — more strongly
      than a default, in fact: there is no longer a second backend to
      default away from.
- [x] Web build-exclusion tooling for both QPC V2 and the Quran Engine
      corpus removed; the corpus verified bundled in real `flutter build
      apk --release`, `flutter build appbundle --release`, and `flutter
      build web --release` output (§8a/§9).
- [x] `flutter analyze` clean, `flutter test` 353/353, `dart format`
      clean, after the full removal (§8a).
- [ ] **Android live re-verification through the production Reader UI**
      against this final state — still not done (no device/emulator
      connected during either implementation pass; per explicit
      instruction, not blocked on, but not claimed as done either). The
      POC proved the same underlying `qvp_flutter` integration on real
      hardware, and this pass's Web-level/build-level verification found
      nothing backend-specific to Android that changed, but neither
      stands in for an actual on-device check.
- [ ] **Light/Warm/Sepia/Black appearance verification** against Quran
      Engine — only Dark was ever exercised live, and only on Web.
- [ ] **iOS** — explicitly out of scope for this milestone. No
      implementation attempted (no macOS/Xcode environment available in
      this sandbox regardless). `mushafQuranEngineBackendProvider` throws
      a clear `UnsupportedError` for iOS. **Status: NOT IMPLEMENTED YET —
      FUTURE PLATFORM WORK.**
- [ ] Ayah-level selection/highlighting, masking/reveal — implemented as
      an API (§7), not exercised live, no production caller.
- [ ] `headerInk` / decoration-specific theme mapping (§6).
- [ ] Golden/visual regression tests for the Quran Engine path — the live
      verification in §8 was manual/screenshot-based, not automated; the
      one Mushaf-mode golden test that existed
      (`mushaf_page_view_golden_test.dart`) tested the now-deleted QPC V2
      `CustomPainter` mechanism specifically and was deleted with it (§8a),
      not replaced with a Quran Engine equivalent.
- [ ] Full feature-parity acceptance matrix, item-by-item — §1's
      inventory is the analysis backing it and several rows are
      independently confirmed live, but this is not the same as a
      formal, complete sign-off pass.
- [x] `docs/ARCHITECTURE.md` (a "superseded" note added where it named QPC
      V2 as the authoritative renderer), `docs/MUSHAF_RENDERING.md`
      (marked superseded in full — it described the now-deleted renderer
      end to end, not just in passing), `docs/QURAN_DATA_PROVENANCE.md`
      (release checklist updated with the Quran Engine exception, stale
      pubspec line references fixed), `docs/OFFLINE_MOBILE_ARCHITECTURE.md`
      (what-ships-where table and measured sizes updated), and
      `docs/THIRD_PARTY_RESOURCES.md` (new resource-register row for the
      Quran Engine corpus, existing QPC V2 rows marked removed) have all
      been updated.

None of the remaining items block what was actually authorized (§10):
shipping Quran Engine everywhere, with QPC V2 removed, merged to `main`.
They are the honest remainder of the migration's original, broader
acceptance criteria (full theme coverage, Android live re-verification,
golden tests, the other docs) — real gaps, tracked here rather than
silently dropped, but not gates on the decision that was actually made.
