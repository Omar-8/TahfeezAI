# 07 — Search Specification (Reference Behavior)

> Source: `com.quranapp.android.search.*`, `com.quranapp.android.compose.screens.search.*`,
> `com.quranapp.android.db.searchindex.*`, `com.quranapp.android.db.dao.{ArabicSearchDao,
SurahSearchDao}`.

## 1. Entry points

- Bottom navigation "Search" item (`ActivitySearch`, exported, also registered as an Android
  `SEARCH` intent-action target with an `android.app.searchable` metadata resource, meaning it can
  also be invoked via the system assist/search affordances).
- Deep-linkable from Home's tabbed section, verse options, etc. is not observed; primary entry is
  the dedicated Search tab.

## 2. Search domains (what can be searched)

The `SearchScreen` composable takes a `quranTextEnabled` toggle plus supports a distinct
"collections" search mode, giving at least these searchable domains:

1. **Arabic Quran text** — `ArabicSearchDao` over `ArabicSearchFtsEntity` (an FTS5 shadow table in
   the immutable `QuranDatabase`).
2. **Translation text** — `SearchIndexDao` over `TranslationSearchFtsEntity`/
   `TranslationSearchContentEntity` (the separate, derived `SearchIndexDatabase` — see
   `docs/reference/06_DATA_MODEL_SPEC.md` §6), scoped by an optional set of selected translation
   slugs (`SearchFilters.selectedSlugs`).
3. **Chapter/Surah name & alias search** — `SurahSearchDao` over `SurahSearchAliasEntity` +
   `SurahAliasFtsEntity`, resolving fuzzy/transliterated/aliased chapter names to a canonical
   chapter (`SurahSearchResult`).
4. **Quick-link pattern parsing** — `SearchQuickLinksParser` recognizes structured navigation
   queries typed directly into the search box: a verse jump (`2:255`), a verse-range jump
   (`2:255-257`), a bare chapter or Juz number, and (implied by the presence of
   `QuickLinkItem.Tafsir`) direct tafsir jump patterns. These render as an immediate "quick links"
   result section above/alongside full-text results (`QuickLinks.kt`), letting a numeric or
   reference-shaped query resolve instantly without a full-text query round-trip.
5. **Reference-content collections** — `ExclusiveVersesSearchProvider` searches across Topics
   (via `TopicsDao`/`TopicSearchHit`), the curated exclusive-verse datasets (duas, solutions,
   etiquette, major sins — `docs/reference/12_BOOKMARK_HISTORY_SPEC.md` is not the right place;
   see `docs/reference/11_HOME_SPEC.md` §6 for the dataset roster), and Quran-and-Science topic
   items, each capped at its own result limit (40/40/30) and combined under one shared cap (90).
6. **Search history** — a small, separate `SearchHistoryStore`/`SearchHistoryDBHelper`, independent
   of the FTS databases, storing raw query strings with timestamps.
7. **Voice search** — gated by `supportsVoiceSearch` (checked at runtime — the manifest declares a
   `<queries>` element for `android.speech.action.RECOGNIZE_SPEECH`, and the Android 11+ package-
   visibility model means this capability check can legitimately fail on devices/OS configurations
   without a speech-recognition provider). When available, a mic icon triggers voice capture and
   feeds the recognized text back into the query field via a `SharedFlow<String>`.

## 3. Text normalization (the clean-room-relevant part)

`SearchNormalizer` implements script-aware normalization used to build FTS index content **and**
to normalize incoming queries the same way, so the two sides match:

- **Latin-script languages** (`en`, `fr`, `es`, `id`, `tr`, `de`, `nl`, `sv`, `no`, `da`, `it`,
  `pt`, `ms`, …): lowercased.
- **Arabic-script languages** (`ar`, `ur`, `fa`): diacritics (tashkeel, U+064B–U+065F, U+0670)
  stripped, tatweel (ـ) stripped, hamza-bearing alef variants (أ إ آ ٱ) folded to bare alef (ا),
  alef-maksura (ى) folded to yaa (ي), and whitespace collapsed.
- A generic pass (`Normalizer.Form.NFKC` + lowercase + trim) is applied as the base step before
  either script-specific pass.
