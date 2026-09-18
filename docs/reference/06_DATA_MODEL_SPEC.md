# 06 — Data Model Specification (Reference Behavior)

> Source: `com.quranapp.android.db.*` (Room). Schema/behavior only — table/column *names* are
> reference vocabulary for understanding relationships, not something Tahfeez must reproduce
> literally. Tahfeez's own schema (Drift/SQLite per `docs/PROJECT_BRIEF.md`) should be
> independently designed while preserving the same architectural separations described here.

## 1. Five independent databases (the key architectural fact)

The reference app does **not** use one monolithic database. It uses five separate Room
databases, each with its own version number and migration lifecycle:

| Database | Mutability | Purpose |
|---|---|---|
| `QuranDatabase` (v10) | **Immutable** canonical data | Chapters, ayahs, scripts, Mushaf page maps, navigation ranges, Arabic full-text search index, curated cross-references |
| `UserDatabase` (v2) | **Mutable** user data | Bookmarks, read history |
| `ExternalQuranDatabase` (v4, `exportSchema = true`) | Downloadable/optional | Word-by-word text, word-by-word audio timing, Atlas glyph bundles |
| `TopicsDatabase` (v1) | Immutable reference content | Quranic topics/ontology, topic-ayah links, topic relationships |
| `SearchIndexDatabase` (v2) | Derived/rebuildable | Translation full-text search content, separate from canonical translation storage |

This is a direct, confirmed real-world precedent for two of Tahfeez's own mandated architecture
principles (`CLAUDE.md`): **"immutable Quran data separate from mutable user data"** (Quran vs.
User databases here) and **"keep normalized search text separate from canonical display text"**
(the dedicated `SearchIndexDatabase`, distinct from wherever translation display text is actually
stored/rendered from). Tahfeez should adopt the same *separation of concerns* — e.g., separate
Drift database files or at minimum clearly separated schemas/migrations for canonical Quran data,
user data, downloadable resource data, and search-index data — without copying these exact table
or database names.

## 2. QuranDatabase — canonical Quran data (immutable)

Entities (all keyed to support multi-script coexistence):

- **`SurahEntity`** (`surahs`) — `surahNo` (PK), `ayahCount`, `revelationOrder`, `rukusCount`,
  `revelationType` (enum: `meccan`/`medinan`). Indexed by revelation type and revelation order for
  filtered chapter lists. Carries verse-range validation logic (`isVerseValid`,
  `isVerseRangeValid`) directly on the entity via a `SurahMethods` interface.
- **`SurahLocalizationEntity`** — per-language chapter name/meaning localization (relation:
  `SurahWithLocalizations`).
- **`SurahSearchAliasEntity`** (`surah_search_aliases`) — alternate names/spellings/aliases for a
  chapter per language (e.g., transliteration variants), unique per (`surahNo`, `langCode`,
  `alias`) — this is what lets search resolve a fuzzy/aliased chapter name to its canonical
  number. Backed by an FTS shadow table (`SurahAliasFtsEntity`) for fast prefix matching.
- **`AyahEntity`** (`ayahs`) — `ayahId` (PK, computed as `surahNo*1000 + ayahNo`), `surahNo`,
  `ayahNo`, `juzNo`, `hizbNo`, `rubNo`, `manzilNo`, `rukuNo`, nullable `sajdahType`. Heavily
  indexed (surah, surah+ayah unique, juz, hizb, rub, and a combined juz/hizb/rub/manzil/ruku/
  surah/ayah composite index) to support all navigation-unit lookups efficiently. This single
  table is the join key for essentially everything else (translations, WBW, tafsir, bookmarks
  reference it by chapter+verse-number pair rather than by `ayahId` directly in the mutable
  `UserDatabase`, since that DB has no FK to the immutable one — see §3).
- **`ScriptEntity`** (`scripts`) — a self-referencing tree (`parent → script_id`) representing
  script families and their variants (e.g., a "KFQPC" family script row could parent multiple
  version-variant rows) — `code` unique.
- **`AyahWordEntity`** (`ayah_words`) — composite PK (`ayahId`, `scriptId`, `wordIndex`); per-word
  canonical Arabic text for a given script. This is the shared "word index" space that Mushaf
  glyph placement, WBW, and per-word tap handling all key off.
