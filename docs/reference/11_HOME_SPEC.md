# 11 — Home Screen Specification (Reference Behavior)

> Source: `AlfaazPlus/QuranApp`, package `com.quranapp.android.compose.screens.HomeScreen` and
> `com.quranapp.android.compose.components.homepage.*`. This document describes reference
> *behavior only*. Visual treatment (colors, imagery, card chrome) is reference-only per
> `docs/CLEAN_ROOM_RULES.md` and must be reinterpreted per `docs/DESIGN_DIRECTION.md`.

## 1. Purpose

Home is the single entry surface of the app. It is not a tab inside a `NavHost` — it is the
body content of `MainScreen`, which is a `Scaffold` with a top app bar, a bottom navigation bar,
and a Recitation player sheet overlay. There is no separate "Home activity"; `MainActivity` hosts
`MainScreen` directly.

## 2. Section order (top → bottom, exact)

1. `AppUpdateBanner` — shown only if a Play Store update is available and the in-app update
   banner decision (`UpdateManager.bannerDecision`) says to show it inline (as opposed to a
   blocking/critical update dialog).
2. `HomeResourceUpdatesBanner` — shown only if one or more of: downloaded recitations,
   downloaded translations, or downloaded word-by-word (WBW) language packs are outdated
   (stale versus latest published version). Aggregates counts per resource type into one card;
   tapping a resource-type row deep-links into Settings at that resource's sub-screen
   (`SettingRoutes.RECITATION_DOWNLOAD` / `TRANSLATIONS` / `WWB`) via an intent extra
   (`Keys.NAV_DESTINATION`).
3. `HomeTabbedSection` — see §3.
4. `HomeSectionReadHistory` — horizontal list ("View all" → `ActivityReadHistory`).
5. `HomeSectionFeaturedReading` — horizontal list of curated verse/chapter shortcuts.
6. `HomeSectionVersesCollections` — 2-column grid linking to reference content collections.

A separate `RecitationUpdateBanner` composable exists in the same package (recitation-specific,
narrower version of the resource-updates banner) but is not wired into `HomeScreen`'s current
composition — treat it as `NEEDS_VERIFICATION` whether it is used elsewhere (e.g. inside the
recitation download screen) or is dead/legacy code.

The whole column scrolls vertically as one screen (no per-section independent scrolling except
the internal `LazyRow`s), with bottom padding reserved for the mini player height plus a fixed
64dp so the floating Recitation player sheet never permanently occludes the last section.

## 3. HomeTabbedSection (Recommended vs Verse of the Day)

- On composition, asynchronously loads `Recommended.getRecommendations(context)`.
- **If there are no recommendations**: renders `VerseOfTheDay()` directly (no tabs) — this is
  the common/default case for most installs and dates.
- **If there are recommendations** (e.g. a special occasion or curated banner content is
  configured): renders a two-tab `SecondaryTabRow` inside a themed banner container
  (`HomePremiumBannerContainer`):
  - Tab 0: "Recommended" → `HomeSectionRecommended(recommendations)`.
  - Tab 1: "Verse of the Day" → `VotdContent(header = {})` (same content model as the
    standalone VOTD path, reused via `ReaderProvider`).
- Selected tab index is remembered across recomposition (`rememberSaveable`) but not persisted
  across process death beyond the standard `SavedStateHandle` lifetime.

### Recommendation model
- `Recommendation` has a `title`, `description`, and a `reference` which is one of:
  - `RecommendationRef.Chapter(number)` → tapping opens the full chapter in the reader
    (`ReaderFactory.startChapter`).
  - `RecommendationRef.Verses(spec)` → a comma-separated list of `chapter:verse` or
    `chapter:start-end` tokens; tapping opens a synthetic "reference verses" reading session
    (`ReaderFactory.startReferenceVerse`) covering all referenced chapters/verse-spec strings,
    labeled with the recommendation's own title/description rather than a chapter name.
- Card visually resolves and shows the chapter name only for single-chapter recommendations
  (an async lookup via `QuranRepository.getChapterName`).

### Verse of the Day (VOTD)
- VOTD content itself lives in a separate shared component (`VerseOfTheDay` /
  `VotdContent`) reused by Home and by the home-screen app widget
  (`updateAllVotdWidgets`, invoked from `MainActivity.onResume`). Exact VOTD selection algorithm
  (fixed daily verse list vs. random-with-seed-per-day vs. remote-configured) is
  `NEEDS_VERIFICATION` — not confirmed from the files read so far.

## 4. Read History section

- Backed by `ReadHistoryViewModel`, exposing `chapterNames` (a map from chapter number to
  localized name) and `recentHistories` (most-recent-first, home shows the ones the view model
  chooses to expose — historically capped, see `HOME_HISTORY_LIMIT = 10` constant in
  `HomeScreen.kt`, though the constant's actual wiring into the view model call should be treated
  as `NEEDS_VERIFICATION` since it is declared but its use site was not directly confirmed in the
  excerpt read).
- Empty state: italic muted text, "Read history will show up here" style message. No image/
  illustration in the empty state.
