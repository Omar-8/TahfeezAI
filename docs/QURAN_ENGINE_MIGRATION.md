# Quran Engine Mushaf Migration — status and architecture

Branch: `feature/quran-engine-migration`, created from `main` at
`746a290c4f73526a17c8221dadb54f48744dc3a3` (tagged
`pre-quran-engine-migration`). This is a **rendering backend migration**,
not a reader/data/navigation/translation/bookmarks/settings rewrite —
every product surface listed in §1 continues to work exactly as it does on
`main` today, because (per §3) the migration's one integration point sits
underneath all of them, not beside or in front of them.

**Status at a glance: Android + Web both genuinely working and live-verified.
Still not switched to default, and not merged.** Quran Engine renders real
Mushaf pages correctly through the full production architecture on both
Android (compiled/tested; last live-verified on real hardware during the
POC, not re-verified live this pass) and Web (compiled, tested, **and
live-verified in a real browser through the actual production Reader UI**
this pass, including a real word tap resolving to the real word-by-word
sheet). The default backend is still `qpcV2`; the old renderer is fully
intact. iOS is explicitly out of scope for this milestone. See §11 for the
exact remaining gate before Stage F (switch default)/G (remove QPC)/I
(merge to `main`) — the honest answer is: not yet, primarily because full
Android live re-verification, all 5 themes, and the full parity matrix
have not all been exercised.

## 0. Safety record

- POC branch (`poc/quran-engine`) confirmed complete and committed
  (`4f88ad3`, "poc: Quran Engine full Mushaf evaluation").
- `main` confirmed stable before branching: `flutter analyze` clean,
  **453/453 tests passing**, tagged `pre-quran-engine-migration`.
- This branch created from that exact commit. The old QPC V2 renderer
  (`lib/features/mushaf/presentation/mushaf_page_view.dart` and everything
  under it) is untouched code, still the default, still fully reachable —
  nothing has been deleted.
- Repository has no `origin` remote and no `master` branch anywhere —
  `main` is confirmed the only real default/stable branch.

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
| Quran text boldness | `mushaf_text_boldness_controller.dart` | QPC-V2-specific (font-weight variant selection) — no Quran Engine equivalent; see §11 |
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

## 2. Target architecture (implemented)

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
       └── MushafRenderBackend.quranEngine (new)
                ↓
                QuranEngineMushafPageContent (new widget)
                ↓
                mushafQuranEngineBackendProvider (new — the platform branch)
                ↓
                ┌── Android: QuranEngineAndroidBackend → qvp_flutter's own
                │   QvpPageView (renders + hit-tests natively)
                └── Web: QuranEngineWebBackend → QuranEngineWebBridge →
                    vendored qvp.js/qvp_ffi.wasm + a Flutter Web platform
                    view hosting a <canvas>, driven by QVP.CanvasRenderer
                ↓
                MushafTokenHitRect  ← the SAME type the QPC path already
                produces, so MushafPager._showWordInfo needs no change
