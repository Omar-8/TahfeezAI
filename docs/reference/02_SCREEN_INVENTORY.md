# 02 — Screen Inventory (Reference Behavior)

> Every user-facing screen in `AlfaazPlus/QuranApp`, with purpose, entry routes, section order,
> actions, states, and a KEEP/EVOLVE/DO-NOT-COPY classification for its visual treatment (detailed
> further in `docs/reference/18_VISUAL_REFERENCE_NOTES.md`). Screens with a dedicated deep-dive
> document are summarized here and cross-referenced rather than duplicated.

## Legend for "states" columns
L = Loading, E = Empty, Er = Error, O = Offline-capable. "✓" = confirmed observed/implemented,
"NV" = NEEDS_VERIFICATION (not directly confirmed in source read for this milestone).

---

## 1. Home (`MainScreen` → `HomeScreen`)
- **Purpose**: primary landing surface; single-screen aggregation of update banners, VOTD/
  recommended, read history, featured reading, and reference-content collections.
- **Entry**: app launch (post-onboarding), always the `MainActivity` root content.
- **Sections (order)**: see `docs/reference/11_HOME_SPEC.md` §2.
- **Major actions**: continue reading (history card tap), open a featured verse/chapter, open a
  collection category, update app/resources.
- **Secondary actions**: "View all" on Read History.
- **States**: L: per-section async-load ✓ · E: Read History empty message ✓, others N/A (static
  content) · Er: NV · O: ✓ (core content local; banners degrade silently offline).
- **Nav destinations**: `ActivityReadHistory`, `ActivityReader` (multiple entry shapes),
  `ActivityExclusiveVerses`, `ActivityProphets`, `ActivityQuranScience`, `ActivityQuranicTopics`,
  `ActivitySettings` (from resource-update banners).
- **Data required**: bookmarks (for bookmark-state elsewhere), read history, resource-version
  state, curated featured-reading array, recommendations.
- **Settings affecting screen**: theme, locale, installed/outdated resources.
- **Platform-specific**: VOTD home-screen widget refresh on resume.
- **Responsive**: single scrolling column; no confirmed multi-column tablet variant in files
  inspected (`NEEDS_VERIFICATION`).
- **Classification**: information hierarchy (banners → highlight tab → history → curated →
  collections) — KEEP AS UX PRINCIPLE. Exact card art/gradients — DO NOT COPY EXACTLY.

## 2. Reader — Verse-by-verse / Mushaf / Translation (`ActivityReader` → `ReaderScreen`)
Full detail: `docs/reference/04_READER_SPEC.md`, `docs/reference/05_MUSHAF_SPEC.md`.
- **Purpose**: primary Quran-reading surface across three interchangeable modes.
- **Entry**: bottom-nav "Quran" pill (via index, see §5) → chapter/juz/hizb selection; Home
  shortcuts; Search results; deep links; `OPEN_READER` action; HTTPS App Links.
- **Sections**: collapsing two-row app bar (mode switch + mode-specific sticky header) → content
  (verse list / Mushaf pager / translation list) → per-verse or per-page chrome.
- **Major actions**: switch mode, navigate (chapter/juz/hizb/page sheet), play/pause verse audio,
  bookmark, open tafsir, open verse options (footnotes/similar/share/report), auto-scroll, tap a
  word (WBW), open reader settings.
- **States**: L: full-screen loader while mode resolves ✓, else NV granular · E: N/A for canonical
  content · Er: NV · O: ✓ for installed script/translations/tafsir/audio; NV for exact fallback UI
  on missing resource.
- **Nav destinations**: `ActivityTafsir`, `ActivitySettings` (reader-scoped), navigator sheet
  (in-place).
- **Data required**: active Mushaf/script, selected translations/tafsir/WBW, bookmarks,
  recitation state.
- **Settings affecting screen**: nearly all Reader Settings (`docs/reference/10_SETTINGS_SPEC.md`
  §2) plus Arabic-text toggle and VOTD marker.
- **Platform-specific**: Media3 session drives lock-screen/notification controls while audio
  plays from this screen.
- **Responsive**: `isWideScreen` branch changes app-bar/navigator composition
  (`docs/reference/04_READER_SPEC.md` §17).
- **Classification**: three-mode switch + collapsing chrome + navigator sheet — KEEP AS UX
  PRINCIPLE (a genuinely useful, non-brand-distinctive pattern). Exact pill/chip shapes, colors,
  and icon set — DO NOT COPY EXACTLY.

## 3. Tafsir reader (`ActivityTafsir` → `TafsirReaderScreen`)
- **Purpose**: dedicated full-screen tafsir reading for one verse (or session).
- **Entry**: reader verse-action-bar Tafsir icon; `OPEN_TAFSIR` action.
- **Sections**: app bar (chapter:verse + tafsir name) → tafsir body text.
- **Major actions**: (implied) navigate to adjacent verse's tafsir; switch tafsir.
- **States**: L ✓ (content load) · E: NV · Er: NV (missing/undownloaded tafsir) · O: ✓ once
  downloaded.