- **`NavigationRangeEntity`** (`navigation_ranges`) — composite PK (`type`, `unitNo`, `surahNo`);
  `type` enum `{juz, hizb, rub, manzil}`; each row records the start/end ayah of that unit *within
  a given chapter* (a navigation unit can span multiple chapters, hence chapter-scoped rows rather
  than one row per unit).
- **`MushafEntity`** / **`MushafMapEntity`** — see `docs/reference/05_MUSHAF_SPEC.md`.
- **`ArabicSearchFtsEntity`** — FTS shadow table for Arabic Quran-text search (normalized, per
  `docs/reference/07_SEARCH_SPEC.md`).
- **`SimilarVerseEntity`**, **`MutashabihatPhraseEntity`** / **`MutashabihatPhraseAyahEntity`** —
  curated cross-reference datasets: verses similar in content/wording (`mutashabihat` = Quranic
  term for "similar/resembling" verses), surfaced via the reader's "Similar verses" option
  (`docs/reference/04_READER_SPEC.md` §6).

## 3. UserDatabase — mutable user data

- **`BookmarkEntity`** (`user_bookmarks`) — auto-increment `id`; `chapterNo`, `fromVerseNo`,
  `toVerseNo` (a single verse is `fromVerseNo == toVerseNo`, a range is not — this is how single
  vs. range bookmarks share one table/shape); optional `note`; `dateTime`. **No foreign key** to
  `QuranDatabase` — the two databases are physically separate, so referential integrity to
  canonical verse data is enforced only by application logic (verse numbers must be validated
  against `QuranMeta`/`SurahEntity.isVerseRangeValid` at write time), not by the database engine.
  A `BookmarkKey(chapterNo, fromVerse, toVerse)` value type is used purely in-memory to test "is
  this exact verse/range bookmarked" against a loaded bookmark set.
- **`ReadHistoryEntity`** (`read_history`) — auto-increment `id`; `readType` (string mirroring
  `ReadType`: chapter/juz/hizb), `readerMode` (string mirroring `ReaderMode`), `divisionNo`,
  `chapterNo`, `fromVerseNo`, `toVerseNo`, nullable `mushafCode`/`mushafVariant`/`pageNo`,
  `datetime` (epoch millis). Storing both the read-type/verse-range *and* the exact Mushaf
  page/script context is what lets "Continue Reading" restore a user to the exact page/scroll
  position they left off at, not just the chapter.
