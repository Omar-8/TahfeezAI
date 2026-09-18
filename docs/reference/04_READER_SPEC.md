# 04 — Reader Specification (Reference Behavior)

> Source: `com.quranapp.android.compose.screens.reader.ReaderScreen`,
> `com.quranapp.android.compose.components.reader.*`, `com.quranapp.android.utils.reader.*`,
> `com.quranapp.android.viewModels.ReaderViewModel`. Behavior only — visual chrome, spacing, and
> color are reference-only.

## 1. Entry points and launch parameters

The reader is a single Activity (`ActivityReader`, `singleTask` launch mode) driven by a
strongly-typed `ReaderLaunchParams` (see `docs/reference/06_DATA_MODEL_SPEC.md` for the full
intent-extras contract). It can be launched with exactly one of four intent shapes
(`ReaderIntentData` sealed class):

1. `FullChapter(chapterNo, initialVerse?)`
2. `FullJuz(juzNo, initialVerse?)`
3. `FullHizb(hizbNo, initialVerse?)`
4. `MushafPage(mushafCode, mushafVariant, pageNo, fallbackChapterNo, fallbackVerseNo, initialVerse?)`

Plus optional `readerMode` (verse-by-verse / Mushaf / translation) and `slugs` (translation
selection override for this session only). All four shapes optionally carry an `initialVerse`
target used to scroll straight to a specific verse once content loads.

External entry points that build these intents:
- Custom scheme action `com.quranapp.android.action.OPEN_READER`.
- HTTPS App Link `https://quran.com/...` (juz, chapter, chapter:verse, chapter:verse-range
  patterns) — see `docs/reference/16_PLATFORM_FEATURES_SPEC.md`.
- Internal call sites: Home (featured reading, read history, recommendations), Search results,
  reference-content collections, bookmarks.
- `ReaderLaunchParams.toInitSignature()` produces a stable string key (data+mode+slugs) used to
  detect "is this actually a different reading session" and avoid redundant reloads when an
  Activity is re-delivered the same intent.

## 2. Reading modes

Three modes, switchable at any time from the reader's own toolbar (see §4), backed by a single
enum `ReaderMode { VerseByVerse, Reading, Translation }`:

- **VerseByVerse** — a vertically scrolling list of verse blocks, each with its own per-verse
  action bar (§5), Arabic text, and (depending on settings) inline translation.
- **Reading** — Mushaf (paginated) mode: a horizontal pager of fixed Mushaf pages rendered line
  by line, matching the physical printed page's line breaks (see
  `docs/reference/05_MUSHAF_SPEC.md`).
- **Translation** — a reading mode optimized for translation-first consumption: paginated by
  Mushaf page internally for position-tracking purposes but visually presented as continuous
  translation text grouped by verse, with a single "current translation book" quick-switch
  control in the sticky header instead of the full per-verse translation stack.

Switching modes calls `readerVm.handleModeTransition(newMode)`, which is responsible for carrying
over the current reading position (verse/page) across the mode change so the user does not lose
their place. The selected mode is persisted as a reader preference and becomes the default for
future reader sessions until changed again.

## 3. Toolbar / chrome

The reader's app bar is a two-row `CenterAlignedTopAppBar` region (on phone width) that
collapses with scroll (`TopAppBarScrollBehavior`):

- **Row 1** (fixed height): back button, a pill-shaped 3-way mode switcher (VerseByVerse /
  Reading / Translation, each with its own icon), and a settings gear that opens Settings scoped
  to "reader settings only" (`Keys.SHOW_READER_SETTINGS_ONLY`). On wide/tablet layouts, row 1 also
  inlines the mode-specific quick actions that would otherwise live in row 2.
- **Row 2** (sticky header, phone-only — hidden and folded into row 1 on wide screens): mode-
  specific content:
  - *VerseByVerse*: auto-scroll toggle, "select translations" shortcut, and (right-aligned) a
    "navigator" button showing the current Juz/Hizb/Chapter icon+label; tapping it opens the
    navigator (§7) as a modal bottom sheet.
  - *Reading (Mushaf)*: left side shows the chapter name(s) present on the current page (marquee
    if it overflows); right side shows current page number plus Juz/Hizb label, tappable to open
    the navigator sheet.
  - *Translation*: left side shows the active translation book name as a chip (tap → translation
    selection); right side shows current page number, tappable to open the navigator sheet.
