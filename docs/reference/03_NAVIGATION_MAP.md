# 03 — Navigation Map (Reference Behavior)

## 1. Top-level architecture: Activities, not a single NavHost

The reference app is **not** structured as one Compose `NavHost` with every screen as a
destination. It is a classic multi-Activity Android app where each major feature area is its own
Activity (see the full list and launch modes in `docs/reference/16_PLATFORM_FEATURES_SPEC.md` §1
and the manifest excerpt below), and only *within* some of those Activities (Settings, the
Quran Index, Onboarding, Reference-content flows) is there an internal Compose navigation graph
or pager.

`MainActivity` hosts `MainScreen`, which is just: a top app bar, `HomeScreen` as body content, a
bottom navigation bar, and the persistent Recitation player overlay. There is **no tab-switching
NavHost at the Home level** — Home is the only content `MainScreen` ever shows; the other two
bottom-bar destinations (Quran Index, Search) are separate Activities launched via `Intent`, not
in-place content swaps.

This is an important architectural fact for Tahfeez to consciously decide about: Tahfeez uses
`go_router` (per `CLAUDE.md`), which naturally supports either a single-shell multi-tab structure
or a more Activity-like "push a new full route" structure. Tahfeez is **not** obligated to
replicate "bottom nav items are separate Activities" — a shell-based `go_router` structure (one
persistent bottom nav + `IndexedStack`/nested navigators per tab) is equally valid and arguably a
Tahfeez-appropriate improvement (it would let the mini player persist across all three areas
instead of only Home), consistent with `docs/DESIGN_DIRECTION.md`'s license to improve on the
reference where a better Tahfeez composition exists.

## 2. Primary (bottom) navigation

Three items, rendered as a custom `Row` (not Android's `NavigationBar` composable), always
visible at the bottom of `MainScreen`:

| Position | Label | Icon | Destination | Notes |
|---|---|---|---|---|
| Left | Home | home icon | *(no-op — already on Home)* | Marked visually "active" always, since Home is the only content `MainScreen` shows |
| Center | (no text label) | Quran/Kaaba glyph, pill-shaped, primary-colored | `ActivityReaderIndexPage` | Visually the most prominent item — larger, filled pill, not a plain icon-plus-label like the other two |
| Right | Search | search icon | `ActivitySearch` | |

Per `docs/DESIGN_DIRECTION.md`'s eventual **Home / Quran / Memorize / Search** four-area target,
Tahfeez should treat this reference 3-item bar as a placeholder appropriate only until
memorization ships; Milestone 4 (Home & Navigation) should still capture the "one item is
visually elevated/primary" pattern as a KEEP-worthy piece of hierarchy (Quran access is the app's
core action) even as the exact item set evolves.

## 3. Full Activity graph (from `AndroidManifest.xml`)

```
MainActivity (LAUNCHER)
├── ActivityReaderIndexPage            (bottom nav: center)
│     └── ActivityReader               (tap chapter/juz/hizb)
├── ActivitySearch                     (bottom nav: right; also SEARCH intent action)
│     ├── ActivityReader               (result tap)
│     ├── ActivityTafsir               (result tap)
│     └── reference/* activities       (collection-result tap)
├── ActivityReader                     (singleTask; OPEN_READER action; quran.com App Links)
│     ├── ActivityTafsir               (verse action bar)
│     └── ActivitySettings             (reader-scoped settings icon)
├── ActivityTafsir                     (singleTask; OPEN_TAFSIR action)
├── ActivityChapInfo                   (singleTask; OPEN_CHAPTER_INFO action; quran.com/chapter_info/* App Link)
├── ActivitySettings                   (singleTask)
│     ├── LanguageSelectionScreen
│     ├── SettingsThemeScreen
│     ├── TranslationSelectionScreen → TranslationDownloadScreen
│     ├── TafsirSelectionScreen
│     ├── ScriptsScreen
│     ├── SettingsWbwScreen
│     ├── RecitationDownloadScreen
│     └── AppLogsScreen
├── ActivityBookmark
├── ActivityReadHistory
│     └── ActivityReader               (resume at exact position)
├── ActivityExportImport
├── ActivityStorageCleanup
│     ├── StorageCleanupRecitationScreen
│     ├── StorageCleanupScriptsScreen
│     ├── StorageCleanupTafsirScreen
│     └── StorageCleanupTranslationScreen
├── ActivityAppLogs
├── ActivityAbout
├── ActivityOnboarding                 (shown instead of MainActivity content pre-first-run)
└── reference/*
      ActivityReference                (hub; OPEN_REFERENCE action)
      ActivityProphets
      ActivityExclusiveVerses          (kind param: Dua/Solution/Etiquette/MajorSins)
      ActivityPropheticDuas
      ActivityQuranScience → ActivityQuranScienceContent
      ActivityQuranicTopics            (screen-type param: Ontology/Thematic)

PopupQuranActivity                     (excludeFromRecents; SHOW_POPUP action; standalone)
```

`ActivityReader`, `ActivityTafsir`, `ActivityChapInfo`, and `ActivitySettings` all use
`launchMode="singleTask"` — repeated launches reuse the existing instance (clearing activities
above it in that task) rather than stacking duplicates, which matters for how "open reader from
three different places while one is already open" behaves (it re-targets the existing instance
via `onNewIntent`, not a fresh stacked Activity).

## 4. Deep links (cross-reference)

Full deep-link table (HTTPS App Links + custom actions) is in
`docs/reference/16_PLATFORM_FEATURES_SPEC.md` §1.

## 5. Internal navigation graphs

- **Settings** (`SettingRoutes`) — a proper Compose `NavHost`-style string-route graph (the only
  place in the app using this pattern as its primary navigation, per `SettingRoutes.kt`).
- **Quran Index** (`ReaderIndexScreen`) — a `HorizontalPager` over 4 fixed tabs (not route-based).
- **Onboarding** — a `HorizontalPager` over 4 fixed pages (not route-based).
- **Reference content / Quranic Topics** — hub → list → detail, `NEEDS_VERIFICATION` whether this
  is route-based or a local state-driven pager/stack within one Activity.

## 6. Back-stack and up-navigation

Every non-`MainActivity` Activity's app bar shows a back chevron wired to
`LocalOnBackPressedDispatcherOwner`'s dispatcher (confirmed directly in `ReaderAppBar`), i.e.
standard Android back-stack semantics throughout, with the one deliberate exception of a
"selection mode" screens (Bookmarks) intercepting back to first clear selection rather than
exit (`docs/reference/12_BOOKMARK_HISTORY_SPEC.md` §2).

## 7. Tahfeez interpretation

Tahfeez's own navigation architecture (Milestone 1/4) should define, in `docs/ARCHITECTURE.md`,
an explicit choice between:
1. a reference-like "each major area is a pushed full-screen route, bottom nav items behave like
   distinct entry points" model, or
2. a shell-based model (persistent bottom nav + nested navigators) that keeps the mini player and
   bottom nav visible across Home/Quran/Search at all times — the improvement this document
   flags in §1.

Either is compatible with `docs/CLEAN_ROOM_RULES.md` (navigation *behavior/functionality* parity
is fine; the *code structure* must be independently written either way). Milestone 1/4 should
record the chosen model once decided so later milestones build on a frozen decision rather than
re-litigating it per screen.