- Each history card shows:
  - A leading icon whose glyph depends on `ReaderMode` (`Reading` = Mushaf icon,
    `Translation` = translation icon, else = verse-by-verse icon).
  - A title/subtitle computed by `titleLabel(chapterName)` / `subtitleLabel(chapterName)`
    extension functions on `ReadHistoryEntity`, which vary by `ReadType` (`Chapter` / `Juz` /
    `Hizb`) — exact string composition is `NEEDS_VERIFICATION` (extension functions not yet
    read in full).
  - An accent color keyed to `ReadType` (chapter = primary, juz = tertiary, hizb = secondary) —
    color values themselves are reference-only; Tahfeez should express the same *semantic*
    distinction (three distinguishable read-type accents) using its own token set.
  - A static "Continue Reading" affordance label at the bottom of the card.
- Tapping a card resumes reading at the exact stored position via
  `ReaderFactory.prepareHistoryIntent(history)`.

## 5. Featured Reading section

- Sourced from a string-array resource (`R.array.arrFeaturedQuranItems`), where each entry is a
  token of the form `"chapter"`, `"chapter:verse"`, or `"chapter:start-end"` (en-dash `–` also
  accepted as a range separator).
- For each token the UI resolves a title/subtitle:
  - Whole chapter → chapter name + "verses 1–N" mini info.
  - Single verse that is Chapter 2, Verse 255 → special-cased as "Ayatul Kursi" title.
  - Other single verse → chapter name + "Verse N".
  - Verse range → chapter name + "Verses N–M".
- Tapping a card opens that exact chapter/verse-range in the reader
  (`ReaderFactory.startVerseRange`).
- This is a fixed, curated, developer-authored list (not personalized/algorithmic).

## 6. Verses Collections grid

Fixed set of 8 entries (2-column grid, wraps), each opening a distinct reference-content
activity/screen:

| Title | Destination |
|---|---|
| Featured Duas | `ActivityExclusiveVerses` (kind = Dua) |
| Solutions from Quran | `ActivityExclusiveVerses` (kind = Solution) |
| Etiquette verses | `ActivityExclusiveVerses` (kind = Etiquette) |
| Major Sins | `ActivityExclusiveVerses` (kind = MajorSins) |
| Prophets | `ActivityProphets` |
| Quran & Science | `ActivityQuranScience` |
| Ontology Explorer | `ActivityQuranicTopics` (screen type = Ontology) |
| Thematic Topics | `ActivityQuranicTopics` (screen type = Thematic) |

This list is a generic "grid of reference-content categories" UX pattern (KEEP AS UX PRINCIPLE);
its exact 8-item roster, icon artwork, and ordering are DO NOT COPY EXACTLY — Tahfeez should
decide its own reference-content roadmap and only add a similar grid once equivalent content
exists.

## 7. Loading / empty / error / offline states

- **Loading**: sections that depend on async data (`produceState`) render nothing until data is
  ready; there is no shared skeleton/shimmer treatment observed across all home sections — this
  should be treated as `NEEDS_VERIFICATION` for full precision, but the common pattern is
  "no visible section until data resolves" rather than a placeholder skeleton.
- **Empty**: Read History has an explicit empty-state message (§4). Featured Reading and Verses
  Collections are statically populated and never empty. Recommended/VOTD tab falls back to VOTD
  when there are no recommendations (§3).
- **Error**: no explicit error UI was observed for home sections in the files read; failures in
  underlying repositories would surface as an indefinitely "loading" (never-populated) section.
  Mark exact error-state behavior `NEEDS_VERIFICATION`.
- **Offline**: Home does not require network for its default state (reading history, featured
  reading, and collections are all local). The only network-dependent visuals are the app-update
  banner (Play Store metadata) and resource-update banners (checking for newer downloadable
  resource versions) — both silently no-op/hide when the check cannot complete, matching the
  project's offline-first philosophy.

## 8. Settings affecting Home

- Outdated-resource banners react to installed language/reciter/translation/WBW selections in
  Settings.
- Theme (light/dark/dynamic color) affects all card rendering.
- Locale/language affects all string resources and the `LocalAppLocale` used for number/date
  formatting in Featured Reading subtitles.

## 9. Platform-specific behavior

- A Verse-of-the-Day home-screen widget exists (`updateAllVotdWidgets`), refreshed on every
  `MainActivity.onResume`. Widget content reuses the same VOTD data source as the in-app VOTD
  component (`NEEDS_VERIFICATION` on exact parity of formatting between widget and in-app VOTD).

## 10. Tahfeez interpretation notes

Per `docs/DESIGN_DIRECTION.md`, Tahfeez's home should progressively foreground **Continue
Reading, Today's Memorization, Today's Revision, Daily Ayah, Recent Quran, Memorization
Progress, Explore Quran** rather than mirroring this exact section list. Before memorization
ships, an early Tahfeez home may reasonably keep an equivalent-purpose subset (continue reading /
daily ayah / recent activity / explore) implemented with independent visuals, spacing, and
component structure — not this file's card shapes, gradients, or copy.