- The whole bar recedes/collapses on scroll consistent with `docs/DESIGN_DIRECTION.md`'s "chrome
  recedes while reading" principle — Tahfeez should preserve this behavior with its own visual
  language rather than this bar's exact pill/chip shapes.
- A separate, more minimal `FullscreenMushafHeader` composable exists for an even more
  content-forward Mushaf presentation (chapter name / page number / Juz-Hizb in one thin row),
  suggesting the reference app supports (or is migrating toward) a "fullscreen Mushaf" reading
  variant with a lighter header than the standard sticky header. Treat exact wiring/toggle for
  this as `NEEDS_VERIFICATION`.

## 4. Navigator (bottom sheet / side panel)

Opened from the toolbar's navigator button. Contains four navigation lists as sub-destinations,
consistent with `FEATURES.md`'s "Read Qur'an in different views (chapter, juz, hizb)" and "jump
to any verse, chapter, juz, hizb or page":

- Chapter navigator (`ChapterNavigatorList` / `ChapterCard`) — jump to any of the 114 chapters.
- Juz navigator (`JuzNavigationList` / `JuzCard`) — jump to any of the 30 Juz.
- Hizb navigator (`HizbNavigationList` / `HizbCard`) — jump to any Hizb (each Juz has 2 Hizb, 60
  total).
- Page navigator (`PageNavigationList`) — jump directly to a Mushaf page number.

A `PullNavigation` helper suggests pull-to-navigate or swipe gestures are also supported for
quick chapter/page stepping (`NEEDS_VERIFICATION` on the exact gesture). On phone width the
navigator renders as a `ModalBottomSheet`; on wide/tablet layouts (`isWideScreen`) it can be
presented inline rather than as a sheet — consistent with `docs/DESIGN_DIRECTION.md`'s tablet
"side panels where space allows" guidance.

## 5. Per-verse actions (Verse-by-verse mode)

Each verse block (`VerseView`) has a leading action row plus a verse-serial badge:

| Icon | Action |
|---|---|
| Overflow ("⋮", rotated) | Opens `VerseOptionsSheet` (§6) |
| Play/Pause | Plays this single verse's recitation via `RecitationController.playControl` |
| Tafsir | Opens Tafsir reader (`ActivityTafsir`) scoped to this chapter/verse |
| Bookmark toggle | Adds/removes a single-verse bookmark for this exact verse (icon swaps between outline/filled) |
| Verse serial badge (e.g. "2:255") | Tap copies the verse's internal numeric id to the clipboard |

Below the action row: the Arabic text (word-by-word tappable spans, §14) and, if translations are
enabled, one or more translation blocks stacked underneath, each ending with a muted
"— Translator Name" attribution line.