- **Nav destinations**: back to reader; `ActivitySettings` (tafsir selection) — NV on direct link.
- **Data required**: selected tafsir's stored text for the target verse.
- **Classification**: dedicated full-screen tafsir view (vs. inline) — KEEP AS UX PRINCIPLE
  (keeps the main reader uncluttered); exact typography treatment — reference-only.

## 4. Chapter Info (`ActivityChapInfo` → `ChapterInfoScreen`)
- **Purpose**: chapter metadata/overview (name meaning, revelation place, verse count, etc.).
- **Entry**: `OPEN_CHAPTER_INFO` action; HTTPS App Link `/chapter_info/*`; presumably a chapter-
  card long-press or info icon in navigator (`NEEDS_VERIFICATION` on the in-app trigger, since the
  manifest confirms external triggers but the in-app affordance wasn't directly inspected).
- **Nav destinations**: reader (start reading this chapter).
- **Classification**: informational detail screen — KEEP AS UX PRINCIPLE; exact layout —
  reference-only.

## 5. Quran Index (`ActivityReaderIndexPage` → `ReaderIndexScreen`)
- **Purpose**: primary "browse the Quran" surface, reached from the bottom nav's central pill
  button.
- **Entry**: `MainBottomNavigationBar` center button (see `docs/reference/03_NAVIGATION_MAP.md`).
- **Sections**: 4 tabs — **Chapters**, **Juz**, **Hizb**, **Favourites** — each its own scrollable
  list within a `HorizontalPager`; a reverse-order toggle per tab (except Favourites); chapter tab
  additionally supports filters (`ReaderChapterIndexFilters`: length, revelation type — Meccan/
  Medinan, and presence of a Sajdah verse).
- **Major actions**: tap a chapter/juz/hizb card to open the reader at that unit; toggle list
  order; apply chapter filters.
- **Secondary actions**: switch tabs.
- **States**: L: NV · E: Favourites tab empty state NV (depends on what "Favourites" sources from
  — likely bookmarked chapters or a separate favorites concept, `NEEDS_VERIFICATION`) · Er: N/A ·
  O: ✓ fully local.
- **Nav destinations**: `ActivityReader` (all three non-Favourites tabs); Favourites tab target
  `NEEDS_VERIFICATION`.
- **Classification**: tabbed index with filters — KEEP AS UX PRINCIPLE (`FEATURES.md`'s "Read
  Qur'an in different views"); exact card art — reference-only.

## 6. Search (`ActivitySearch` → `SearchScreen`)
Full detail: `docs/reference/07_SEARCH_SPEC.md`.
- **Purpose**: unified search across Quran text, translations, chapters, and reference content;
  quick navigation via structured query patterns.
- **Entry**: bottom-nav "Search" item; Android system `SEARCH` intent action / assist integration.
- **Sections**: search field (+ voice-search mic if supported) → quick links → search history (no
  query) → result sections by kind (once querying).
- **Major actions**: type/voice a query, tap a result to navigate, filter by translation.
- **Secondary actions**: clear/delete history entries, toggle Arabic-text-inclusion.
- **States**: L: Paging 3 load states ✓ · E: NV empty-history / zero-result copy · Er: NV ·
  O: ✓ (installed content only).
- **Nav destinations**: `ActivityReader`, `ActivityTafsir`, reference-content activities (via
  `ExclusiveVersesSearchProvider` result taps).
- **Classification**: unified multi-domain search with quick links — KEEP AS UX PRINCIPLE; exact
  result-card styling — reference-only.

## 7. Settings (`ActivitySettings`)
Full detail: `docs/reference/10_SETTINGS_SPEC.md`. Grouped list (3 categories) → ~9 sub-screens +
2 bottom sheets (Daily Reminder, Text Sizes) + 1 picker sheet (Download Source).
- **Classification**: grouped settings list, per-item subtitle showing current value — KEEP AS UX
  PRINCIPLE (very common, high-clarity Material pattern); exact icon set — reference-only.

## 8. Bookmarks (`ActivityBookmark` → `BookmarksScreen`)
Full detail: `docs/reference/12_BOOKMARK_HISTORY_SPEC.md` §2.
- **Classification**: flat multi-select list with shared delete-confirmation dialog — KEEP AS UX
  PRINCIPLE.

## 9. Read History (`ActivityReadHistory` → `ReadHistoryScreen`)
Full detail: `docs/reference/12_BOOKMARK_HISTORY_SPEC.md` §3.

## 10. Export / Import (`ActivityExportImport` → `ExportImportScreen`)
Full detail: `docs/reference/12_BOOKMARK_HISTORY_SPEC.md` §4.
- **Classification**: scoped-card export/import (Everything / Settings / Bookmarks) — KEEP AS UX
  PRINCIPLE (clear, low-risk scoping); read-history's deliberate exclusion — KEEP AS PRODUCT
  DECISION (Tahfeez should make and document its own equivalent decision).

## 11. Storage Cleanup (`ActivityStorageCleanup` + 4 sub-screens)
Full detail: `docs/reference/09_OFFLINE_RESOURCES_SPEC.md` §4.
- **Sections**: main category list → per-category (Recitation/Scripts/Tafsir/Translation) storage
  breakdown and deletion.
- **Classification**: per-category storage breakdown — KEEP AS UX PRINCIPLE.

## 12. App Logs (`ActivityAppLogs` → `AppLogsScreen`)
- **Purpose**: view/export locally-captured crash logs (no third-party crash SDK).
- **Classification**: self-hosted diagnostics — KEEP AS PRODUCT PRINCIPLE (privacy-aligned);
  exact log-viewer UI — reference-only.

## 13. About (`ActivityAbout` → `AboutScreen`)
- **Purpose**: app version/credits/links (privacy policy, help, feedback, Discord, donation — per
  the reference repo's `inventory/other/` link manifest). Likely also hosts links to Export/Import
  and Storage Cleanup (`NEEDS_VERIFICATION`, since neither appears in the Settings nav graph
  itself — see `docs/reference/10_SETTINGS_SPEC.md` §6).
- **Classification**: standard about/credits screen — KEEP AS UX PRINCIPLE; exact content/links —
  DO NOT COPY (these are the reference project's own organizational links, not Tahfeez's).

## 14. Onboarding (`ActivityOnboarding` → `OnboardingScreen`, 4-page pager)
- **Purpose**: first-run setup before the main app is usable (`isOnboardingRequired` gate in
  `MainActivity`).
- **Pages (order)**: 1) Language, 2) Theme, 3) Translations, 4) Tafsir.
- **Major actions**: next/back paging, make a selection per page, finish → main app.
- **Nav destinations**: replaces itself with `MainActivity` on completion (`finish()`-based, no
  back-stack return to onboarding).