- A `MIGRATION_1_2` raw-SQL migration shows `read_history` was added in schema version 2 (bookmarks
  existed from version 1), and a separate `UserDataMigrationManager` + `ReadHistoryMigration`
  handle **one-time migration from a pre-Room legacy `SQLiteOpenHelper`-based bookmark store**
  (`BookmarkDbHelper`) into the new Room table, gated by `SharedPreferences` "already migrated"
  flags — evidence the reference app itself went through at least one storage-layer rewrite.
  Tahfeez does not need to replicate this migration, but should note the general lesson: plan for
  future schema migrations of user data from the start (Drift's own migration system covers this).

## 4. ExternalQuranDatabase — downloadable resource data

- **`WbwWordEntity`** (`wbw_words`) — composite PK (`wbwId`, `ayahId`, `wordIndex`); per-word
  `translation` and `transliteration` for a specific WBW language pack (`wbwId`).
- **`WbwAudioTimingEntity`** (`wbw_audio_timing`) — composite PK (`audioId`, `ayahId`,
  `wordIndex`); `startMillis`/`endMillis` word-level audio timing, used to highlight/advance
  per-word during WBW audio playback and (likely) during Spotlight mode.
- **`AtlasBundleEntity`** / **`AtlasWordShapeEntity`** — see
  `docs/reference/05_MUSHAF_SPEC.md` §5.

This database is versioned independently (`exportSchema = true`, unlike the other four) — a sign
the maintainers track its schema more strictly, likely because its rows are populated from
downloaded, remotely-versioned bundles that must stay schema-compatible with older installed
app versions during a rollout.

## 5. TopicsDatabase — reference content

`TopicEntity` / `TopicLocalizationEntity` / `TopicAyahEntity` / `RelationshipEntity` model a
hierarchical topic ontology (see `docs/reference/11_HOME_SPEC.md`'s "Ontology Explorer" and
"Thematic Topics") where topics have parent/child relationships (`RelationshipEntity`,
surfaced via `TopicParentEdgeRow`) and each topic links to one or more ayahs (`TopicAyahEntity`).
This is a separate, fully independent database from the Quran/Search/User databases, reinforcing
that "reference content" (duas, topics, prophets, etc.) is treated as its own bounded resource
category with its own versioning/licensing story — relevant to
`docs/CLEAN_ROOM_RULES.md`'s requirement to not assume redistribution rights over such datasets.

## 6. SearchIndexDatabase — derived translation search index

`TranslationSearchContentEntity` (denormalized per-verse translation text for a given
translation+language, used as the source of truth the FTS table is built from) +
`TranslationSearchFtsEntity` (the actual FTS5 virtual table) + `TranslationIndexMetaEntity`
(tracks which translations have been indexed and at what content version, so the index can be
incrementally rebuilt only for translations that changed). This entire database is *derived* —
it can be dropped and rebuilt from installed translation content without any data loss, which is
exactly the "index vs. canonical text" separation `docs/CLEAN_ROOM_RULES.md` requires ("Search
normalization must operate on derived/indexed representations while preserving canonical source
text"). See `docs/reference/07_SEARCH_SPEC.md`.

## 7. Cross-database relations and projections

Because canonical Quran data, user data, and downloadable resource data live in physically
separate Room databases, the app cannot use SQL `JOIN`s across them. Instead:
- `VerseWithDetails` (a `db.relations` projection) is application-level-assembled: canonical
  ayah/word data from `QuranDatabase`, translation text resolved via `QuranTranslationFactory`
  (which reads a *different* legacy/independent translation content store —
  `QuranTranslDBHelper` — see `docs/reference/13_TRANSLATION_TAFSIR_SPEC.md`), and WBW/atlas data
  from `ExternalQuranDatabase`, merged in Kotlin (`ReaderItemsBuilder`, §14 of the Reader spec)
  rather than in SQL.
- Bookmarked-state lookups (`BookmarkKey`) are computed in memory by comparing a loaded bookmark
  list against the current verse being rendered, not via a SQL join, because `UserDatabase` has no
  FK relationship to `QuranDatabase`.

This "compose across independent stores in application code" pattern is a direct consequence of
the multi-database design and is a pattern Tahfeez's Riverpod repository layer should expect to
need too if it adopts a similar separation (e.g., a Drift `QuranDatabase` and a Drift
`UserDatabase` as two separate database classes).

## 8. `ChapterVerseBatch` and batched repository access

A small `ChapterVerseBatch` helper exists in `db` for efficiently loading many
(chapter, verse) pairs' data in one batched query rather than N+1 individual queries — relevant
for building a full Juz/Hizb reading session (which spans many chapters/verses) without one query
per verse. Tahfeez's repository layer should budget for the same batching concern.

## 9. Reader intent-extras contract (for reference / cross-linking)

Although not itself a persisted database, `ReaderLaunchParams`'s Intent-extra keys constitute a
de facto public "session data model" (see `docs/reference/04_READER_SPEC.md` §1) worth recording
here because Tahfeez's own router (`go_router`) will need an equivalent typed representation of
"what reading session is this": read-type (chapter/juz/hizb) OR a Mushaf-page restore, an optional
reader mode, an optional translation-slug-set override, and an optional initial-verse scroll
target.

## 10. NEEDS_VERIFICATION

- Exact `mushafCode` string values and how many distinct Mushaf rows ship by default.
- Whether `ExternalQuranDatabase` and `SearchIndexDatabase` are lazily created only once a
  relevant resource is first installed, or always created empty at first launch.
- Exact legacy translation/tafsir storage mechanism referenced by `QuranTranslDBHelper` /
  `QuranTafsirDbHelper` (older `SQLiteOpenHelper`-style helpers coexist alongside the newer Room
  databases — see `docs/reference/13_TRANSLATION_TAFSIR_SPEC.md`).