While a verse is the one currently playing, its whole block is highlighted with a soft primary-
color tint (the "current playback highlighting" behavior called out in
`docs/CLEAN_ROOM_RULES.md`/Milestone 0's required-verification list).

## 6. Verse options sheet

A modal bottom sheet titled "Verse information — Chapter Name, Verse N" with a horizontally
scrollable row of options:

- **Footnotes** — enabled only if the verse's active translation(s) have footnotes; disabled
  taps show a toast ("No footnotes for this verse").
- **Similar verses** — enabled only if the verse has any `SimilarVerseEntity` rows; disabled taps
  show a toast ("No similar verses").
- **Share** — opens the verse share sheet (§9).
- **Report** — opens an external link to the project's GitHub issue template for reporting a
  verse-content problem (`ApiConfig.GITHUB_ISSUES_VERSE_REPORT_URL`). Tahfeez should replace this
  with its own reporting channel, not this URL.

## 7. Footnotes, similar verses, and quick reference

- `FootnotePresenter` renders a translation's footnote content for the tapped footnote marker
  (inline superscript markers inside translation text link to this).
- `SimilarVersesSheet` lists verses related to the source verse (backed by
  `extrasDao.countSimilarVerses` / `SimilarVerseEntity` — a curated cross-reference dataset, not
  a live similarity search).
- `QuickReference` is a lighter-weight popup/tooltip surface for quick verse-reference previews
  (e.g., hovering/tapping a translation footnote reference to a verse without leaving the current
  screen) — exact trigger points are `NEEDS_VERIFICATION`.

## 8. Word-by-word (WBW) interaction

- Tapping an Arabic word (when WBW is enabled) opens `WbwSheet`/`WbwTooltip` showing that word's
  transliteration and translation (see `docs/reference/14_WORD_BY_WORD_SPEC.md`).
- `QuranTextWbw` / `QuranWordText` render each word as an individually tappable unit; word
  boundaries come from `AyahWordEntity.wordIndex`, matching the Mushaf glyph-placement model used
  by the atlas renderer, so WBW taps and Mushaf glyph selection share the same underlying word
  index space.

## 9. Sharing

`VerseShareSheet` builds a shareable verse image/text (exact composition — plain text vs.
rendered image, included attribution — is `NEEDS_VERIFICATION` from the files inspected so far).
`docs/PROJECT_BRIEF.md`/`FEATURES.md` calls this "Advanced sharing"; Tahfeez should design its own
share-card visual rather than reproduce this one, while supporting the same *capability* (share a
verse or verse range with Arabic + selected translation).

## 10. Bookmarking from the reader

- Single-verse bookmark: tap the bookmark icon in a verse's action row (§5).
- Range bookmark: triggered via verse selection (multi-verse select in verse-by-verse mode) or via
  the reference-verse flow (see `HomeSectionRecommended`, §"Recommendations" in
  `docs/reference/11_HOME_SPEC.md`) which opens a synthetic reading session over a discontiguous
  verse-spec list; exact in-reader multi-select UX (long-press to start range selection, drag to
  extend) is `NEEDS_VERIFICATION` — not directly confirmed in the files inspected, but implied by
  `FEATURES.md`'s "Bookmark a verse range" and the `BookmarkEntity` schema's `fromVerseNo`/
  `toVerseNo` pair.
- `BookmarkViewerSheet` shows a bookmark's stored note and lets the user edit/delete it in place
  from within reading flows (also reused by the standalone Bookmarks screen).

## 11. Auto-scroll and audio-linked scrolling

- `AutoScrollSheet` lets the user start a hands-free auto-scroll at an adjustable speed,
  independent of audio playback.
- Separately, when a "sync reader position to player" preference (`playerVerseSync`) is on and
  audio is playing, the verse list automatically scrolls to keep the currently-playing verse
  visible (`animateScrollToItem`) — this is the "automatic reader scrolling" / "current playback
  highlighting" feature called out in `FEATURES.md` and Milestone 0's verification list. The two
  scrolling mechanisms (manual auto-scroll speed vs. audio-driven sync) are mutually exclusive:
  audio-driven sync only engages when `autoScrollSpeed == null`.
- A `onSyncStateChanged` callback bubbles up whether the currently-playing verse is on-screen,
  presumably to drive a "jump to playing verse" affordance when it scrolls off-screen
  (`NEEDS_VERIFICATION` on the exact affordance shown to the user).

## 12. Spotlight mode

A full-screen, distraction-free playback companion view (`Spotlight.kt`) that shows the currently
playing verse's Arabic text (and, per `FEATURES.md`, presumably word-level highlighting) large and
centered while audio plays, with minimal chrome — matching "Spotlight mode" in `FEATURES.md`'s
Recitations feature list. Selection/copy of the spotlighted text is supported
(`SelectionContainer`). Exact trigger (a dedicated button vs. auto-entering fullscreen playback)
is `NEEDS_VERIFICATION`.

## 13. Chapter info and structural markers

`ReaderLayoutItem` (the unit type for verse-by-verse/translation-mode lists) includes, besides
`VerseUI`:
- `ChapterInfo` — a card summarizing the chapter (name, meaning, revelation place, verse count;
  see `ChapterInfoCard`) inserted at the start of a full-chapter reading session.
- `Bismillah` — inserted before chapter content except for Chapter 1 (Al-Fatiha, where it is verse
  1) and Chapter 9 (At-Tawbah, which conventionally omits it).
- `IsVotd` — a marker/badge shown when the current verse is today's Verse of the Day.
- `ChapterTitle` — a chapter-name header, used when a reading session spans multiple chapters
  (e.g., Juz/Hizb reading) to mark chapter boundaries inline.
- `SectionMarker` — a lightweight inline label (e.g., a Ruku/Rub/Manzil boundary marker) inserted
  between verses when a structural division changes mid-session.

## 14. Text rendering pipeline (verse-by-verse / translation modes)

`ReaderItemsBuilder` (a suspend, non-UI-thread object) assembles the full list of
`ReaderLayoutItem`s for a chapter/Juz/Hizb ahead of composition:
- Resolves verse count and validates the chapter number via `QuranMeta`.
- Loads translation content through `QuranTranslationFactory` (one factory instance handles
  multiple simultaneously-selected translation slugs).
- Builds `AnnotatedString` translation bodies with inline clickable footnote/reference spans
  (`withLink`, `LinkAnnotation`) and a muted trailing translator-attribution line, with Urdu
  translations getting a dedicated font family for the attribution line (`fontUrdu`) — evidence
  that per-language font substitution is already a modeled concern in the reference app, relevant
  to Tahfeez's own font-fallback design.
- Merges in Atlas glyph placements (`QuranAtlasBundle`/`AtlasGlyphPlacement`) and WBW word data
  (`WbwWordEntity`) per ayah so a single verse item can render Arabic glyphs, per-word tap targets,
  and translation text together without further per-frame DB queries.

## 15. Reader preferences that affect this screen

(Full detail in `docs/reference/10_SETTINGS_SPEC.md`.) Reader-scoped preferences read live via
`ReaderPreferences.observe*()` flows include: reader mode, Quran script + script variant, Arabic
text enabled/disabled, Arabic/translation text size multipliers, primary translation slug(s),
selected tafsir, and WBW settings. Changing any of these while the reader is open updates it
immediately (reactive `StateFlow`/Compose state, not a "restart required" model).

## 16. Loading / empty / error / offline states

- **Loading**: `Loader(fill = true)` full-screen spinner while `readerMode` itself is still being
  resolved (first composition before preferences are read); per-page/per-chapter content loads
  asynchronously afterward without necessarily re-showing a full-screen loader (exact per-mode
  granular loading indicators are `NEEDS_VERIFICATION`).
  - **Empty**: not generally reachable for canonical Quran content once the immutable dataset is
  installed (a chapter/juz/hizb/page always has content); an *empty* condition surfaces instead
  as reduced content, e.g., "no footnotes for this verse" (toast) or a hidden translation stack
  when no translation is selected.
- **Error**: `ReaderItemsBuilder.buildChapterVersesForTranslationMode` returns `null` on invalid
  chapter or zero verse count, which callers must handle by not rendering content —
  `NEEDS_VERIFICATION` on the exact user-facing error surface (toast vs. inline message vs. silent
  no-op).
- **Offline**: the canonical Quran text, its default script, and (once installed) selected
  translations/tafsir/WBW/audio all work fully offline. Only *not-yet-downloaded* optional
  resources (a translation not yet installed, a reciter's audio not yet downloaded) require
  network, and those are gated by the download flows in
  `docs/reference/09_OFFLINE_RESOURCES_SPEC.md`, not by the reader screen itself.

## 17. Responsive behavior

`isWideScreen` is threaded through the app bar and navigator: on wide layouts the navigator can
render inline instead of as a bottom sheet, and toolbar row 2's per-mode actions merge into row 1.
This is the reference app's version of `docs/DESIGN_DIRECTION.md`'s tablet/desktop guidance
("navigation rail where useful," "side panels where space allows") — Tahfeez should implement the
same *responsive intent* (progressively richer chrome on wider viewports) with its own layout and
breakpoints rather than this exact two-row/sheet structure.

## 18. Deep link / restore-position behavior

`ReaderLaunchParams.fromIntent` prioritizes a `MushafPage` restore (exact mushaf code + variant +
page number) over the read-type-based paths, and always supports an `initialVerse` override to
scroll to a specific verse once the page/chapter loads — this is the mechanism read history and
resumed sessions use to return a user to their exact prior position (see
`docs/reference/12_BOOKMARK_HISTORY_SPEC.md`).