- This normalized form is stored **only** in the derived search/index tables
  (`ArabicSearchFtsEntity`, `TranslationSearchFtsEntity`/`TranslationSearchContentEntity`) — the
  canonical Arabic verse text in `AyahWordEntity`/`AyahEntity` and canonical translation text are
  never overwritten with the normalized form. This is a concrete, working example of
  `docs/CLEAN_ROOM_RULES.md`'s requirement that "search normalization must operate on
  derived/indexed representations while preserving canonical source text," and Tahfeez's own
  search-index design should follow the identical separation (never destructively normalize the
  canonical Quran text table itself).

## 4. Query building (FTS5)

`FtsQueryBuilder`:
- Normalizes the raw query the same way index content was normalized.
- Splits on whitespace into tokens, drops tokens shorter than 2 characters or containing no
  letter/digit.
- Converts each surviving token into an FTS5 prefix-match term (`token*`), optionally scoped to a
  specific FTS column (`column:token*`).
- Joins tokens with implicit `AND` (FTS5 default), i.e. a multi-word query requires all terms to
  match (as prefixes) somewhere in the row — this is "search for full word or word part" from
  `FEATURES.md` (prefix matching naturally covers partial-word search).
- Escapes FTS5 special tokens (`OR`/`AND`/`NOT`) by quoting them if a user's query literally
  contains those words, so they're treated as search terms rather than FTS operators.
- Returns `null` if no valid tokens remain (e.g., an all-punctuation or all-short-token query),
  signaling "don't run a query" rather than "run an empty/match-all query."

## 5. Filters

`SearchFilters(selectedSlugs: Set<String>?)` — when non-null/non-empty, translation search is
restricted to only the selected translation slugs; `null`/empty means "search across all
installed translations." Persisted via `SearchFiltersStore`. Exposed to the user via
`SearchFilterSheet` (a bottom sheet, consistent with `docs/DESIGN_DIRECTION.md`'s "bottom-sheet
interaction for secondary actions" as a KEEP-worthy UX pattern).

## 6. Pagination

`SearchPagingSource` (an Android Paging 3 `PagingSource`) backs the results list, meaning search
results — at least for translation/Arabic FTS results — are loaded incrementally as the user
scrolls rather than all at once. Tahfeez should adopt an equivalent incremental-loading strategy
for potentially-large result sets (a common word could match thousands of verses).

## 7. Result presentation

Distinct composables per result kind: `TextSearchResults` (Arabic/translation FTS hits, presumably
with the matched term highlighted — `NEEDS_VERIFICATION` on highlight styling), `SurahSearchResults`
(chapter/alias matches), `ExclusiveSearchResults` (reference-content collection hits),
`QuickLinks` (structured navigation matches), and `SearchHistorySection` (recent queries, tappable
to re-run, presumably deletable — `NEEDS_VERIFICATION` on per-item delete UI, though
`SearchHistoryStore.remove(id)` exists at the data layer confirming the capability exists
somewhere in the UI).

## 8. Loading / empty / error / offline states

- **Loading**: Paging 3's built-in load states apply to the FTS-backed result list;
  `NEEDS_VERIFICATION` on exact placeholder/shimmer treatment.
- **Empty**: no query → history + quick entry points shown instead of results (implied by the
  presence of `SearchHistorySection` as a first-class screen section, not just a dropdown).
  Query with zero results → `NEEDS_VERIFICATION` on exact empty-state message/illustration.
- **Error**: not specifically observed; since search reads local SQLite only (no network round
  trip for the query itself), search failures would be programming errors rather than a
  user-facing network-error state.
- **Offline**: fully offline for any content already installed — Arabic text and chapter/alias
  search always work (canonical data ships with the app or its base dataset); translation search
  works only for installed + indexed translations (`TranslationIndexMetaEntity` tracks indexing
  state per translation, populated by `TranslationSearchIndexWorker`, a background indexing job
  that must complete — at least once per translation version — before that translation's content
  is searchable). This means a freshly-downloaded translation may have a brief "not yet
  searchable" window until its background indexing job finishes; Tahfeez should design for the
  same eventually-searchable window if it defers index building off the download's critical path.

## 9. NEEDS_VERIFICATION

- Exact voice-search flow UI (system dialog vs. in-app recognition UI).
- Whether search-history entries are capped in count/age.
- Exact highlight/emphasis styling applied to matched terms within a result snippet.
- Whether Arabic search also supports partial-diacritic ("search with tashkeel") exact-match mode
  in addition to the default normalized/diacritic-insensitive mode.