- **Classification**: a short, capability-selection-first onboarding (language → theme → content
  preferences, no account/login step) — KEEP AS UX PRINCIPLE, directly consistent with
  `docs/PROJECT_BRIEF.md`'s "no mandatory account." Exact page count/order/art — reference-only.

## 15. Reference-content screens (`activities.reference.*`)
Group of screens for curated Quran-reference collections (`docs/reference/11_HOME_SPEC.md` §6):
`ActivityReference` (a hub, `OPEN_REFERENCE` action), `ActivityProphets`,
`ActivityExclusiveVerses` (parameterized by kind: Dua/Solution/Etiquette/MajorSins),
`ActivityPropheticDuas`, `ActivityQuranScience` + `ActivityQuranScienceContent`,
`ActivityQuranicTopics` (parameterized: Ontology/Thematic — `TopicsListScreen`,
`TopicsDetailScreen`, `QuranicTopicsSearchScreen`).
- **Sections**: category hub → list → detail (verse or topic content), a consistent 3-level
  drill-down across all reference categories.
- **States**: L/E/Er/O — NV in detail per category, but all are local-content-driven so expected
  to be offline-capable once their dataset is installed/bundled.
- **Classification**: consistent hub→list→detail drill-down across reference categories — KEEP AS
  UX PRINCIPLE; category roster and authored prose content — DO NOT COPY (see
  `docs/CLEAN_ROOM_RULES.md` on reference-content prose provenance).

## 16. Popup Quran Activity (`PopupQuranActivity`, excluded from Recents)
- **Purpose**: a lightweight, transient popup presentation of Quran content, triggered via the
  custom `SHOW_POPUP` action — likely used for a quick verse preview from outside the main app
  flow (e.g., from another app via intent, or from a system-level integration). Exact trigger
  source `NEEDS_VERIFICATION`.
- **Classification**: lightweight popup pattern — KEEP AS UX PRINCIPLE if Tahfeez ever needs an
  equivalent (e.g., a quick-look verse card); not a near-term priority.

---

## Cross-cutting: persistent overlay

The Recitation player (mini/expanded, `docs/reference/08_AUDIO_SPEC.md` §6) is mounted once at
the `MainScreen` level and persists visually across Home/Search/Settings/etc. (but not across the
separate `ActivityReader`/`ActivityTafsir`/other Activities, each of which is its own Android
task/window) — its state (what's playing) persists app-wide via the shared `RecitationService`
regardless of which screen is visible. This "always-available player" pattern is KEEP AS UX
PRINCIPLE; Tahfeez's Flutter navigation (single `Navigator`/`go_router` shell) can implement true
persistence across every screen, an improvement opportunity over the Activity-boundary limitation
inherent to the reference app's architecture.