```

Both branches report hits as `MushafTokenHitRect` (unchanged type) and are
selected by `MushafRenderBackendController`
(`lib/features/mushaf/application/mushaf_render_backend_controller.dart`),
defaulting to `qpcV2` and refusing to select `quranEngine` in a release
build. A `--dart-define=MUSHAF_RENDER_BACKEND=quranEngine` boot-time
override (also `!kReleaseMode`-gated) exists purely for reproducible live
verification, so testing this never requires hand-editing the controller.

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

- `flutter analyze`: clean, whole project, every step of this pass.
- `flutter test`: **465/465 passing**.
- `flutter build apk --debug` / `--release` / `appbundle --release`:
  all succeed, full 604-page corpus bundled (§9).
- `flutter build web --release` (via `tool/build_web.dart`): succeeds;
  both the QPC V2 font package and the Quran Engine page corpus verified
  **excluded (0 bytes)** from the Web output — `tool/build_web.dart` was
  extended this pass to also stage out the new
  `assets/quran/quran_engine/pages/` pubspec line, after a real leak into
  `build/web` was caught by actually inspecting the build output (the
  exact same class of mistake the POC's own QPC V2 tooling was built to
  prevent, now recurring for a new asset path and fixed the same way).
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

## 9. Resource packaging and measured sizes

- **Android**: the full 604-page Quran Engine corpus (91MB,
  `assets/quran/quran_engine/pages/`, all individually SHA-256-verified
  against the pinned release manifest — see
  `tool/quran_engine/fetch_page_data.sh --all`) is bundled for local/debug
  builds, mirroring exactly how the existing QPC V2 604-font package is
  already bundled and gated. `QuranEngineAndroidBackend.loadPage` refuses
  to load it when `kReleaseMode` is true (`QuranEngineReleaseModeBlockedException`).
  As with the pre-existing QPC V2 finding in
  `docs/QURAN_DATA_PROVENANCE.md` §8, this code-level refusal does **not**
  remove the asset bytes from a naively-built release package — confirmed
  directly:
  - **Release APK: 207.2MB → 253.2MB** (+46.0MB, matching the corpus size).
  - **Release AAB: 252.1MB**.
- **Web**: the page corpus is fully excluded from the Web build (0 bytes,
  verified — see §8); pages are fetched on demand, one at a time, plus a
  ±1-page preload window (`QuranEngineWebBackend.preloadAround`, mirroring
  `QpcPageFontManager.preloadAround`'s exact role) — never the full
  corpus. The `qvp.js` + `qvp_ffi.wasm` runtime (328KB combined) does ship
  unconditionally in every Web build (files under `web/` are copied
  verbatim by `flutter build web`, outside the pubspec asset-exclusion
  mechanism).
  - **Web build: 90MB, unchanged** from the pre-migration baseline (the
    QPC V2 exclusion already established); Quran Engine adds only the
    328KB runtime.

## 10. Licensing (unchanged conclusion from the POC, repeated deliberately)

Quran Engine's own page data is **KFGQPC-derived with the same unresolved
redistribution status as Tahfeez's existing QPC V2 fonts** — confirmed by
the engine maintainers' own README statement (quoted in
`docs/poc/QURAN_ENGINE_POC.md` §8). Adopting Quran Engine as a rendering
backend does not, by itself, resolve Tahfeez's underlying Mushaf-data
licensing gap; it is a different technical delivery mechanism for
material with the same open legal question.

- The full 604-page Android corpus is gated exactly like every other
  KFGQPC-derived asset in this codebase (kReleaseMode refusal, gitignored,
  not committed) and must not be treated as cleared for public release.
- The Web page-delivery endpoint (`QURAN_ENGINE_PAGE_BASE_URL`) is unset
  by default and was only ever pointed at a local, non-public dev server
  (`127.0.0.1`) during this pass's live verification — never a public
  host. Production Web delivery must remain disabled until redistribution
  permission is cleared, per the migration spec's own explicit
  instruction.
- **Public release readiness: still blocked.** Nothing in this pass
  changes that conclusion for either platform.

## 11. Honest status — exact remaining gate before Stage F/G/I

Both Android and Web now have a real, working, production-integrated
Quran Engine backend. What is genuinely not yet done, and therefore what
blocks switching the default, removing QPC V2, or merging to `main`:

- [x] Canonical stable-ID adapter, tested, and now confirmed correct
      against a real live hit.
- [x] Backend-selection abstraction + controller, defaulting to QPC V2,
      release-mode-safe, with a reproducible `--dart-define` test override.
- [x] Android production backend, wired into the real `MushafPageView`.
- [x] Web production backend, wired into the real `MushafPageView`,
      **live-verified in a real browser through the real production UI**.
- [x] Theme (ink/paper) mapping, implemented on both platforms, **Dark
      confirmed live on Web**.
- [x] Asset gating matching the existing QPC V2 convention exactly, on
      both platforms.
- [x] Full 604-page structural validation against the real compiled
      engine — 604/604 pass.
- [x] Real word-tap → canonical ref → existing word-by-word sheet,
      confirmed live end to end on Web.
- [ ] **Android live re-verification through the production Reader UI**
      — not done this pass (no device connected; not blocked on, per
      explicit instruction, but also not something to claim as done).
- [ ] **Light/Warm/Sepia/Black appearance verification** against Quran
      Engine (only Dark was exercised, and only on Web).
- [ ] **iOS** — explicitly out of scope for this milestone. No
      implementation attempted (no macOS/Xcode environment available in
      this sandbox regardless). `mushafQuranEngineBackendProvider` throws
      a clear `UnsupportedError` for iOS. **Status: NOT IMPLEMENTED YET —
      FUTURE PLATFORM WORK.**
- [ ] Ayah-level selection/highlighting, masking/reveal — implemented as
      an API (§7), not exercised live, no production caller.
- [ ] `headerInk` / decoration-specific theme mapping (§6).
- [ ] Golden/visual regression tests for the Quran Engine path (the live
      verification in §8 was manual/screenshot-based, not automated).
- [ ] Full feature-parity acceptance matrix, item-by-item — §1's inventory
      is the analysis backing it and several rows are now independently
      confirmed live, but this is not the same as a formal, complete
      sign-off pass.
- [ ] `docs/ARCHITECTURE.md`, `docs/MUSHAF_RENDERING.md`,
      `docs/QURAN_DATA_PROVENANCE.md`, `docs/THIRD_PARTY_RESOURCES.md`,
      `docs/OFFLINE_MOBILE_ARCHITECTURE.md` have **not** been updated yet.
- [ ] No cleanup of the old QPC V2 renderer has been done or should be
      done yet.
- [ ] Default backend has **not** been switched to `quranEngine` — `main`
      and this branch both still default to `qpcV2`.
- [ ] **Not merged into `main`.**

Given the size of the remaining gap (Android live check, 4 more themes,
the full parity matrix, doc updates), switching the default or removing
QPC V2 now would be premature relative to the migration's own staged
rollout plan. The technical thesis is proven on both required platforms;
the acceptance gate is not yet fully cleared.
