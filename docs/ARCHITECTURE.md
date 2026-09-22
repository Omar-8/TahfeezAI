# Tahfeez AI — Architecture

This document records the engineering architecture established in Milestone 1 (Flutter
Cross-Platform Foundation) and the decisions later milestones should build on rather than
re-litigate. Per `docs/CLEAN_ROOM_RULES.md`, this architecture is independently designed for
Tahfeez; where it happens to match a pattern validated in `docs/reference/` (e.g. the immutable/
mutable database split), that is because the reference app's own experience confirmed the pattern
is sound — not because any reference code was reused.

## Authority

Per every milestone prompt's "Authority rules": this document controls implementation
architecture. `docs/CLEAN_ROOM_RULES.md` controls what may be learned from vs. copied from the
reference app. `docs/DESIGN_DIRECTION.md` controls visual/UX direction. `docs/reference/`
describes reference *behavior*, not Tahfeez's implementation.

## 1. Layers and dependency direction

```
presentation  →  application  →  domain  ←  data
     │                                        │
     └────────────────── core ────────────────┘
```

- **`domain`** (per feature area) defines repository *interfaces* and the minimal value types they
  operate on. It has no dependency on Flutter, Drift, Dio, or any other implementation detail —
  it is pure Dart. This is the layer other layers depend on, never the reverse.
- **`data`** implements domain repository interfaces against concrete storage/network (Drift
  tables, Dio calls, file storage). Added by the milestone that owns each feature (Quran Data
  Engine for `quran/data`, User Data & Sharing for `user_data/data`, and so on) — Milestone 1
  intentionally ships zero concrete data-layer implementations, only the interfaces.
- **`application`** (where a feature needs it) holds Riverpod controllers/state notifiers that
  orchestrate one or more repositories for a specific screen or flow.
- **`presentation`** is widgets. Presentation code depends on `application`/`domain` types, never
  reaches past them into `data` or `core` implementation details directly (e.g. a widget never
  imports `package:drift` or `package:dio`).
- **`core`** is cross-cutting infrastructure every feature area may depend on (database
  connection, theming, routing, logging, networking, storage, downloads, audio, platform
  capabilities). `core` never depends on `quran`, `user_data`, `memorization`, `ai`, or
  `features` — dependencies only point inward/upward through this stack, never sideways between
  feature areas and never downward from `core` into a feature.

Feature areas do not depend on each other directly. If two feature areas need to share
something, the shared piece belongs in `core` (if it's infrastructure) or is exposed through a
repository interface one area's domain publishes for another to depend on.

## 2. Project structure

```text
lib/
  app/                          Root widget, bootstrap sequence, main().
  core/
    database/                   Drift connection helper + the core app-level database.
    routing/                    go_router configuration.
    theme/                      Color/typography/spacing tokens, breakpoints, ThemeData assembly.
    localization/               l10n wiring, supported locales, persisted locale controller.
    storage/                    FileStorage (native) + BrowserStorage (cross-platform KV) interfaces.
    networking/                 NetworkClient (Dio) + ConnectivityService interfaces.
    downloads/                  ResourceDownloadService interface + domain/ResourceRepository.
    audio/                      AudioController interface (+ minimal just_audio impl) + domain/AudioRepository.
    logging/                    AppLogger interface + implementation + global error hook.
    platform/                   PlatformCapabilities — the one place platform checks live.
    ui/                         Small UI helpers shared by more than one feature (e.g. showComingSoon).
  quran/domain/                 QuranRepository, TranslationRepository, TafsirRepository, SearchRepository, QuranLocation.
  quran/application/            Quran-domain concerns shared by more than one feature (dataset-installed status, recent location, script code + preference, available scripts, chapter localization, translation/tafsir selection + library controllers).
  quran/presentation/           Translation/tafsir UI shared by more than one feature (Milestone 9): TranslationBlock, quick reference, packs sheets, TafsirReaderScreen.
  wbw/                           Word-by-word: its own domain/data/application/presentation, own database (Milestone 8).
  user_data/domain/             UserDataRepository (bookmarks, reading history).
  memorization/domain/          MemorizationRepository.
  ai/domain/                    RecitationRecognizer, RecitationContext, RecitationEvent (interfaces only).
  features/                     Feature-area presentation code (home, quran, search, reader, mushaf, ...).
```

This refines the milestone prompt's suggested tree in one deliberate way: `UserDataRepository`,
`AudioRepository`, `ResourceRepository`, and `MemorizationRepository` are *not* all grouped under
`quran/domain` even though the prompt listed them together under one "Repository interfaces"
heading. They are split across `user_data/`, `core/audio/domain/`, `core/downloads/domain/`, and
`memorization/domain/` respectively, because:

- `UserDataRepository` governs **mutable** user data (bookmarks, history), which must stay
  architecturally and physically separate from the **immutable** canonical Quran data
  `QuranRepository` governs — see §4. Putting both under `quran/domain` would blur exactly the
  boundary that separation exists to enforce.
- `AudioRepository` and `ResourceRepository` are cross-cutting infrastructure concerns (any
  feature area might play audio or track a downloadable resource), so they live next to their
  corresponding `core/audio` and `core/downloads` infrastructure rather than under one feature
  area's domain.
- `MemorizationRepository` gets its own top-level domain because Memorization is its own
  first-class product area per `docs/PROJECT_BRIEF.md`, not a sub-concern of reading.

`QuranRepository`, `TranslationRepository`, `TafsirRepository`, and `SearchRepository` remain
together under `quran/domain` because they all describe read access to Quran-adjacent content
(`docs/PROJECT_BRIEF.md`'s "Read" product area).

## 3. Repository pattern

Every repository is defined as an abstract Dart class in a `domain/repositories/` folder, with:

- No Flutter, Drift, or Dio imports.
- Method signatures expressed in terms of small domain value types (e.g. the `VerseRef`/
  `VerseRangeRef` records in `lib/quran/domain/models/quran_refs.dart`) rather than raw
  primitives where a shape is shared across methods.
- A doc comment stating which milestone provides the concrete implementation.

UI and application code depend on the interface via a Riverpod provider that later milestones
override with a real implementation; nothing in this milestone hardcodes a concrete
implementation behind these interfaces except where noted in §6 (audio) — everywhere else,
Milestone 1 ships the contract only, deliberately, so the milestones that own each domain are free
to choose their concrete data shape without Milestone 1 having guessed wrong.

## 4. Database separation (immutable vs. mutable vs. derived)

`docs/reference/06_DATA_MODEL_SPEC.md` confirmed the reference app itself uses five physically
separate databases specifically to keep immutable canonical Quran data apart from mutable user
data and from a derived search index. `CLAUDE.md` makes the same separation a Tahfeez
requirement independent of that finding. Tahfeez's plan:

| Database | Owns | Introduced by |
|---|---|---|
| Core app database (`lib/core/database/app_database.dart`) | App-level bookkeeping only (a generic key/value table) — no Quran or user content | Milestone 1 |
| Quran database (`lib/quran/data/quran_database.dart`) | Canonical chapters/verses/scripts/Mushaf maps/navigation units — **immutable** | Milestone 2 (Quran Data Engine) — delivered |
| User database | Bookmarks, reading history — **mutable** | Milestone 11 (User Data & Sharing) |
| Search index database | Derived, normalized, rebuildable text index — never the source of truth | Milestone 10 (Search) |
| Resource metadata (translations/tafsir/WBW/audio/atlas) | Downloadable content + its version-tracking state | Milestones 8, 9, 12, 13 |

Each database is its own Drift `@DriftDatabase` class opened through the same
`openConnection()` helper (`lib/core/database/database_connection.dart`), so the native/web
connection-resolution logic is solved exactly once and reused, not reimplemented per database.
No milestone should ever add a table that mixes canonical and mutable data in the same database,
and no milestone should destructively normalize canonical Quran text in place — normalized/
derived text belongs only in the search index database, per `docs/CLEAN_ROOM_RULES.md`'s Quran
correctness rules.

### 4a. The Quran data engine (Milestone 2)

`lib/quran/` is organized exactly along the `domain`/`data` split from §1:

- **`quran/domain/models/`** — plain, Drift-independent domain models (`Surah`, `Ayah`,
  `AyahWord`, `QuranScript`, `QuranScriptVariant`, `Mushaf`, `MushafLine`, `MushafPage`,
  `NavigationRange`, `Juz`, `Hizb`, `DatasetMetadata`), built with `freezed` for cheap value
  equality. `QuranScript` and `QuranScriptVariant` are two distinct types (a family and its
  editions) rather than one self-referencing type, unlike the single self-referencing entity the
  reference app uses internally for the same concept (`docs/reference/05_MUSHAF_SPEC.md` §7) — an
  independent modeling choice, not a copy.
- **`quran/domain/quran_dataset_payload.dart`** — `QuranDatasetPayload`, the seam between "where
  Quran data comes from" and "how it is imported." A dataset can be replaced entirely by
  constructing a different payload from a different source; neither `QuranRepository` nor its
  Drift implementation changes.
- **`quran/domain/dataset_integrity.dart`** — `DatasetIntegrityValidator`, pure Dart, no database
  required. Runs ten structural rules (exactly 114 surahs, contiguous ayah numbering per surah,
  unique/stable ayah ids, contiguous word indices, valid Mushaf page/line bounds, contiguous line
  numbers, valid line word-ranges, valid navigation-range bounds, no missing/blank verse text,
  present dataset version/hash) against a `QuranDatasetPayload` and returns a
  `DatasetIntegrityReport`. This is what makes "integrity tests fail loudly" concrete: every rule
  has a dedicated unit test asserting it fires (`test/quran/domain/dataset_integrity_test.dart`),
  not just a test that the validator exists.
- **`quran/domain/repositories/quran_repository.dart`** — the full `QuranRepository` interface
  (surahs, ayahs/words, batch verse-range loading, Mushaf pages/lines, Juz/Hizb/navigation lookup,
  location validation, dataset metadata). Superseded Milestone 1's placeholder four-method version
  now that this milestone owns the real contract.
- **`quran/data/tables/`** — the Drift `Table` definitions (`Surahs`, `SurahLocalizations`,
  `Ayahs`, `AyahWords`, `QuranScripts`, `QuranScriptVariants`, `Mushafs`, `MushafLines`,
  `NavigationRanges`, `DatasetMetadataEntries`), combined into `QuranDatabase`
  (`quran/data/quran_database.dart`) — schema only, per the same "database class declares tables,
  repository does the querying" convention `lib/core/database/app_database.dart` established.
  `QuranScripts`, `QuranScriptVariants`, and `Mushafs` use **caller-supplied**, non-autoincrement
  integer primary keys (like `Ayahs.id`) rather than autoincrement, because other rows in the same
  import batch reference them by id before they exist in the database — an autoincrement id
  can't be known ahead of the insert.
- **`quran/data/quran_mappers.dart`** — one-directional Drift-row-to-domain-model conversions, so
  no domain model or repository consumer ever sees a generated Drift type.
- **`quran/data/import/quran_dataset_importer.dart`** — `QuranDatasetImporter`: validates a
  payload (throwing `DatasetIntegrityException`, which carries the full report, if invalid),
  then replaces the database's content inside one transaction. This is the **only** code path
  allowed to write to the Quran database; `DriftQuranRepository` is read-only, enforcing
  `docs/CLEAN_ROOM_RULES.md`'s "never silently edit Quran text" at the architecture level, not
  just by convention.
- **`quran/data/repositories/drift_quran_repository.dart`** — `DriftQuranRepository`. Every
  batch-shaped method (`getVerseRangeWithWords`, `getWordsForLine`) issues a small, fixed number
  of queries regardless of range size — proven, not just asserted, by
  `test/quran/data/drift_quran_repository_test.dart`'s `CountingQueryInterceptor`, which wraps a
  test database's `QueryExecutor` and counts real `SELECT` statements sent to SQLite.
- **`quran/quran_providers.dart`** — the first two Riverpod providers in the app wired to a real
  implementation rather than left as bare interfaces: `quranDatabaseProvider` and
  `quranRepositoryProvider`.

Two non-obvious Drift lessons worth keeping in mind for every future table in this project:
1. **Never name a column the same as a `Table` DSL method** (`text`, `integer`, `boolean`,
   `dateTime`, `blob`, …). A column getter named `text` shadows the inherited `Table.text()`
   factory method it needs to call internally, which does not just misbehave at runtime — it
   corrupts `drift_dev`'s static analysis of the whole table with an opaque
   `FunctionExpressionInvocationImpl` cast error. `AyahWords`' text column is named `wordText` for
   exactly this reason.
2. **`part of` files share only their library file's own imports, not transitively-imported
   files' imports.** `quran_database.g.dart` is `part of quran_database.dart`, and its generated
   code references enums (`RevelationType`, `SajdahType`, …) declared in the domain model files.
   Those enums are visible to the *table* files (which import them directly), but not to
   `quran_database.dart` itself unless it also imports them directly — Dart imports are not
   transitive. `quran_database.dart` therefore imports every domain model file that defines an
   enum used by any of its tables, even though nothing in that file references those enums by
   name (documented inline with `// ignore: unused_import` at each one).

Dataset sourcing itself is not part of this milestone's deliverable — see
`docs/DATA_RESOURCE_REQUIREMENTS.md` for the researched candidate sources (Tanzil.net, Al Quran
Cloud, QUL) and their license status, none of which have been integrated yet.

## 5. Offline strategy

Per `docs/PROJECT_BRIEF.md`, the network is only ever used for optional resource
acquisition/updates and optional AI services — never for anything on the critical path of
opening the app or using already-installed content. Concretely:

- `ConnectivityService` (`core/networking`) exists to gate *download-triggering* affordances
  (e.g. disable a "Download" button while offline, or show a resource-update banner only when a
  manifest refresh actually succeeded), never to gate reading, search, bookmarks, or
  memorization against already-installed data.
- `ResourceDownloadService`/`ResourceRepository` (`core/downloads`) model resources as
  independently versioned and independently installable, mirroring the version-reconciliation
  pattern documented in `docs/reference/09_OFFLINE_RESOURCES_SPEC.md` §2 — an "outdated" resource
  keeps working with its last-installed version until the user chooses to update, it never stops
  working just because a newer version exists remotely.
- Every repository interface's read methods are expressed as returning local data synchronously/
  from a stream — no repository method signature in this milestone requires a live network call
  to satisfy a read.

## 6. Platform adapters

`PlatformCapabilities` (`core/platform/platform_capabilities.dart`) is the single place that asks
"can this platform do X" (background audio sessions, home-screen widgets, scheduled
notifications, native file storage). Per `CLAUDE.md`, feature code must ask this interface rather
than branch on `Platform.isAndroid`/`kIsWeb` inline. When a later milestone needs a new
platform-conditional capability, it is added here as a new getter, not as a new scattered check.

## 7. Web persistence

Two distinct mechanisms, matching two distinct data shapes:

- **`BrowserStorage`** (`core/storage/browser_storage.dart`) — small key/value data (preferences,
  the active locale, theme mode), backed by `shared_preferences`, which uses `localStorage` on
  the web and the native preferences store on Android/iOS. Already wired end-to-end in this
  milestone (`ThemeModeController`, `LocaleController`).
- **Drift over SQLite-WASM** (`core/database/database_connection.dart`) — structured relational
  data (the future Quran/User/Search databases), via `package:drift_flutter`'s `driftDatabase()`
  helper. On the web this compiles SQLite to WebAssembly and runs it in a Web Worker, using OPFS
  when available and falling back to IndexedDB otherwise (no code-level branch needed — `drift`
  makes that choice internally per-browser).

  The two required web assets (`web/sqlite3.wasm`, `web/drift_worker.js`) are **vendored into
  this repository**, downloaded from the `drift` package's own GitHub release tag that exactly
  matches the `drift` version pinned in `pubspec.yaml` (`drift-2.35.0` at the time of writing).
  They are intentionally committed (not gitignored) rather than fetched from a CDN at runtime,
  because a CDN dependency would silently violate this project's offline-first requirement for
  the web target. **When `drift` is upgraded, these two files must be re-downloaded from the
  matching release tag** (`https://github.com/simolus3/drift/releases/tag/drift-<version>`) —
  a mismatched version pairing is a real correctness risk, not just a lint concern.
  `flutter build web` copies them into `build/web/` automatically as part of the standard `web/`
  asset copy; this was verified by inspecting the build output. Serving them requires the
  `sqlite3.wasm` file be served with a `application/wasm` content type, which was verified against
  a plain static file server; this is the responsibility of whatever hosts the built web app, not
  of the Flutter app itself.

  Large downloaded resources (audio, fonts, atlas bundles) have no web storage strategy yet;
  `FileStorage`'s doc comment flags this explicitly as a gap for the Resource Manager milestone
  (13) to close, likely via the Origin Private File System API or IndexedDB-backed blob storage.

## 8. Audio architecture

`AudioController` (`core/audio/audio_controller.dart`) is the seam between UI and playback engine.
Milestone 1 ships `JustAudioController`, a minimal implementation wrapping `package:just_audio`
directly — enough to prove the interface is real (play/pause/seek/speed against an actual
player), but with **no background session** of its own. The Audio milestone (12) is responsible
for a second, `audio_service`-backed implementation providing the lock-screen/notification
controls and background playback survival that `docs/reference/08_AUDIO_SPEC.md` §1 documents as
essential reference behavior (backed by AndroidX Media3 there; Tahfeez's equivalent is
`audio_service`'s `AudioHandler`). Swapping implementations requires no change outside
`lib/core/audio/` because everything else depends on `AudioController`, not on `just_audio` or
`audio_service` directly. `AudioContentOption` and `AudioEndBehaviour`
(`core/audio/audio_models.dart`) already encode the reference vocabulary (Quran-only/
translation-only/both; stop/next-chapter/repeat-chapter) so the Audio milestone does not need to
invent or rename this vocabulary later.

## 9. Download/resource design

`ResourceDownloadService` and `ResourceRepository` (`core/downloads/`) are interfaces only in
this milestone. The intended shape they codify, informed by
`docs/reference/09_OFFLINE_RESOURCES_SPEC.md` §2-3: every downloadable resource (translation,
tafsir, reciter, word-by-word pack, atlas bundle, font) is identified by an opaque `resourceId`,
has an independently trackable `ResourceDownloadState`, and reports granular progress
(`ResourceDownloadProgress`) over a stream rather than a one-shot callback — because more than one
screen (a Settings download screen, a Home update banner, a Storage Cleanup screen) may need to
observe the same download simultaneously. The Resource Manager milestone (13) implements this
against real background download infrastructure (e.g. `WorkManager`-equivalent scheduling on
native, and a web-appropriate strategy) plus the per-resource version-tracking store the
interface implies.

## 10. Future AI boundary

`lib/ai/domain/` defines `RecitationRecognizer`, `RecitationContext`, and the `RecitationEvent`
sealed union (`started`, `positionCandidate`, `ayahDetected`, `wordMatched`, `wordSkipped`,
`wordIncorrect`, `hesitation`, `selfCorrection`, `confidenceUpdate`, `ended`,
`recognitionError`) — the full event vocabulary `docs/PROJECT_BRIEF.md`'s "AI" product area
needs, with **no implementation**. This means:

- `lib/memorization/` and any future AI-assisted review UI can be designed and built against a
  stable event stream shape well before a real recognizer exists.
- A concrete `RecitationRecognizer` is always optional and swappable (including a possible
  on-device implementation later, per `docs/PROJECT_BRIEF.md`), which is what makes "the app
  should be useful even if the AI features are never enabled" structurally true rather than just
  a stated goal.
- No milestone before the AI milestones (18-19) should implement this interface; they should only
  depend on it where wiring a future recognizer in is anticipated (e.g. a memorization session
  screen accepting an optional `RecitationRecognizer?`).

## 11. Testing strategy

- **Unit tests** for pure logic (breakpoint classification, the AI event union, future domain
  logic) live next to the code they test under `test/`, mirroring `lib/`'s structure.
- **Widget tests** exercise `TahfeezApp` end-to-end against real (not mocked) Riverpod providers
  where practical — `test/app_test.dart` proves theme mode and locale changes propagate through
  the real `MaterialApp.router` tree, including a genuine LTR→RTL `Directionality` flip, not just
  that a provider's value changed in isolation.
- **Database tests** open a real `AppDatabase` against an in-memory `NativeDatabase`
  (`package:drift/native.dart`) rather than mocking Drift's generated code, so schema mistakes
  and query bugs are actually caught. This pattern should be reused by every later milestone that
  adds a Drift database.
- **Platform-specific runtime verification.** `flutter test --platform chrome` does **not**
  serve the `web/` directory the way `flutter run -d chrome`/`flutter build web` do, so it cannot
  be used to exercise the real SQLite-WASM path end-to-end (a `driftDatabase()` call under that
  harness fails to fetch `sqlite3.wasm` — confirmed while building this milestone, and this is a
  test-harness limitation, not an application bug). The web database path was instead verified by
  (a) confirming `flutter build web` copies both vendored assets into `build/web/` unchanged, and
  (b) serving `build/web/` with a plain static file server and confirming `sqlite3.wasm` is
  returned with the required `application/wasm` content type. Before Milestone 2 lands real
  Quran data, it is worth adding a `flutter run -d chrome` (or `integration_test`-based) smoke
  test that actually opens the database in a live browser, since that is the one scenario this
  milestone's automated suite cannot cover.
- **Quality gate commands** (run after generating code — see `README.md`):
  `dart format --set-exit-if-changed lib test`, `flutter analyze`, `flutter test`,
  `flutter build apk --debug`, `flutter build web`. `flutter build ios` could not be run in this
  Linux development environment (no Xcode); iOS compatibility was instead verified structurally —
  no shared (non-`core/platform`) code references an Android- or Linux-specific API, and the
  standard `flutter create` iOS project template is present and untouched. A real iOS build must
  be verified on macOS before Tahfeez ships to iOS.

## 11a. The design system (Milestone 3)

`lib/core/theme/` is now Tahfeez's full production design system, not just the light/dark proof
Milestone 1 shipped. Everything in it uses the `Tahfeez*` naming the milestone suggested
(`TahfeezSpacing`, `TahfeezRadii`, `TahfeezBreakpoint`, etc.), superseding Milestone 1's `App*`
names.

**Tokens** (`core/theme/`, one file per concern): `app_spacing.dart` (`TahfeezSpacing`,
`TahfeezRadii`), `tahfeez_elevation.dart` (`TahfeezElevation` — deliberately shallow, per
`docs/DESIGN_DIRECTION.md`'s "restrained elevation"), `tahfeez_motion.dart`
(`TahfeezMotionDuration`/`TahfeezMotionCurves`), `tahfeez_icon_sizes.dart` (`TahfeezIconSize`),
`tahfeez_content_widths.dart` (`TahfeezContentWidth` — the constrained-reading-width cap used by
`TahfeezResponsiveScaffold`), `app_typography.dart` (`buildTahfeezTextTheme`), `app_colors.dart`
(the emerald/default exploration palette + `TahfeezColorTokens` extension for tokens with no
`ColorScheme` slot, e.g. the muted-gold accent).

**Color families** (`tahfeez_theme_families.dart`): `TahfeezThemeFamily` — 7 independently-chosen
seed colors (emerald/blue/burgundy/purple/violet/gold/monochrome), each producing a full light and
dark `ColorScheme` via `ColorScheme.fromSeed`. Emerald (the default) is special-cased to use
`docs/DESIGN_DIRECTION.md`'s exact exploration values instead of the algorithmic seed result,
since that document only gives concrete guidance for the default family. None of these hues or
names are drawn from the reference app's own preset-theme roster
(`docs/reference/18_VISUAL_REFERENCE_NOTES.md` §8 flags that roster as reference-only).

**Dynamic (Material You) color** (`lib/app/app.dart`, via `package:dynamic_color`): optional and
off by default (`DynamicColorPreferenceController`), matching this milestone's "support platform
dynamic/system color only where appropriate and optional." **Dependency note worth remembering**:
`dynamic_color` versions 2.0.0+ depend on a new standalone `material_ui` package and return *its*
`ColorScheme` type from `DynamicColorBuilder`, which is a different, incompatible class from
Flutter SDK's own `package:flutter/material.dart` `ColorScheme` that `MaterialApp`/`ThemeData`
still use in this Flutter version — passing one where the other is expected fails to compile with
a confusing "type X can't be assigned to type X" error (same name, different library). Pinned to
`dynamic_color: ^1.9.0`, the last major version before that split, which returns the SDK's own
`ColorScheme` directly. Revisit this pin (and the error) if the ecosystem migration to
`material_ui` completes and Flutter's own Material widgets adopt it too.

**Typography** (`app_typography.dart`, fonts in `assets/fonts/`): Noto Sans (Latin) with Noto Sans
Arabic registered as `fontFamilyFallback`, so any UI string mixing scripts renders both correctly
without the app detecting script itself. Both are single-file variable fonts (one file covers
every weight via the `wght` axis) under SIL Open Font License 1.1, bundled as local assets — not
fetched from Google Fonts at runtime — so the UI font never depends on network access, consistent
with this project's offline-first requirement. Recorded in `docs/THIRD_PARTY_RESOURCES.md` (its
first real entry) with checksums and the exact upstream commit fetched from. As always, this is
the **UI** typeface only; canonical Quran text will never render with it (see
`docs/DESIGN_DIRECTION.md`'s UI/Quran typography separation, already enforced structurally since
`buildTahfeezTextTheme` has no code path that could reach Quran content).

**Components** (`core/theme/components/`, barrel-exported from `components.dart`): all 19 named
in the milestone — `TahfeezAppBar`, `TahfeezCard`, `TahfeezSettingsTile`, `TahfeezSectionHeader`,
`TahfeezListRow`, `TahfeezActionChip`/`TahfeezFilterChip`, `TahfeezSegmentedControl`,
`TahfeezResourceRow`, `showTahfeezModalBottomSheet`, `showTahfeezConfirmationDialog`,
`TahfeezLoadingView`/`TahfeezEmptyView`/`TahfeezErrorView`, `TahfeezDownloadProgressRow`,
`TahfeezMiniPlayerShell`, `TahfeezQuranSectionCard`, `TahfeezVerseActionBar`, and
`TahfeezResponsiveScaffold` (bottom nav on phone, a `NavigationRail` from tablet upward, body
capped at `TahfeezContentWidth.maxReading` — the "do not stretch the phone layout across large
screens" rule). Every one is built only from the tokens above; none hardcodes a color, radius, or
spacing value.

**Icon set**: Flutter's bundled Material Symbols (`Icons`), already licensed as part of the SDK
(`uses-material-design: true`) and functionally independent of the reference app's own custom
drawable artwork — satisfies "use Material Symbols or another independently licensed icon set"
without adding a new dependency.

**Component gallery** (`core/theme/gallery/`): `ComponentGalleryScreen`, reachable at the
`/gallery` route (linked from the foundation demo screen, not from any user-facing navigation),
shows every component above across every theme family, both brightnesses, and both a supported
LTR (English) and RTL (Arabic) locale, plus `MemorizationStateGallery` — a placeholder sketch of
the 14 memorization visual states `docs/DESIGN_DIRECTION.md`'s "Memorization visual language"
section calls for (visible/hidden/partially-revealed text, current ayah/word, listening,
correct/skipped/incorrect word, hesitation, self-correction, weak memory range, scheduled
revision, completed session). Every placeholder uses plain English UI copy ("sample word"),
deliberately never anything resembling Quran text, per `docs/CLEAN_ROOM_RULES.md`'s Quran-
correctness rules — the real, session-wired implementation is the Memorization milestone's (17)
job; this only proves the visual vocabulary (overlays/opacity/underlines, never editing text
itself) reads clearly in every theme.

**A testing gotcha worth remembering**: `ComponentGalleryScreen` permanently displays an
indeterminate `CircularProgressIndicator` (the loading-state demo), which schedules a new frame
forever by design. `tester.pumpAndSettle()` can never settle on a screen with a permanent
indeterminate animation — every widget test that renders this screen uses a fixed number of
`tester.pump(duration)` calls instead. Any future screen with a permanent (not just
transient-during-fetch) indeterminate spinner will need the same test pattern.

## 11b. Navigation shell & Home (Milestone 4)

### Navigation architecture decision

Tahfeez uses a **shell-based** `go_router` model — `StatefulShellRoute.indexedStack`
(`lib/core/routing/app_router.dart`) wrapping three branches (Home, Quran, Search), each
rendered inside `lib/app/shell/app_shell.dart`'s `AppShell` widget — rather than the reference
app's own Activity-per-top-level-screen model (`docs/reference/03_NAVIGATION_MAP.md` §1-2). This
was chosen over a pushed-route model for two reasons that reference document's own §7 flags as
worth improving on:

1. Each branch (`StatefulShellBranch`) keeps its own independent navigation stack via a separate
   `Navigator`/`GlobalKey<NavigatorState>`, which the reference app's Activity boundaries only
   approximate — this matters once Quran's branch grows its own nested navigation (chapter list →
   reader) in later milestones, without disturbing Home's or Search's stacks.
2. A single, shell-level mini-player region (`lib/app/shell/mini_player_region.dart`) persists
   across every branch, instead of being re-created at every Activity boundary the way the
   reference app's mini player is described as doing. This is a genuine, deliberate improvement
   over the reference behavior, not a deviation for its own sake.

`Home` is now the app's real initial route (`AppRoutes.home = '/home'`, `initialLocation`).
Milestone 1/3's dev-proof screens (`FoundationDemoScreen`, `ComponentGalleryScreen`) moved to
non-shell debug routes (`/debug/foundation`, `/debug/gallery`) — reachable, but never linked from
user-facing navigation.

### Main navigation: the "Quran is prominent" component

Three destinations at this stage (Home, Quran, Search), per the milestone's explicit scope —
`Memorize` is reserved for Milestone 17 by simply being a fourth `TahfeezPrimaryNavItem`/
`StatefulShellBranch` to add later, not a structural change.

Rather than cloning the reference app's specific center-pill artwork for Quran access (which
`docs/CLEAN_ROOM_RULES.md` forbids anyway), Quran's visual prominence is a new, genuinely reusable
design-system component: `TahfeezPrimaryNavigationBar`/`TahfeezPrimaryNavigationRail`
(`lib/core/theme/components/tahfeez_primary_nav_bar.dart`). Exactly one `TahfeezPrimaryNavItem` per
list can be marked `isPrimary`, which renders as a raised, filled circle (built only from
`TahfeezElevation`, `TahfeezSpacing`, and the active `ColorScheme` — no new hardcoded color/shape)
instead of a plain icon+label. The same "Quran is prominent" identity holds on phone (bottom bar)
and tablet/desktop (side rail) using the same token treatment.

This intentionally is not a change to `TahfeezResponsiveScaffold` (Milestone 3): that component
stays a generic, uniform-destinations scaffold usable by any future screen that needs simple
navigation, while `AppShell` composes the bespoke primary-nav widgets directly (still reusing
`TahfeezContentWidth.maxReading` centering via a small private `_ConstrainedContent` helper, the
same width-capping rule `TahfeezResponsiveScaffold` encodes).

### Home information hierarchy

`lib/features/home/presentation/home_screen.dart` composes the reference-equivalent hierarchy as
one `SingleChildScrollView`-over-`Column` (not a lazy `ListView` — same "every widget must exist in
the tree for tests without scrolling first" reasoning as `ComponentGalleryScreen`, §11a):

1. A greeting header (`homeGreetingBandForHour`, `lib/features/home/presentation/home_greeting.dart`)
   — a pure, unit-tested hour→band mapping, satisfying "clear page greeting/title."
2. `HomeResourceUpdatesBanner` — hides itself entirely while
   `outdatedResourceSummariesProvider` is empty (always true today; no concrete
   `ResourceRepository` exists until Milestone 13), matching the reference app's own "shown only
   if" banner behavior.
3. `HomeDailyAyahSection` — a deterministic, date-seeded chapter/verse *reference* (never
   canonical Arabic text) via `dailyAyahSurahNoForDate`.
4. `HomeReadHistorySection` — permanently empty today; no `UserDataRepository` provider exists yet
   (Milestone 11).
5. `HomeMemorizationTeaserSection` — a concrete, visible placeholder for Today's Memorization/
   Today's Revision/Memorization progress, satisfying "do not paint the architecture into a
   reading-only corner" by literally reserving and showing the slot today rather than only
   architecting an invisible seam.
6. `HomeFeaturedReadingSection` — a horizontal rail over a small curated list of chapter
   *numbers* (`featuredReadingSurahNumbers`; structural metadata, not Quran text).
7. `HomeExploreSection` — an adaptive grid (2 columns phone, 4 tablet+) of category placeholders
   (Duas/Topics/Prophets/Science) drawn from `docs/PROJECT_BRIEF.md`'s own "Explore" product area,
   not the reference app's specific category roster/icons.

The persistent mini-player region (hierarchy item 6) is deliberately **not** part of this list —
it is mounted once at the `AppShell` level so it survives switching branches (see above).

### The "no Quran dataset installed" state

Milestone 2 built the Quran data engine's plumbing, but no app-boot step has ever imported a real
(or even synthetic) dataset into the live app's `QuranDatabase` — only tests exercise the importer,
against ephemeral in-memory databases. This means the running app's Quran database is genuinely
empty today, and Home is the first screen to have to confront that honestly.
`hasInstalledQuranDatasetProvider` (a `getSurah(1) != null` check, originally added here and
relocated to `lib/quran/application/quran_dataset_status.dart` in Milestone 5 once the Quran index
needed the same check — see §11c) is the single seam every Quran-data-dependent Home section
checks first, rendering an "unavailable resource" state (never fabricated content) when it's
`false` — which is the only state reachable in the shipped app until a real dataset import path
exists. This is the concrete form this milestone's "do not insert fake production Quran data" /
"implement intentional loading/empty/offline/unavailable-resource states" requirements take.

### Testing gotcha: `flutter test` cannot exercise real Drift/`just_audio` backends

`HomeScreen`/`AppShell` are the first screens to actually watch `quranRepositoryProvider` and
`audioControllerProvider` from a widget tree. Both real backends need a platform channel
`flutter test` does not provide (`drift_flutter`'s native SQLite path via `path_provider`;
`just_audio`'s real player), which otherwise leaves `pumpAndSettle()` stuck forever the first time
either provider is watched. `test/test_helpers/widget_test_overrides.dart` overrides
`quranDatabaseProvider` with a real in-memory `NativeDatabase` (the same "real Drift, test-safe
backend" pattern §11 already established) and `audioControllerProvider` with a small
`FakeAudioController` (no test-safe real backend exists for `just_audio`). Every widget test that
renders `TahfeezApp`/`AppShell`/`HomeScreen` must use these overrides.

## 11c. Quran Index and Navigation (Milestone 5)

### The unified location model

`lib/quran/domain/models/quran_location.dart` defines `QuranLocation`, a `freezed` sealed union
with exactly six variants: `surah`, `ayah`, `ayahRange`, `juz`, `hizb`, `page`. This is the single
domain concept every screen that jumps into Quran content is meant to describe its target with —
the Quran index today; Search, Bookmarks, and eventually the Reader itself in later milestones —
rather than each screen inventing its own navigation argument shape, per this milestone's explicit
"do not invent separate incompatible navigation argument schemes per screen" requirement. It is
pure Dart (no Flutter dependency), living in `quran/domain` alongside the rest of the read-domain
model types.

`lib/quran/domain/quran_location_path.dart` provides the one canonical, deep-link-safe string
serialization of a `QuranLocation` (`quranLocationPath`/`quranLocationFromPath`, e.g. `surah/2`,
`ayah/2/255`, `page/1/42`) — also pure Dart, reused by two independent consumers rather than
duplicated: `core/routing`'s literal `go_router` path templates, and
`lib/features/quran/application/quran_index_providers.dart`'s persisted "recent location" value
(the milestone's "remember recent/current context where appropriate" requirement, backed by
`BrowserStorage`).

### Routing: `core/routing`'s one documented exception

`lib/core/routing/quran_location_routing.dart` defines six `GoRoute`s (one per `QuranLocation`
variant, nested under the Quran branch) and the single `goToQuranLocation(context, location)`
helper every index result — and every future caller — must go through, per this milestone's
"every index result should route through `QuranLocation`... without screen-specific routing hacks"
requirement. `go_router` path parameters match exactly one segment each, so the six variants get
six literal path templates (`surah/:surahNo`, `ayah/:chapterNo/:verseNo`, …) rather than one
generic catch-all segment carrying the slash-bearing encoded string from
`quran_location_path.dart`.

This file, like `app_router.dart` itself (which has referenced feature screens directly since
Milestone 4), is a **documented exception** to §1's "`core` never depends on a feature" rule:
something has to wire concrete route paths to concrete screens, and that composition-root role
belongs to `core/routing` alone. No other file under `core/` may depend downward into `features/`
or a feature-owning domain area. `AppRoutes` was extracted into its own file
(`lib/core/routing/app_routes.dart`, re-exported from `app_router.dart` for existing importers) so
`quran_location_routing.dart` could depend on the path constants without an import cycle with
`app_router.dart`.

### The Quran index UI

`lib/features/quran/presentation/quran_index_screen.dart` is a four-tab `TabBar`/`TabBarView`
(Surah / Juz / Hizb / Page) plus a "Go to Ayah" app-bar action
(`lib/features/quran/presentation/go_to_ayah_sheet.dart`) — covering all five navigation modes
this milestone requires. Every tab and the quick action funnel through one `_select` callback that
records the location (`RecentQuranLocationController`) and calls `goToQuranLocation`.

- **Surah tab** (`tabs/surah_index_tab.dart`) — searchable (by number or name) and filterable (by
  revelation place). Chapter metadata comes from `quran_index_providers.dart`'s `indexedSurahs`,
  which resolves every chapter's Arabic and current-UI-language localized names via two *batched*
  `getAllSurahLocalizations` calls — never 114 individual `getSurahLocalization` lookups. This
  batch method is this milestone's one addition to `QuranRepository`/`DriftQuranRepository`,
  following the exact "small, fixed number of queries" discipline §4a established.
- **Juz/Hizb tabs** — all 30/60 units, each showing where it starts. Built by grouping a single
  `getNavigationRanges(NavigationUnitType.juz|hizb)` call client-side by `unitNo`
  (`_groupByUnit`) rather than querying `getJuz`/`getHizb` once per unit (30/60 queries) — the same
  batching discipline applied to a repository method that already existed but wasn't previously
  used this way.
- **Page tab** — a validated "go to page" entry (`isValidPage`) rather than one row per page (a
  Mushaf commonly has 600+ pages); a Tahfeez-owned take on "jump to any page" more appropriate to
  the medium than a giant list.
- No "Favourites" tab (the reference index's fourth tab, `docs/reference/02_SCREEN_INVENTORY.md`
  §5): that concept depends on bookmarks, which don't exist until Milestone 11 — a Page tab
  fills the fourth slot instead, matching this milestone's own explicit "Surah; Juz; Hizb; Page;
  direct Ayah selection" mode list instead of the reference app's exact tab roster.

`hasInstalledQuranDatasetProvider` moved from `features/home/application/home_providers.dart` to
`lib/quran/application/quran_dataset_status.dart` in this milestone, once the Quran index needed
the identical "is a dataset installed" check Home already had — per §1's "feature areas do not
depend on each other directly" rule, a check two features need is a `quran`-level concern, not one
feature's private implementation reused by reaching into another feature's `application/` folder.
This is the first file under `lib/quran/application/`; the project structure table in §2 predates
per-feature `application/` folders needing a shared, feature-spanning counterpart, and this is that
counterpart for the `quran` domain area specifically (mirroring how `quran/quran_providers.dart`
already serves every feature needing Quran data, not just one).

### The Reader stub

`QuranLocationStubScreen` (`lib/features/quran/presentation/quran_location_stub_screen.dart`) was
every index result's destination for this milestone: it resolved and displayed the real
`QuranLocation` a route parsed, proving the routing genuinely worked end to end, without building
Verse Reader UI that belonged to Milestone 6. `QuranPlaceholderScreen` itself was deleted,
superseded by the real `QuranIndexScreen`. Milestone 6 then superseded this stub in turn for five
of its six variants — see §11d.

## 11d. Verse-by-Verse Reader (Milestone 6)

### Every reading mode is one batched-loading engine, not six

`lib/features/reader/application/reader_session_controller.dart`'s `ReaderSession` (a
`QuranLocation`-keyed family provider) is the single engine behind every reading mode this
milestone requires — full Surah, verse range, individual Ayah, Juz, Hizb — plus "continuous
scrolling," which is modeled as a *behavior* (`loadMore()`, appending the next chapter once the
current content is exhausted) rather than a seventh mode, since it changes what happens at the
*end* of any session rather than how one starts. Every load goes through the existing
`QuranRepository.getVerseRangeWithWords` batch method (never a per-verse or per-word query, per
this milestone's explicit performance requirement), with a `_nextSurahNo` cursor tracking where
continuous scrolling should resume regardless of which mode the session started in.

`Ayah`-mode loads the *whole containing chapter* (scrolled to the requested verse), matching how
a "resume my position" deep link should feel; `ayahRange`-mode loads *only* the requested range
(a focused, quoted excerpt) — a deliberate distinction between "jump into this chapter at verse
N" and "show me exactly this range," both real, both useful, and both worth keeping distinct
rather than collapsing into one behavior.

### `ReaderLayoutItem`: one domain/presentation unit per milestone's own requirement

`lib/features/reader/domain/reader_layout_item.dart` is a `freezed` sealed union (`chapterInfo`,
`bismillah`, `chapterTitle`, `sectionMarker`, `verse`) — independently modeled from
`docs/reference/04_READER_SPEC.md` §13's `ReaderLayoutItem` concept, not copied. `ReaderVerseItem`
carries only immutable content (an `AyahWithWords`, straight from `QuranRepository`) — per this
milestone's "do not hard-code Quran text into widgets" requirement, no verse text of any kind is
ever a literal string in `lib/features/reader/presentation/`. Per-verse *mutable* state (selection,
future playback highlight) lives in `ReaderSessionState`, not in the content item, so the same
content never needs rebuilding just because its display state changed.

**The Bismillah is deliberately textless.** `ReaderBismillahItem` renders as a plain decorative
divider (`BismillahDivider`) with no Arabic glyphs at all — the Bismillah is canonical Quran text,
and this milestone's schema has no dedicated place to source it from independently of a real
Mushaf line/word dataset (Milestone 7). Hard-coding it as a UI string, even as a "just this one
fixed phrase" shortcut, would be exactly the kind of literal-Quran-text-in-a-widget this milestone
(and `docs/CLEAN_ROOM_RULES.md`'s Quran-correctness rules) forbids.

### Quran typography gets its own, separate token — still no real font

`lib/core/theme/quran_text_style.dart`'s `quranTextStyle()` is intentionally **not** part of
`buildTahfeezTextTheme`/`app_typography.dart`: per `docs/DESIGN_DIRECTION.md`, UI and Quran
typography are separate systems, and canonical Quran text must never render with Tahfeez's own
branded UI font (Noto Sans / Noto Sans Arabic). No real Quran-specific script/font has been
selected yet — `docs/DATA_RESOURCE_REQUIREMENTS.md` §5 explicitly defers that to the Mushaf
Renderer milestone (7), since a font choice is entangled with which Mushaf pagination dataset
ends up usable. `quranTextStyle()` leaves `fontFamily` unset, deferring to each platform's own
default Arabic-capable system font — distinct from (not a substitute for) a real Uthmani-style
typeface, but also not Tahfeez's UI font, honestly satisfying the separation rule until Milestone
7 lands. Arabic text always renders inside an explicit `Directionality(textDirection: TextDirection.rtl)`
wrapper regardless of the app's own UI locale.

### Real actions where genuinely possible, honest hooks elsewhere

Per this milestone's explicit "wire interfaces or intentional disabled states rather than fake
behavior": Copy (a verse's reference, `Clipboard`) and Share (a composed reference + Arabic-text
card with a working Copy button, `lib/features/reader/presentation/widgets/verse_share_sheet.dart`)
are genuinely functional today — no native OS share-sheet plugin dependency was added, since
`docs/reference/04_READER_SPEC.md` §9 flags exact share composition as reference-only and adding a
plugin is a deliberate product decision, not something to default into mid-milestone. Play,
Bookmark, and Tafsir are real, tappable `TahfeezVerseAction`s that show an honest "coming soon"
(no verse-audio source, no `UserDataRepository` implementation, and no Tafsir dataset exist yet —
Milestones 12, 11, 9 respectively). The Mushaf/Translation segments of `ReaderModeSwitch` are
visible but disabled the same way, per "architecturally ready for translation... audio, and
memorization" — switching to them shows "coming soon" rather than doing nothing or crashing.

### `showComingSoon` moved to `core/ui`

`lib/core/ui/coming_soon.dart` (moved from `features/home/presentation/coming_soon.dart`) is the
same relocation pattern §11c already established for `hasInstalledQuranDataset`: once a second
feature (the Reader, following Home and the Quran index) needed the identical "give honest tap
feedback for a not-yet-built destination" helper, it moved to `core` rather than being duplicated
or reached into across feature boundaries.

### A real correctness gap this milestone's own tests caught

`QuranRepository.getVerseRangeWithWords` returns **zero verses outright** — not "verses with empty
words" — when its `scriptCode` argument matches no installed `QuranScript` row. `ReaderSession`
originally read a hardcoded `defaultReaderScriptCode` constant directly; every reader test using
the synthetic fixture (which registers its own `testScriptCode`, not the production placeholder)
silently saw empty chapters instead of the fixture's real content, surfacing as "Juz/Hizb sessions
load zero verses" test failures with a correct-looking Juz/Hizb resolution underneath. The fix:
`readerScriptCodeProvider` wraps the constant, so tests can override which script a session loads
instead of the controller being hardwired to one value it can never be told to change — worth
remembering for any future "default X" constant a controller reads directly instead of through an
overridable provider.

### Persistence

`lib/features/reader/application/reader_preferences_controller.dart` follows the exact
`ThemeModeController` pattern (§11a): three independent, `BrowserStorage`-backed controllers for
continuous scrolling (on by default), Arabic-text visibility, and reader mode (always
`verseByVerse` today, persisted so a real mode switch is a one-controller change once Milestones 7
and 9 exist). "Current location"/"last read" (this milestone's other persistence requirement)
reuses §11c's `RecentQuranLocationController` rather than introducing a second, overlapping
persisted value — the Reader records into it once a session's content loads, exactly like the
Quran index's "Jump back in" chip does, since both are the same underlying concept.

## 11e. Accurate Mushaf Renderer (Milestone 7)

> **Superseded, historical record only**: the per-word rendering described here
> (`FontMushafLineRenderer`, `MushafLineRenderer`, `MushafWordPlacement`) was replaced by
> the line-level shaping architecture in §24 — those classes no longer exist. Kept
> as-is below for the historical decision record, per this document's own stated
> purpose; see `docs/MUSHAF_RENDERING.md` for the current, accurate architecture.

### A pure-Dart layout engine, injected with a measurer

`lib/features/mushaf/domain/mushaf_page_layout_engine.dart`'s `MushafPageLayoutEngine` is the
milestone's required "UI-independent `MushafPageLayoutEngine`": it depends only on an abstract
`MushafWordMeasurer` (`measure(text, fontSize) → width`), not on Flutter's `TextPainter` directly,
so the scaling/justification math is unit-testable with a fake, deterministic measurer
(`test/features/mushaf/domain/mushaf_page_layout_engine_test.dart`) with no widget pump or real
font shaping involved. The real measurer
(`lib/features/mushaf/presentation/text_painter_word_measurer.dart`, wrapping `TextPainter`) and
the engine instance that uses it
(`lib/features/mushaf/presentation/mushaf_layout_providers.dart`) live in `presentation/`, not
`application/` — `TextPainter` is a rendering concern, and wiring it to the pure engine must sit
on the presentation side of the `domain → application → presentation` dependency direction (§1),
never the reverse.

Per line, the engine: measures every word at a base font size, computes a scale (clamped to
`[minScale, maxScale]`) so the line's natural width roughly matches the available width, re-measures
at the resulting font size, then either justifies (distributes remaining space as inter-word
spacing, itself clamped so a very short line doesn't stretch into absurd gaps) or — for a
`isCentered` line (a Bismillah, a chapter heading, or a short final line of a chapter, per
`docs/reference/05_MUSHAF_SPEC.md` §2's convention) — leaves the line at its natural scaled width
for the renderer to center. The result (`MushafLineLayout`) always has `lineWidth <=
availableWidth` — the concrete "prevent clipping" guarantee — and every word's placement is
computed once as an explicit `(x, width)` pair, never left to a text layout's own line-breaking,
which is what makes "prevent accidental wrap" true by construction rather than by convention.

### Rendering: no wrapping widget, ever

`lib/features/mushaf/presentation/font_mushaf_line_renderer.dart`'s `FontMushafLineRenderer` paints
each word's placement as its own positioned `TextPainter` call inside one `CustomPainter` — never a
`Text`/`RichText` widget wrapping a whole line's words — the literal form of this milestone's "do
not render a page by placing all Quran text into one wrapping widget" requirement. Word hit testing
reuses the exact same placement geometry the painter draws from (a `GestureDetector.onTapUp` maps a
local tap position back to the placement whose `[x, x+width]` range contains it), so a tap always
maps to a real `(ayahId, wordIndex)` pair — the "Ayah/word mapping" this milestone requires for
future WBW (8), playback highlighting (12), and memorization overlays (17).

### The future atlas boundary

`lib/features/mushaf/presentation/mushaf_line_renderer.dart`'s `MushafLineRenderer` is the
milestone's required "replaceable interface for a future glyph-atlas renderer": `FontMushafLineRenderer`
is its only implementation today, selected via `mushafLineRendererProvider`
(`mushaf_layout_providers.dart`). Milestone 7B's optional atlas renderer is meant to be a second
implementation swapped in behind that same provider, with no change to `MushafPageView` or the
layout engine.

### Batched data loading

`QuranRepository.getWordsForPage` (added this milestone, alongside `getWordsForLine` from
Milestone 2) loads every word for every line of one page in a small, fixed number of queries —
never one query per line (~5-15 for a typical page) — mirroring the exact "batch, don't N+1"
discipline §4a established for verse ranges. `lib/features/mushaf/application/mushaf_page_providers.dart`'s
`mushafPageDataProvider` calls it once per page and slices the result per line in memory (the same
ayah-id/word-index boundary trimming `getWordsForLine` does internally for one line), rather than
querying per line itself.

### Reader appearance, independent of the application theme

`lib/features/mushaf/domain/mushaf_appearance.dart`'s `MushafAppearance` (Light/Warm/Sepia/Dark/
Black, per `docs/DESIGN_DIRECTION.md`'s "Reader themes") carries its own
`MushafAppearanceColors` — `MushafPageView` never reads `Theme.of(context)` for page background/
text color, per this milestone's explicit "do not let application card styling leak into the
Mushaf page" requirement. Persisted via `MushafAppearanceController`, the same `BrowserStorage`-backed
pattern as `ThemeModeController` (§11a) and the Reader's own preference controllers (§11d).

### Device modes and a real mode transition

`lib/features/mushaf/presentation/mushaf_reader_screen.dart`'s `_MushafPager` switches between a
single-page `PageView` (phone, or any portrait viewport) and a two-page spread (tablet-landscape or
a wide desktop viewport, lower-numbered page on the right per RTL book convention) based on
`TahfeezBreakpoint` and orientation. It intentionally does **not** try to preserve one
`PageController`'s position across a live switch between these two layouts (which use different
index-to-page-number mappings) — switching resets to the requested initial page instead of
remapping an in-flight scroll position. This is a deliberate, documented scope limitation, not an
oversight (see §18 below).

The Reader's `ReaderModeSwitch` (§11d) now has a genuinely working Mushaf segment: tapping it
resolves the topmost currently-loaded verse to a Mushaf page (`getPageForAyah`) and navigates
there — the same intent as the reference's `handleModeTransition` (carrying the reading position
across a mode change), independently implemented. `QuranLocation.page(...)` now opens the real
`MushafReaderScreen` everywhere it's produced (the Quran index's Page tab, this mode switch, any
future deep link), superseding the `QuranLocationStubScreen` placeholder from Milestone 5, which is
now deleted (nothing routes to it any more).

### A fourth relocation to `quran/application`

Two more concerns moved to the shared `quran/application` location this milestone, continuing the
pattern §11c/§11d established: the "default script code" constant/provider (previously duplicated
independently as `defaultQuranScriptCode` in the Quran index and `defaultReaderScriptCode` in the
Reader — consolidated into `quran/application/quran_script_code.dart`'s `quranScriptCodeProvider`
once the Mushaf renderer needed the identical concept a third time), and per-chapter localization
lookup (previously `readerChapterLocalizationProvider` in the Reader — moved to
`quran/application/quran_chapter_localization.dart`'s `chapterLocalizationProvider` once the Mushaf
renderer's chapter-header lines needed it too).

### Testing

`test/features/mushaf/mushaf_test_fixtures.dart` is a second, richer synthetic fixture (five
pages, distinct from `test/quran/quran_test_fixtures.dart`'s single-page one) modeling exactly this
milestone's five named representative-page scenarios: an opening chapter, the beginning of a
longer chapter, a plain mid-chapter page, a page spanning a chapter transition, and a final page
ending in a short centered line. Each is covered by layout-invariant tests
(`mushaf_pages_layout_test.dart` — expected line count/structure, no overflow, deterministic
placements, correct centering) rather than five separate pixel-golden images: with only synthetic
filler words standing in for real Quran text and no real script/font chosen yet, five pixel goldens
would mostly re-test the same rendering mechanism five times without adding real Mushaf-fidelity
coverage. One genuine pixel `matchesGoldenFile` test
(`mushaf_page_view_golden_test.dart`) still exists, locking in that the `CustomPainter`-based
renderer produces stable, deterministic output — the "golden test" infrastructure itself, proven
working, ready to gain real fidelity value once a real dataset and font exist.

## 11f. Scripts and Word-by-Word (Milestone 8)

### Scripts become a real, swappable preference

`QuranScript`/`QuranScriptVariant` and the storage-layer plumbing to support more than one script
(`Mushaf.scriptId`, `AyahWord.scriptId`-keyed word text, `getMushaf(scriptCode:)`) already existed
from Milestone 2 — this milestone made script *selection* real rather than architecturally-ready-
but-inert. `QuranRepository.getAllScripts()` (new) lists every script the installed dataset
provides; `lib/quran/application/quran_script_code.dart`'s `QuranScriptPreferenceController`
(`@Riverpod(keepAlive: true)`, persisted via `BrowserStorage` exactly like `MushafAppearanceController`)
replaces the previous hardcoded `defaultQuranScriptCode` constant as the source every Reader/Mushaf
session actually resolves against. `quranScriptCodeProvider` — the plain function every existing
call site and test already depended on — is kept as a thin derived provider
(`ref.watch(quranScriptPreferenceControllerProvider)`) rather than converted into the controller
itself, specifically so every existing `quranScriptCodeProvider.overrideWith((ref) => testCode)`
test override across the codebase kept working unchanged; only production code needed to start
reading the new controller (via a new "Quran script" picker in the Reader's options sheet,
`lib/features/reader/presentation/widgets/quran_script_sheet.dart`).

Because Reader and Mushaf already resolved every word/page lookup through `quranScriptCodeProvider`
rather than a hardcoded constant (a Milestone 7 decision), switching the controller's value is
sufficient on its own to change what both screens render — no code in either screen's own files
changed. `test/features/reader/presentation/reader_script_switch_test.dart` proves this end-to-end
against a new two-script fixture (`test/quran/multi_script_test_fixtures.dart`) where the two
scripts deliberately have different word text *and* different Mushaf page counts/pagination for the
identical canonical ayahs — this milestone's explicit "do not assume identical word strings/page
mappings/page count/line count" requirement, checked mechanically rather than only by code review.

### Word-by-word is its own resource, not a canonical-data extension

Per `docs/ARCHITECTURE.md` §4's data-model table ("Resource metadata (translations/tafsir/WBW/
audio/atlas) ... Milestones 8, 9, 12, 13"), WBW content is downloadable/optional resource data, not
canonical Quran data — even though it is keyed against canonical word indices. `lib/wbw/` is a new
top-level bounded area (sibling to `quran/`, `user_data/`, `memorization/`), with its own physically
separate Drift database (`lib/wbw/data/wbw_database.dart`, opened via the same
`core/database/database_connection.dart` helper the Quran database uses) rather than new tables on
`QuranDatabase`. `WbwRepository` (`lib/wbw/domain/repositories/`) exposes exactly the operations a
downloadable, versioned, deletable resource needs: `getInstalledPacks`/`getInstalledPack`,
`installPack` (an atomic replace-in-place, mirroring `QuranDatasetImporter`'s transactional-replace
shape — an "update" is just installing the same pack id at a newer version), `deletePack`, and a
single-word `getWord` lookup for the word detail sheet. `WbwLanguagePack` records the provenance
metadata `docs/CLEAN_ROOM_RULES.md`'s resource-provenance rules require (`source`, `license`,
`version`, `checksum`) as mandatory fields from day one, not something bolted on before a real pack
ships.

### No real network download yet — by design, not oversight

`core/downloads/`'s `ResourceDownloadService`/`ResourceRepository` interfaces (Milestone 1) are
explicitly reserved for the Resource Manager milestone's (13) real background-download
implementation. This milestone does not implement them for WBW; instead, `WbwPackCatalog`
(`lib/wbw/domain/wbw_pack_catalog.dart`) is a small, WBW-scoped "what's available to install"
interface with one production implementation, `NoWbwPackCatalog`, which honestly reports nothing
available — the same "no real dataset shipped yet" shape `hasInstalledQuranDatasetProvider` already
established for the canonical dataset itself. `WbwLibraryController`
(`lib/wbw/application/wbw_library_controller.dart`) merges installed packs with catalog packs into
one list of `(pack, ResourceDownloadState)` pairs and drives `install`/`remove` through the full
`notDownloaded → queued → downloading → completed`/`outdated`/`failed`/`deleting` state machine this
milestone's Definition of Done requires — real and independently testable
(`test/wbw/application/wbw_library_controller_test.dart`) even though, with no real catalog/network
yet, `install` performs its write immediately rather than actually taking time. `ResourceDownloadState`
gained a `deleting` value and `TahfeezResourceRowState` gained `queued`/`deleting` (previously
missing) specifically to make this full state list expressible — a small, deliberate extension to
Milestone 1's shared resource vocabulary rather than a WBW-only parallel enum.

### One word-tap seam, shared by both reading modes

`lib/quran/domain/models/quran_refs.dart`'s new `WordRef` typedef (`({int ayahId, int wordIndex})`)
is the identifier both reading modes now resolve a tap to and hand to
`lib/wbw/presentation/word_detail_sheet.dart`'s `showWordDetailSheet`. Verse-by-verse `VerseBlock`
previously rendered a whole verse's words as one joined `Text` string with no tap targets at all
(`docs/ARCHITECTURE.md` §17 flagged this as an explicit Milestone 6 deferral); it now renders each
`AyahWord` as its own `InkWell`-wrapped `Text` inside a `Wrap(textDirection: TextDirection.rtl)` —
individually tappable, still reading right-to-left, with no change to the batched
`getVerseRangeWithWords` data it already loaded. Mushaf's `_showWordInfo` (previously a placeholder
`SnackBar` showing only the raw ayah/word reference, per §18's explicit deferral) now calls the same
`showWordDetailSheet`, reusing the exact `(ayahId, wordIndex)` hit-testing `FontMushafLineRenderer`
already computed for Milestone 7's tap-to-placement mapping — no change to the renderer or the
layout engine. The sheet itself always shows the tapped word's Arabic text and ayah/word reference
(available from canonical data regardless of WBW); it shows translation/transliteration only once
`activeWbwPackProvider` resolves a real installed pack, and otherwise shows an honest hint with a
shortcut into the WBW packs sheet — the same "real, tappable, honestly-incomplete" shape `VerseBlock`'s
Play/Bookmark/Tafsir actions already established for features later milestones provide.

### Testing

`test/wbw/data/repositories/drift_wbw_repository_test.dart` covers the repository against a real
in-memory `WbwDatabase` (empty-by-default, install/read, update-in-place replaces old words, delete
removes both pack and words). `test/wbw/application/wbw_library_controller_test.dart` covers the
merge/state-machine logic against a fake `WbwPackCatalog`. `test/wbw/presentation/` covers the word
detail sheet's three states (no pack, pack with data, preference toggles) and the WBW packs sheet's
empty/install-to-downloaded flow. `test/quran/data/multi_script_repository_test.dart` and
`test/features/reader/presentation/reader_script_switch_test.dart` cover script-swapping at the
repository and full-UI layers respectively, per this section's earlier discussion.

## 11g. Translations and Tafsir (Milestone 9)

### A new shared presentation layer: `lib/quran/presentation/`

Milestone 1 already assigned `TranslationRepository`/`TafsirRepository` to `quran/domain/repositories/`
(§2: "they all describe read access to Quran-adjacent content"). This milestone extends that
decision one layer further: `lib/quran/presentation/` is a **new** folder holding UI that more than
one feature needs (`translation_block.dart`, `quick_reference_sheet.dart`, `translation_packs_sheet.dart`,
`tafsir_packs_sheet.dart`, `tafsir_reader_screen.dart`) — the same "shared-by-more-than-one-feature
belongs outside any one feature" rule `lib/wbw/presentation/` already established for word-by-word
(Milestone 8), applied here under `quran/` instead of a new top-level module, since translation/
tafsir domain models already live under `quran/`. `TafsirReaderScreen` in particular is reached from
both the verse-by-verse reader's Tafsir action and Mushaf's translation/tafsir sheet, so it could
never have been feature-local without violating "feature areas do not depend on each other
directly" (§1).

### Two more resource databases, same shape as WBW's

`lib/quran/data/translation_database.dart` and `lib/quran/data/tafsir_database.dart` are two more
physically separate `@DriftDatabase`s (per §4's "Resource metadata" row), each schema-only, each
paired with a `Drift*Repository` that is the only code path allowed to write to it. `TranslationBooks`/
`TranslationVerses` and `TafsirWorks`/`TafsirVerses` mirror `WbwPacks`/`WbwWords`'s "one metadata
table + one per-verse-or-word content table" shape; a translation verse's footnotes and cross-references
are stored as nullable JSON columns (`footnotesJson`/`crossReferencesJson`) rather than further
tables, since they're small, per-verse, and never queried structurally — a table per footnote would
add join cost for no real benefit.

### Resource safety made real without a real network

This milestone's explicit "Resource safety" requirement (staged, format-validated, checksum-verified,
activated atomically, never replacing a working resource with a corrupt download) is implemented as
a real, tested code path even though no network layer exists yet: `core/downloads/resource_integrity.dart`'s
`computeResourceChecksum` hashes a payload's canonical fields, and `DriftTranslationRepository`/
`DriftTafsirRepository`'s `install*` methods verify the computed hash against the resource's declared
`checksum` metadata *before* the same method's `_db.transaction()` deletes any previously-installed
data for that resource — a checksum mismatch (`ResourceChecksumMismatchException`) or an unsupported
`formatVersion` (`ResourceFormatVersionException`) throws before the transaction ever starts, so a
corrupt payload can never partially or fully replace working installed data. `test/quran/data/repositories/drift_translation_repository_test.dart`'s
"a failed checksum verification never touches a previously installed book" test proves this directly,
not just "installing a bad payload throws."

### Reader integration: batched per chapter segment, never per verse

`ReaderSessionState` gained `translationsByAyahId`/`translationBooks`; `ReaderSession` (`reader_session_controller.dart`)
loads every active translation's text for each chapter segment it already loads canonical words for,
via `TranslationRepository.getVerseRangeText` — the exact same "batch by range, not by verse"
discipline `getVerseRangeWithWords` already established (§4a), now applied to a second, independent
data source in parallel. `VerseBlock` renders one `TranslationBlock` per active translation under the
Arabic text, each showing footnote markers (`[n]` in the stored text) as individually tappable spans
opening the footnote's text, and cross-reference chips opening `showQuickReferenceSheet` — a
lightweight preview of a referenced verse's Arabic text with a "Go to verse" shortcut, independently
designed rather than a copy of the reference app's `AnnotatedString`/`QuickReference` markup. The
verse action bar's Tafsir button now opens the real `TafsirReaderScreen` (`core/routing/tafsir_routing.dart`'s
`openTafsirReader`) instead of "coming soon."

### Mushaf integration: a separate sheet, per this milestone's explicit instruction

`lib/features/mushaf/application/mushaf_page_translations.dart`'s `mushafPageTranslationsProvider`
derives which ayahs are on the current page for free from the page's own already-loaded word data
(`MushafPageBundle.wordsByLineNumber`'s `AyahWord.ayahId`s — no extra repository call needed just to
know which verses are present), then loads each active translation's text for each chapter segment
on the page in the same batched-by-range shape as the reader. `MushafReaderScreen` gained a
"Translation & tafsir" AppBar action (and, to support it, was converted from `ConsumerWidget` to
`ConsumerStatefulWidget` tracking `_currentPageNumber`, updated via `PageView.builder`'s
`onPageChanged`) that opens `showMushafTranslationSheet` — a page-scoped list of each ayah's active
translations plus a per-ayah "Tafsir" shortcut, reusing the same `TranslationBlock` the reader stacks
inline. The printed Mushaf page itself never gains any translation-related decoration, satisfying
this milestone's explicit "use a separate bottom/side sheet or panel so the printed page remains
visually clean" instruction literally.

### Resource-row UI reused, not duplicated

`translation_packs_sheet.dart`/`tafsir_packs_sheet.dart` mirror `wbw_packs_sheet.dart`'s shape
exactly (merge installed + cataloged into `TahfeezResourceRow` states, install/remove actions) —
this milestone's explicit "do not duplicate the reference settings/resource rows" instruction,
satisfied by reusing the same Tahfeez component three times rather than three bespoke rows.
Translations differ only in that a "completed" row toggles multi-select membership
(`TranslationSelectionController.toggle`) rather than single-select (`TafsirSelectionController.select`,
matching the reference app's own translations-multi-select/tafsir-single-select asymmetry, §5). Both
`TranslationCatalog`/`TafsirCatalog` follow `WbwPackCatalog`'s exact "no real implementation until
Milestone 13; production uses a catalog that honestly reports nothing available" shape.

### Testing

`test/quran/data/repositories/` covers both repositories' checksum/format-version verification,
install/update/delete lifecycle, and batched range reads. `test/quran/application/` covers both
library controllers' merge/state-machine logic and both selection controllers' persistence —
including a documented, deliberately-added `setUp` that clears each controller's `BrowserStorage`
key before every test, because these `keepAlive` controllers' fire-and-forget `_restore()` reads
from the same real, process-wide storage every test in a file shares, and can otherwise race with
and clobber a later test's own synchronous-looking mutations (discovered while writing
`TranslationSelectionController`'s reorder test, which failed intermittently with a `RangeError`
until this was fixed — worth remembering for any future `keepAlive`+`BrowserStorage` controller
test). `test/quran/presentation/` covers `TranslationBlock`'s footnote/cross-reference interaction
and `TafsirReaderScreen`'s no-tafsir/with-tafsir/previous-next states end-to-end through a real
`GoRouter`. `test/features/mushaf/presentation/mushaf_translation_sheet_test.dart` covers the
Mushaf sheet's empty and populated states.

## 11h. Advanced Offline Quran Search (Milestone 10)

### A fourth database, finally claiming §4's reserved row

`lib/quran/data/search_index_database.dart` is the "Search index database | Derived, normalized,
rebuildable text index | Milestone 10" row §4's table has reserved since Milestone 1 — the last of
the four databases that table originally planned for (the user-data database remains Milestone 11's
job). `ArabicSearchIndexEntries`/`TranslationSearchIndexEntries` hold only a normalized-text column
plus enough denormalized identity (ayahId/scriptCode or slug/chapterNo/verseNo) to resolve a hit back
to its canonical source — the index holds no canonical text of its own, so it can be dropped and
fully rebuilt from `QuranRepository`/`TranslationRepository` with zero data loss, the same property
§6 of `docs/reference/06_DATA_MODEL_SPEC.md` highlighted for the reference app's own derived search
database.

### FTS5 considered and deliberately not used

The milestone spec explicitly permits "SQLite FTS5 or an equivalent local indexed approach." Drift's
FTS5 support (`package:drift/extensions/fts5.dart`) requires the virtual table to be declared in a
`.drift` SQL file — a source-file type this project has never used, introducing new toolchain surface
for no real matching benefit here: FTS5's own tokenizer would still need custom configuration to
reproduce the exact Arabic diacritic-stripping/alef-folding `SearchNormalizer` already performs in
Dart, since `SearchNormalizer` must run identically over index content and queries regardless of
which storage mechanism holds the index (`docs/reference/07_SEARCH_SPEC.md` §3's "normalize both
sides the same way" requirement). Tahfeez instead stores pre-normalized text in an ordinary indexed
column (`@TableIndex` on `normalizedText`) and matches with `LIKE '%token%'`, ANDing one `LIKE`
clause per query token — functionally equivalent full-word/partial-word matching, expressed entirely
in the pure-Dart `Table` style every other table in this codebase already uses.

### SearchNormalizer: a scoped-down but honest equivalent

`lib/quran/domain/search_normalizer.dart` reproduces `docs/reference/07_SEARCH_SPEC.md` §3's Arabic
fold set (tashkeel/tatweel stripped, hamza-bearing alef variants folded to bare alef, alef-maksura
folded to yaa) exactly, but does not reproduce the reference's Unicode NFKC pass — no dedicated
Unicode-normalization dependency was added for it, since neither Arabic nor the ASCII/Latin-1 Latin
content this milestone targets has compatibility-decomposition forms that would matter for matching
at this milestone's scope. This is recorded as a deliberate, documented gap (§21), not a silent
omission, and is exactly why matched-term highlighting (`search_match_highlight.dart`) is applied
only to Latin-script (translation) results: highlighting Arabic results would need to map normalized
token positions back onto un-normalized, character-shifted canonical text, which `normalizeArabic`'s
character-folding makes unreliable to do correctly.

### Surah search needs no index at all

Rather than modeling a `SurahSearchAlias`-equivalent dataset — the reference app's own alias list is
exactly the kind of curated, proprietary dataset `docs/CLEAN_ROOM_RULES.md` forbids copying, and
Tahfeez has not sourced an independent one — Surah search matches directly against
`QuranRepository.getAllSurahLocalizations`, normalized and substring-matched in memory. 114 rows is
cheap enough to scan on every query, so this needed no persistent index, no rebuild step, and no new
canonical dataset most other search domains required.

### Quick links: pure and synchronous, no index dependency

`lib/quran/domain/quick_link_parser.dart`'s `QuickLinkParser` recognizes a verse (`2:255`), a verse
range (`2:255-257`), and a bare number as both a Surah and (when ≤30) a Juz — resolved purely from
the query's shape and the Quran's fixed structural constants (114 chapters, 30 Juz), with no
repository dependency at all, so quick links always resolve instantly regardless of index state.

### Ensuring indexes exist without a dataset-import trigger point

No milestone has ever wired a real Quran-dataset-import completion event (`docs/ARCHITECTURE.md`
§11b onward all note the shipped app's Quran database is empty), so there is nothing for indexing to
hook into automatically. `SearchController` (`lib/features/search/application/search_controller.dart`)
instead checks `isQuranTextIndexed`/`isTranslationIndexed` on each search and indexes lazily on first
use — correct, real, and fully tested, without inventing an import-pipeline hook this codebase has
no other use for yet.

### Testing gotcha: another `keepAlive`+`BrowserStorage` race, same fix as Milestone 9

`SearchHistoryController`/`SearchFiltersController` are `keepAlive` and persist to the same
process-wide `BrowserStorage` every test in a file shares — the exact race §11g's testing note
already documented for `TranslationSelectionController`. Both controllers' test files clear their
storage key in `setUp` for the same reason.

### Testing

`test/quran/domain/search_normalizer_test.dart` and `quick_link_parser_test.dart` cover the
normalization/tokenization rules and quick-link shapes directly (this milestone's explicit "test
representative Arabic normalization and exact/partial behavior" requirement).
`test/quran/data/repositories/drift_search_repository_test.dart` covers indexing, re-indexing,
multi-token AND matching, per-domain filtering, and translation-slug scoping against real in-memory
databases. `test/features/search/` covers both preference controllers and the search screen
end-to-end (empty/no-dataset/no-match states, typing a query, a quick-link result navigating through
a real `GoRouter`, the filter sheet actually changing what a subsequent search returns).

## 11i. Production Quran Data Integration (Milestone 9A)

### The gap this milestone closes

Every milestone since 2 shipped real repository/import/validation *machinery* against a
`QuranDatabase` that stayed empty in the real app — §11h's own testing note above records
this plainly. This milestone integrates real, licensed, source-verified data through that
existing machinery for three of the dataset's four layers (canonical Arabic text, Surah/
navigation metadata, translations, tafsir), and builds — but does not yet populate — the
architecture for the fourth (Mushaf page/line layout). `docs/QURAN_DATA_PROVENANCE.md` is
the authoritative per-resource record (exact editions, versions, content hashes, license
terms); this section is the architectural "how," not the provenance "what."

### No schema changes were needed for the canonical/translation/tafsir layers

`QuranDatasetPayload`, `DatasetIntegrityValidator`, `QuranDatasetImporter`,
`TranslationRepository`/`TafsirRepository`, and every table under `lib/quran/data/tables/`
already existed with exactly the shape real data needs — Milestone 2's "dataset can be
replaced without rewriting UI" design and Milestone 9's checksum-verified install path
turned out to be literally, not just aspirationally, true. The only genuinely new
production code is: the import tooling that turns real upstream files into these existing
shapes (`tool/quran_data/`), the JSON encoding those shapes are packaged in
(`lib/quran/data/import/dataset_json_codec.dart`), and the boot-time seeding step that
imports them (`lib/quran/data/import/bundled_dataset_seeder.dart`).

### Deterministic, re-runnable import tooling (`tool/quran_data/`)

- `fetch_sources.dart` — fetches Tanzil's text/metadata and QuranEnc's translation/tafsir
  sqlite exports over the live network into a gitignored `.cache/` directory. Re-running it
  reproduces byte-identical files (verified: two independent fetches in this session hashed
  identically).
- `src/tanzil_source.dart` — parses Tanzil's `surah|ayah|text` export plus its metadata XML
  into a `QuranDatasetPayload`. This is where the Bismillah-prefix parsing rule documented
  in `docs/QURAN_DATA_PROVENANCE.md` §1 lives, and where Tanzil's 240 quarter-Hizb
  boundaries are split into Rub (all 240) and derived Hizb (every 4th) `NavigationRange`
  rows, since Tanzil's own `<juzs>` element (not a derived value) already gives the 30 Juz
  boundaries directly.
- `src/quranenc_source.dart` — parses QuranEnc's shared `translations(sura, aya,
  translation, footnotes)` sqlite shape into `TranslationBook`/`TranslationVerseText` or
  `TafsirWork`/`TafsirVerseText`, including a regex-based split of QuranEnc's `[n] text`
  footnote blobs into structured `TranslationFootnote` entries (§3 of the provenance doc).
- `src/mushaf_layout_source.dart` — reads and structurally validates the real, vendored QUL
  layout file (see below); produces no `MushafLine` content.
- `build_production_data.dart` — the single orchestrator: fetch-checked, parsed, validated
  (`DatasetIntegrityValidator`, refusing to write anything on failure), then written to
  `assets/quran/*.json` plus `assets/quran/resource_manifest.json` (schema version, every
  source's content hash, every packaged asset's own content hash, and each blocked
  resource's explicit status string).
- `sqlite3` and `xml` were added as **dev dependencies** (`pubspec.yaml`) — used only by
  this tooling, never by the shipped app; `sqlite3` was already present transitively via
  Drift.

### Why JSON assets, not a pre-built Drift database file

The dataset is packaged as JSON (`assets/quran/quran_dataset.json`,
`translations/en_rowwad.json`, `translations/de_rowwad.json`, `tafsir/ar_muyassar.json`),
read at boot and imported through the *existing* `QuranDatasetImporter`/
`TranslationRepository.installTranslation`/`TafsirRepository.installTafsir` — not shipped
as a ready-made `.sqlite` file swapped in for the app's own database. A pre-built Drift
database file must exactly match the app's current Drift-generated schema version to open
safely; JSON decoded through the same domain models and written via the same
already-checksum-verified install paths every other resource in this codebase uses has no
such coupling, reuses 100% of already-tested validation logic, and costs one JSON-decode
pass at first launch (single-digit seconds for ~77k words) against a real, meaningfully
simpler on-disk story.

### `BundledDatasetSeeder`: verify hash, then import, one resource at a time

`lib/quran/data/import/bundled_dataset_seeder.dart` runs once at boot
(`lib/app/bootstrap.dart`, before `runApp` — via a `ProviderContainer` handed to
`UncontrolledProviderScope` rather than a lazily-created `ProviderScope`, so the same
container the seeded databases were opened on is the one the app actually runs with). For
each of the four assets: it loads `resource_manifest.json`'s `packagedAssetHashes`,
computes the sha256 of the *exact bytes* `rootBundle` returns for that asset, and refuses
to import anything whose hash does not match — "verify manifest/hash, then open the local
database," not "trust whatever bytes happened to load." Each resource then fails
independently:

- **Canonical Quran**: a hash mismatch or `DatasetIntegrityException` from the importer is
  logged as a critical error and the import is skipped — `QuranDatasetImporter` already
  guarantees this is all-or-nothing (one transaction), so a failure here can never leave a
  half-imported, partially-corrupt Quran on disk. An empty `QuranDatabase` (today's
  already-existing, already-handled state throughout the reader/Mushaf/search UI) is always
  the safe fallback, never a partially-written one.
- **Each translation/tafsir**: failures are caught and logged individually — a broken
  German translation file never prevents the English translation, the tafsir, or the
  canonical Quran from seeding successfully.

Already-seeded data is never re-imported redundantly: the canonical Quran compares its
existing `DatasetMetadata.contentHash` against the freshly-parsed payload's; translations/
tafsir compare `checksum`. A second `seedIfNeeded()` call (e.g. a subsequent app launch) is
a fast no-op once seeded, verified by
`test/quran/data/import/bundled_dataset_seeder_test.dart`'s "seeding twice" case.

### The Mushaf layer: architecture built, content deliberately withheld

The project owner provided one real file — QUL's KFGQPC V2 layout export
(`qpc-v2-15-lines.db`, vendored at `tool/quran_data/sources/qpc-v2-15-lines.db.zip`,
**not** ignored by git, since it cannot be re-fetched automatically) — and explicitly
instructed that no synthetic Mushaf layout data be created while a second, still-missing
file (QUL's companion word/script dataset, which resolves the layout's bare
`first_word_id`/`last_word_id` integers to real surah/ayah/word-index positions) remains
outstanding. Rather than waiting to build anything at all, this milestone built the full
seam that file will plug into without weakening that instruction:

- `lib/quran/domain/mushaf_data_source.dart` — `MushafDataSource` (a layout provider
  abstraction: "produce a `RawMushafLayout`"), `MushafWordIdResolver` (a separate
  abstraction: "resolve one word id to `(ayahId, wordIndex)`"), and `resolveMushafLines`
  (pure function: `RawMushafLayout` + `MushafWordIdResolver` → real `MushafLine` rows,
  throwing `MushafWordIdResolutionException` rather than guessing on an unresolvable id).
  Deliberately two separate abstractions, not one: a layout source and a word-id resolver
  are genuinely different upstream resources (per `docs/QURAN_DATA_PROVENANCE.md` §7), and
  QUL's own real files arrived exactly that way — one file with layout, no word file yet.
- `tool/quran_data/src/mushaf_layout_source.dart` — `QulKfgqpcV2MushafDataSource`, a
  concrete `MushafDataSource` that reads and structurally validates the real vendored file
  (604 pages, 15 lines/page, correct `surah_name`/`basmallah`/`ayah` line-type counts) —
  proven against the real file by `test/quran_data/qul_layout_source_test.dart`, not a
  hypothetical. It produces zero `MushafLine` content on its own; that step needs a
  resolver this codebase does not have.
- `build_production_data.dart` runs this validation and records its result
  (`mushafDataHash`, `mushafStatus: "SHIP_BLOCKED_PENDING_WORD_DATA"`,
  `mushafFontStatus: "SHIP_BLOCKED_LICENSE"`) in the manifest, but writes no `mushafs`/
  `mushafLines` into the shipped dataset — `payload.mushafs`/`payload.mushafLines` are
  empty lists, asserted directly by
  `test/quran_data/bundled_dataset_integrity_test.dart`'s "Mushaf layout status (honest,
  not fabricated)" group.

`MushafReaderScreen` already handled a `null` Mushaf gracefully before this milestone
(`_unavailable(...)`, pre-existing code) — real Surah/Ayah/translation/tafsir/search data
and an honestly-empty Mushaf reader now coexist correctly with no UI change required.

### Testing

`test/quran_data/bundled_dataset_integrity_test.dart` runs `DatasetIntegrityValidator`
against the real generated `assets/quran/quran_dataset.json` (not a synthetic fixture),
asserts 114 surahs with individually-checked ayah counts, exactly 6236 ayahs, exactly 15
Sajdahs, exactly 30/60/240/7 Juz/Hizb/Rub/Manzil units, the documented Bismillah-handling
behavior, every packaged asset's hash matching the manifest, and translation/tafsir
per-ayah completeness (every one of the 6236 canonical `(chapterNo, verseNo)` pairs has a
matching entry in each bundled translation/tafsir file — a real "no missing verse"
completeness check, not a total-count-only one).
`test/quran_data/qul_layout_source_test.dart` validates the real vendored QUL file's
structure directly. `test/quran/domain/mushaf_data_source_test.dart` tests the generic
word-id resolution *mechanism* with small synthetic fixtures (the established,
pre-existing pattern for testing generic logic — never used to fabricate Mushaf content
itself). `test/quran/data/import/bundled_dataset_seeder_test.dart` runs the full
verify-then-import boot path against real in-memory Drift databases and the real bundled
assets, asserting zero errors are logged and every resource ends up installed.

## 11j. Mushaf Token Schema and Production Import (Milestone 9B)

### `MushafToken`, not `MushafWord`

Once the project owner obtained QUL's real KFGQPC V2 word-by-word export
(`qpc-v2-word-by-word.db.zip`) alongside the layout file, a read-only compatibility audit
(documented in full in `docs/QURAN_DATA_PROVENANCE.md` §7b) found that QUL's word-id
stream is not purely Quran words: every printed ayah (with one confirmed, singular
exception, 37:130) carries a small ayah-end/verse-number ornament as its own addressable
id, immediately after that ayah's real words — confirmed by exact arithmetic
(83,668 total ids − 77,433 canonical words = 6,235, exactly the number of ayahs with a
marker). This directly shaped the schema: `lib/quran/domain/models/mushaf_token_models.dart`
defines `MushafToken` (never `MushafWord`, per explicit product decision, since "word"
would overclaim what every entry in this id stream actually is) and `MushafTokenType`
(`quranWord | ayahMarker | otherMarker | unknown`) as a model deliberately **separate**
from `AyahWord` — canonical Quran word semantics (search, sharing, word-by-word
translation, AI alignment) continue to use `AyahWord` exclusively; `MushafToken` is the
sole authority for the exact printed-Mushaf token sequence, markers included.

### A data-driven classifier, not a hardcoded rule

`lib/quran/domain/mushaf_token_classifier.dart`'s `MushafTokenClassifier` decides each
ayah's token classification by comparing that ayah's actual QUL token count against its
canonical `AyahWord` count — not by hardcoding "the last token of every ayah is a
marker." This is what lets it correctly detect ayah 37:130's real, singular exception
(zero tokens beyond its 4 canonical words) without a special case, and what makes it
safe against a hypothetical future anomaly: any per-ayah token count that isn't an exact
match or exactly one more is marked entirely `unknown` and reported as a
`MushafTokenClassificationWarning`, never guessed at. `MushafTokenType.otherMarker`
exists in the enum for a future source that might need it, but is never produced by this
classifier — no token pattern in the currently-vendored data warrants it.

### A direct nullable mapping, not a join table — because the data justified it

`MushafToken.canonicalWordIndex`/`canonicalAyahId` are plain nullable fields on the
token itself, populated only for `quranWord` tokens, rather than a separate
`MushafTokenCanonicalWordMap` table. This was an explicit two-way instruction: use the
direct mapping *if and only if* real-data validation shows it is reliable. The audit
validated it exhaustively (every ayah's tokens sort identically by id and by
QUL-reported word-position; every ayah's real-word count, once its trailing marker is
excluded, matches its canonical count) before this design was chosen — it was not
assumed up front. There is also no `canonicalAyahWordId` field: `AyahWord` has no
surrogate key of its own (identified by the composite `(ayahId, scriptId, wordIndex)`),
so `canonicalAyahId` + `canonicalWordIndex` are already the complete, minimal join key.

### `MushafLine` redesigned around token ids, not ayah/word-index ranges

Populating real data forced a schema correction: `MushafLine` originally carried
`startAyahId/startWordIndex/endAyahId/endWordIndex` (a design that predates any real
Mushaf word data). Once §7b's ayah-marker finding was confirmed, that shape became
provably wrong — a line spanning a marker token cannot be expressed as an ayah/word-index
range at all, since a marker has neither. `MushafLine` now carries
`firstTokenId`/`lastTokenId` (raw [MushafToken.sourceTokenId] bounds, copied directly from
QUL's own `first_word_id`/`last_word_id` with no resolution step —
`mushafLineFromRaw` in `lib/quran/domain/mushaf_data_source.dart` is now a plain field
copy, replacing the earlier `MushafWordIdResolver`/`resolveMushafLines` machinery that
this correction made unnecessary). `Mushaf` itself also gained real fields this milestone
needed and the original schema never had: `qiraah`, `edition`, and a
`MushafRenderingType` enum (`pageSpecificGlyphFont` for QUL's per-page-font scheme,
`unicodeText` reserved for a future plain-text Mushaf source) — deliberately real Mushaf
metadata, not a UI assumption, per explicit instruction.

### Repository surface: `getLineTokens`/`getPageTokens` replace the AyahWord-based methods

`QuranRepository.getWordsForLine`/`getWordsForPage` (AyahWord-returning, added when
Mushaf data was still hypothetical) are removed, not deprecated-and-kept: they had
exactly two callers, both in the Mushaf rendering pipeline, and both needed to become
token-based regardless, so keeping an AyahWord-shaped version around would be dead
surface no other code exercises. `getLineTokens(MushafLine)`/`getPageTokens({mushafId,
pageNumber})` (`lib/quran/data/repositories/drift_quran_repository.dart`) do the same
two-query-per-page batching discipline the methods they replace already established,
now against `MushafTokens`. `getJuzForPage`/`getHizbsForPage`/`getPageForAyah` were
adapted to resolve through a token's own `surahNumber`/`ayahNumber` fields (populated for
every token, markers included) rather than a line's old `startAyahId`, with the same
N-queries-per-unique-ayah-on-the-page cost the original implementation already had — not
a regression, since page-level Juz/Hizb lookups were never claimed to be O(1).

### The Mushaf renderer, wired to tokens instead of AyahWord

`MushafWordPlacement` (`lib/features/mushaf/domain/mushaf_line_layout.dart`) now carries
`sourceTokenId`/`tokenType`/nullable `canonicalAyahId`/`canonicalWordIndex` instead of a
required `ayahId`/`wordIndex` pair, and `MushafPageLayoutEngine.layoutLine`/`layoutPage`
take `List<MushafToken>` instead of `List<AyahWord>` — the line-fitting/justification math
itself is unchanged (it only ever needed each item's display text and a width), so this
was a rename-and-retype exercise, not a rewrite of the layout algorithm.
`MushafReaderScreen._showWordInfo` now checks `tokenType == MushafTokenType.quranWord`
before opening the word-detail sheet — an `ayahMarker`/`otherMarker`/`unknown` token
renders normally (same painter, same hit-testable region) but produces no word lookup,
concretely realizing "markers render normally but do not return a canonical Quran word."

### Production import: real data, generated to a deliberately non-bundled asset

`tool/quran_data/src/mushaf_import.dart` combines a `MushafDataSource` (layout) and a
`MushafTokenSource` (word-by-word) through `MushafTokenClassifier`, using canonical word
counts computed from the already-parsed Tanzil payload, and refuses to proceed if the
classifier reports any warning (an unresolved token pattern must never be silently
imported). `tool/quran_data/build_production_data.dart` runs this, validates the
**combined** canonical+Mushaf payload through `DatasetIntegrityValidator` (exercising the
Mushaf-specific checks below), and writes `assets/quran/mushaf/kfgqpc_v2.json` — 9,046
`MushafLine` rows, 83,668 `MushafToken` rows (77,433 `quranWord`, 6,235 `ayahMarker`, 0
`otherMarker`, 0 `unknown`), verified deterministic (byte-identical output across two
independent runs against the same source files). This file is **not** declared in
`pubspec.yaml`'s asset list: QUL's redistribution terms for the layout and word-by-word
resources are still unverified (`SHIP_BLOCKED_LICENSE`), so real, fully-validated Mushaf
data now exists and is exercised by tests, without being distributed as part of a real
app build until that license question resolves — the release gate is about
*distribution*, not about whether the data pipeline itself works.

### Validator additions: token ids and canonical mappings are scoped per-Mushaf

`DatasetIntegrityValidator` gained `_checkLineTokenRanges` (replacing the old
ayah/word-index range check), `_checkMushafTokenIds`, and
`_checkMushafTokenCanonicalMapping` — the last of which is also what makes "a marker must
never receive a fabricated canonical reference" a build-breaking invariant, not just a
classifier convention. All three scope uniqueness/resolution by `(mushafId,
sourceTokenId)`, not by `sourceTokenId` alone — a real bug caught while adapting this
milestone's own multi-Mushaf test fixture: two independent Mushaf editions are not
guaranteed to share a token-id numbering scheme, so the same numeric id can validly mean
a different token in a different Mushaf.

### The QCF V2 font: obtained, not yet packaged

The real 604-file, page-specific TTF font package (confirmed via direct `cmap`
inspection: identical codepoints draw different glyphs per page) is in hand but
deliberately not committed to git pending a packaging-strategy decision — seeing the
data pipeline through to a real, tested Mushaf dataset first, then evaluating font
packaging as its own decision, per explicit instruction not to build a complicated
packaging system before that comparison is presented. See
`docs/QURAN_DATA_PROVENANCE.md` §8 for the comparison itself.

### Testing

`test/quran/domain/mushaf_token_classifier_test.dart` covers the classifier's decision
rules with small synthetic fixtures (testing the generic mechanism, never treated as
real Mushaf content). `test/quran_data/qul_word_by_word_source_test.dart` classifies
every one of the real 83,668 tokens against the real bundled canonical dataset.
`test/quran_data/mushaf_production_integrity_test.dart` validates the **generated
production asset** itself (not just importer sources): page coverage, line counts,
token-range resolution, the full token-type breakdown, the 37:130 exception, and that
every canonical mapping resolves to a real `AyahWord`.
`test/quran_data/mushaf_representative_pages_test.dart` imports the real combined
dataset into an in-memory Drift database through the same `QuranDatasetImporter`/
`DriftQuranRepository` path the real app uses, and materializes pages 1, 2, 106 (a real
Surah transition — An-Nisa's last ayah into Al-Ma'idah's header), 302 (a representative
middle page), and 604, reporting line/token counts and first/last Quran location for
each.

## 11k. Mushaf Rendering and Font Packaging (Milestone 9C)

> **Partially superseded**: the per-word `FontMushafLineRenderer` this section
> describes was replaced by line-level shaping in §24 (`MushafPagePainter`,
> `MushafPageRenderModel`). The font-packaging/`QpcPageFontManager` material below is
> still current and unaffected — see `docs/MUSHAF_RENDERING.md` for the up-to-date
> combined picture.

Once real Mushaf line/token data existed (§11j), this milestone connected it to the
actual renderer and to the real QPC V2 page-specific font system, and made the
production data reach the app's own local database at boot rather than only a
build-tool output file. Full detail lives in two dedicated documents rather than here,
since both are substantial enough to need their own space:

- **`docs/MUSHAF_RENDERING.md`** — the full pipeline
  (`MushafRepository` → `MushafLine`/`MushafToken` → `QpcPageFontManager` →
  `MushafPageLayoutEngine` → `FontMushafLineRenderer`), the generated, per-file-verified
  page→font manifest (`tool/quran_data/build_qpc_fonts.dart`,
  `PageFontManifest`/`PageFontManifestEntry`), the lazy `FontLoader`-based loading
  design (concurrency-safe, ±2 preload radius, no eviction — Flutter has no supported
  API to unregister a loaded font family), and the Riverpod-provider-based race safety
  that keeps rapid page swiping correct.
- **`docs/OFFLINE_MOBILE_ARCHITECTURE.md`** — the boot-time seeding flow, the
  cheap-manifest-first check `BundledDatasetSeeder` uses to avoid re-parsing large JSON
  on every launch, per-resource failure isolation, and the measured (this-sandbox-only)
  app size impact of bundling the font package.

### `MushafLine`'s and `AyahWord`'s field-level schema were not changed for this

Every schema decision from Milestone 9B (`firstTokenId`/`lastTokenId`, `MushafToken`
separate from `AyahWord`, per-`(mushafId, sourceTokenId)` uniqueness) is unchanged —
this milestone is entirely about *connecting* that already-correct schema to a real
renderer and a real font system, not revising it. `MushafPageLayoutEngine` and
`MushafWordMeasurer` gained a `fontFamily` parameter (so justification math measures
with the same font that will actually paint the glyphs), and
`MushafWordPlacement`/`MushafLineRenderer.buildLine` gained the same, but no line's
token membership, no line's page assignment, and no token's canonical mapping changed.

### The one honestly-unresolved architectural gap

`BundledDatasetSeeder` and `qpcPageFontManifestProvider` refuse to import/load the
Mushaf dataset and font package when `kReleaseMode` is true, which stops *the running
app* from displaying this content in a release build. It does not stop the *asset
bytes* from being physically included in a release package — verified directly: a real
`flutter build appbundle --release` produced a 204.9MB AAB still containing the full
font package and Mushaf dataset, since Flutter's asset system has no per-build-type
exclusion without a product-flavor setup, which this milestone did not implement. This
is recorded as a real, open item in `docs/QURAN_DATA_PROVENANCE.md`'s release checklist,
not papered over — resolving it (via a flavor, or via removing the asset declarations
before a real release build) is required before any public distribution, independent of
whether QUL's redistribution terms are ever cleared.

## 12. What Milestone 1 deliberately did not do

- No feature screens (Home, Reader, Search, Settings, ...) — only the one foundation-proof
  screen, per the milestone's explicit scope.
- No concrete implementations of `QuranRepository`, `TranslationRepository`,
  `TafsirRepository`, `SearchRepository`, `UserDataRepository`, `ResourceRepository`, or
  `MemorizationRepository` — interfaces only, by design (§3). (`QuranRepository` gained a real
  implementation in Milestone 2 — see §13.)
- No `audio_service` background session wiring (§8) — only a minimal foreground `just_audio`
  implementation to prove the seam.
- No actual Quran data, translations, tafsir, or downloadable resources of any kind.
- No AI recognition implementation of any kind (§10) — interfaces only, as the milestone
  explicitly requires.

## 13. What Milestone 2 deliberately did not do

- No real Quran text/dataset of any kind — every test uses the clearly-labeled synthetic fixture
  in `test/quran/quran_test_fixtures.dart`, never anything resembling actual Quran content.
  `docs/DATA_RESOURCE_REQUIREMENTS.md` records candidate sources for a future milestone to
  actually integrate, once licensing is verified and recorded in `docs/THIRD_PARTY_RESOURCES.md`.
- No script/font rendering assets or decisions — flagged as out of scope for a later
  Mushaf/Design-System milestone in `docs/DATA_RESOURCE_REQUIREMENTS.md` §5.
- No `TranslationRepository`, `TafsirRepository`, or `SearchRepository` implementations — still
  interfaces only, owned by their respective later milestones (9, 9, 10).
- No UI whatsoever — this milestone is explicitly "primarily non-visual," and no screen depends
  on `quranRepositoryProvider` yet.

## 14. What Milestone 3 deliberately did not do

- No Quran/Mushaf rendering font or atlas decision — `docs/DATA_RESOURCE_REQUIREMENTS.md` §5
  already flags that as a later Mushaf/Design-System-adjacent decision; the Noto Sans/Noto Sans
  Arabic pair chosen here is explicitly the **UI** typeface only.
- No real feature screens — the component gallery and the extended foundation demo screen are
  proof/dev tooling, not Home/Reader/Search/Settings, per this milestone's own framing ("the
  visual foundation for all future UI," not the UI itself).
- No reader-specific theming (the "Light / Warm / Sepia / Dark / Black" reader appearances
  `docs/DESIGN_DIRECTION.md` §"Reader themes" describes) — that is separable from the application
  theme built here and belongs to the Reader/Mushaf milestones, which will read the same token
  files rather than reinvent them.
- No motion applied to route transitions — `TahfeezMotionDuration`/`TahfeezMotionCurves` are
  defined and available, but wiring them into `go_router`'s page-transition builders is deferred
  until real routes exist to transition between (Milestone 4+).

## 15. What Milestone 4 deliberately did not do

- No Quran Index & Navigation (chapter/Juz/Hizb/page lists) — `QuranPlaceholderScreen` only proves
  the shell's second destination is real and discoverable; the real navigator lists are Milestone
  5's job.
- No full-text search — `SearchPlaceholderScreen` only proves the third destination is real; real
  search (and its own derived search-index database, §4) is Milestone 10's job.
- No real Quran dataset import wired into the running app — the live app's `QuranDatabase` is
  genuinely empty (see §11b); a real import path is a data-sourcing concern outside this
  milestone's scope (`docs/DATA_RESOURCE_REQUIREMENTS.md`).
- No `UserDataRepository` or `ResourceRepository` implementations — `HomeReadHistorySection` and
  `HomeResourceUpdatesBanner` depend on provider seams that resolve to empty today, by design,
  until Milestones 11 and 13 respectively supply real data.
- No route-transition animations — same deferral as Milestone 3 (§14), now genuinely applicable
  since real routes exist; still deferred, as motion polish is not this milestone's scope.
- No memorization functionality — `HomeMemorizationTeaserSection` is a visible placeholder only,
  proving the Home layout can hold the section; the real dashboard is Milestone 17's job.

## 16. What Milestone 5 deliberately did not do

- No Verse Reader — `QuranLocationStubScreen` only proves a `QuranLocation` route resolves
  correctly end to end; rendering actual Quran content at that location is Milestone 6's job.
- No Favourites tab — that concept depends on bookmarks, which don't exist until
  `UserDataRepository` is implemented (Milestone 11); a Page tab fills the fourth slot instead
  (§11c).
- No Sajdah or chapter-length filter on the Surah tab — the reference index's exact filter set is
  reference-only per `docs/CLEAN_ROOM_RULES.md`'s "functional parity is acceptable, not
  mandatory"; only a revelation-place filter and search were built, since those need no new
  repository method beyond fields the domain model already has.
- No script/Mushaf selection UI — `defaultQuranScriptCode` (`quran_index_providers.dart`) is a
  single hardcoded placeholder value the Page tab depends on until Settings/Localization
  (Milestone 14) supplies a real user preference.
- No real Quran dataset import — same gap as Milestone 4 (§11b); the Surah/Juz/Hizb/Page tabs all
  render their honest "unavailable resource" state in the shipped app today.

## 17. What Milestone 6 deliberately did not do

- No Mushaf/Translation reading modes — `ReaderMode` reserves both, but only `verseByVerse` is
  implemented; the mode switch shows them disabled with "coming soon" (Milestones 7, 9).
- No real Quran/Mushaf font — `quranTextStyle()` exists as a separate token from the UI theme, but
  still resolves to each platform's default system font, not a real Uthmani-style typeface; that
  selection is Milestone 7's job (§11d, `docs/DATA_RESOURCE_REQUIREMENTS.md` §5).
- No real Bismillah text — `ReaderBismillahItem` is a textless decorative marker; sourcing the
  actual Bismillah glyphs needs a real Mushaf line/word dataset (Milestone 7).
- No word-by-word tap interaction, footnotes, similar-verses, or a Verse Options sheet — all
  explicitly deferred by the milestone itself to later WBW/translation/tafsir milestones (8, 9).
- No native OS share-sheet integration — Share composes real, copyable text in Tahfeez's own
  sheet; adding a `share_plus`-style plugin dependency is deferred as a separate product decision.
- No real Play/Bookmark/Tafsir behavior — genuinely wired, tappable actions that honestly report
  "coming soon" until verse audio (Milestone 12), `UserDataRepository` (Milestone 11), and a
  Tafsir dataset (Milestone 9) exist.
- No audio-driven auto-scroll or "current playing verse" highlighting — the reader's `ScrollController`
  and `GlobalKey`-based scroll-to-verse mechanism are the same machinery that behavior would reuse,
  but no audio position-to-ayah mapping exists yet to drive it (Milestone 12).
- No collapsing/scroll-linked app bar — a plain, non-collapsing `AppBar` satisfies "quieter than
  Home" without the added complexity of a physics-based collapsing header; real motion polish is
  deferred, consistent with Milestone 3/4's own deferrals (§14, §15).
- No real Quran dataset import — same gap as every milestone since 2; every reading session in the
  shipped app renders its honest "unavailable resource" empty state today.

## 18. What Milestone 7 deliberately did not do

- No glyph-atlas rendering — `MushafLineRenderer` defines the replaceable boundary
  (`FontMushafLineRenderer` is the only implementation); the atlas renderer itself is the explicitly
  optional, explicitly later Milestone 7B, which this milestone's spec says to attempt only once
  "the regular Mushaf renderer is already correct and stable."
- No real Quran/Mushaf font or real Bismillah text — same gap as recorded for Milestone 6 (§17);
  `quranTextStyle()`/`MushafPageView`'s Bismillah marker still resolve to platform defaults and a
  textless divider respectively, both pending a real dataset and font (Milestone 7B /
  `docs/DATA_RESOURCE_REQUIREMENTS.md` §5).
- No script/Mushaf-edition selection UI — `quranScriptCodeProvider`'s placeholder default (§11e)
  is still the one value every Mushaf/Reader session resolves against, pending Settings (Milestone
  14).
- No live-position preservation when switching between single-page and two-page-spread layouts
  (e.g. on device rotation) — `_MushafPager` resets to the requested initial page instead of
  remapping an in-flight `PageController` position across two different index schemes; a deliberate
  scope trim (§11e), not an oversight.
- No five-scenario pixel-golden suite — the five representative pages this milestone names are
  covered as layout-invariant tests instead (§11e); one pixel `matchesGoldenFile` test proves the
  golden-test mechanism itself works.
- No word-by-word tooltip/translation content on tap — tapping a Mushaf word shows only its raw
  ayah/word reference; real WBW content is Milestone 8's job, which reuses the same tap-to-placement
  hit-testing this milestone builds.
- No audio/memorization highlighting on the Mushaf page — the same `onWordTap`/placement-based seam
  Milestone 8 will use is also what Milestones 12 (playback highlighting) and 17 (memorization
  overlays) are meant to reuse, per `MushafLineRenderer`'s doc comment; none of that wiring exists
  yet.
- No real Quran dataset import — same gap as every milestone since 2; the shipped app's Mushaf
  pages render their honest "unavailable resource" state until a real dataset exists.

## 19. What Milestone 8 deliberately did not do

- No real WBW manifest or network download — `WbwPackCatalog`'s only implementation
  (`NoWbwPackCatalog`) honestly reports nothing available; `core/downloads/`'s generic
  `ResourceDownloadService`/`ResourceRepository` interfaces remain unimplemented, reserved for the
  Resource Manager milestone (13), per those interfaces' own doc comments. `WbwLibraryController.install`
  performs its write immediately rather than actually downloading bytes over time — every DoD-required
  resource state is real and reachable, but "downloading" has no real progress percentage to report
  yet (§11f).
- No real WBW content ships — `WbwPackCatalog`, `WbwRepository`, and every test exercising them use
  clearly-labeled synthetic fixture data (`test/wbw/wbw_test_fixtures.dart`), never a real
  translation/transliteration corpus; per `docs/CLEAN_ROOM_RULES.md`'s resource-provenance rules, no
  real WBW dataset's rights have been verified or recorded in `docs/THIRD_PARTY_RESOURCES.md`, so
  none ships.
- No script-picker entry point from the Mushaf reader itself — only the Reader's options sheet
  exposes `quran_script_sheet.dart` today (no Settings screen exists yet, Milestone 14). Mushaf
  already benefits from script changes immediately because it reads the same
  `quranScriptCodeProvider`, but has no in-screen affordance of its own to change it — the same
  "start feature-local, relocate once a second screen needs its own entry point" pattern this
  codebase has used repeatedly (§1's `quran/application` relocations).
- No tooltip variant of the word detail sheet — `docs/reference/14_WORD_BY_WORD_SPEC.md` §6 leaves
  "tooltip vs. sheet" as `NEEDS_VERIFICATION` in the reference app itself; Tahfeez always uses the
  fuller bottom sheet. "Tooltip translation"/"tooltip transliteration" preferences from the
  milestone spec are modeled as which fields the sheet shows, not as a separate lightweight popover.
- No word-audio playback — `WbwWordAudioEnabledPreferenceController` exists and gates the word
  detail sheet's play affordance, but pressing it always shows "coming soon"; real per-word audio
  (and `WbwAudioTimingEntity`-equivalent timing data) is Milestone 12's job.
- No inline, always-visible WBW translation/transliteration under Reader/Mushaf words — "show
  translation"/"show transliteration" preferences control only what the word detail sheet displays
  once opened, not a permanent second line under every word in the reading surface itself; the
  milestone's "Reader interaction" section only describes the tap-to-sheet flow, not an always-on
  overlay.
- No multiple-simultaneously-active WBW languages — `WbwSelectedPackController` holds exactly one
  active pack id, matching translations' "one active WBW language at a time" behavior the reference
  spec describes (distinct from translations' own multi-select, which is Milestone 9's concern).
- No real Quran dataset import — same gap as every milestone since 2; without a real dataset
  installed, the shipped app's script picker and word detail sheet render their honest empty/
  unavailable states.

## 20. What Milestone 9 deliberately did not do

- No real translation or tafsir content ships — `TranslationCatalog`/`TafsirCatalog`'s only
  implementations (`NoTranslationCatalog`/`NoTafsirCatalog`) honestly report nothing available, and
  every test uses clearly-labeled synthetic fixture data
  (`test/quran/translation_tafsir_test_fixtures.dart`); per `docs/CLEAN_ROOM_RULES.md`'s licensing
  rule, no real translation/tafsir edition's redistribution/offline terms have been verified or
  recorded in `docs/THIRD_PARTY_RESOURCES.md`, so none is bundled.
- No real network download — same reasoning as Milestone 8's WBW catalog: `install` writes
  immediately once given a payload rather than actually fetching bytes over time, deferred to the
  Resource Manager milestone (13).
- No drag-to-reorder UI for active translations — `TranslationSelectionController.reorder` is a
  real, tested method or the underlying preference (§11g), but the translations sheet only supports
  toggling membership today; wiring a drag gesture to it is a deliberate scope trim.
- No footnote/cross-reference authoring or validation tooling — `[n]`-marker parsing
  (`TranslationBlock`) trusts installed verse text to use this convention correctly; a malformed or
  out-of-range marker simply renders as literal text rather than a tappable span, which is
  acceptable since no real (unverified) content is ever installed to begin with.
- No `QuickReference` support inside the tafsir reader itself — cross-reference chips only appear
  in the verse-by-verse reader's translation blocks and the Mushaf translation sheet, not inside
  tafsir commentary text, since tafsir verse text has no footnote/cross-reference structure in this
  milestone's data model (only translations do).
- No multi-tafsir simultaneous display — `TafsirSelectionController` holds exactly one active
  tafsir id, matching the reference app's own single-active-tafsir behavior
  (`docs/reference/13_TRANSLATION_TAFSIR_SPEC.md` §5); this is a deliberate design choice, not an
  oversight (`NEEDS_VERIFICATION` in the reference spec itself notwithstanding).
- No search integration — translation text is not yet indexed for search (`SearchIndexDatabase`
  equivalent); that is Milestone 10's job per `docs/ARCHITECTURE.md` §4's database-separation table.
- No real Quran dataset import — same gap as every milestone since 2; without a real dataset
  installed, the shipped app's reader/Mushaf/tafsir screens render their honest empty/unavailable
  states.

## 21. What Milestone 10 deliberately did not do

- No SQLite FTS5 — a plain indexed column matched by `LIKE`, per §11h's reasoning; the milestone
  spec explicitly allows this "equivalent local indexed approach."
- No Unicode NFKC normalization pass — `SearchNormalizer` only lowercases/trims/collapses whitespace
  as its generic base step; real translations in scripts with meaningful compatibility-decomposition
  forms may need this revisited once real (non-synthetic) content is sourced.
- No character-accurate highlighting for Arabic results — only Latin-script (translation) hits are
  highlighted; see §11h for why normalized-Arabic token positions don't reliably map back onto
  canonical, un-normalized text.
- No Surah alias/transliteration dataset — Surah search matches only the installed dataset's own
  localized name/meaning, not a curated alternate-spelling list (the reference app's own alias
  dataset is exactly the kind of proprietary content `docs/CLEAN_ROOM_RULES.md` forbids copying, and
  Tahfeez has not sourced an independent one).
- No reference-content collections search (duas, topics, prophets, Quran-and-science) —
  `docs/reference/07_SEARCH_SPEC.md` §2.5's `ExclusiveVersesSearchProvider` domain has no Tahfeez
  dataset behind it yet; those datasets are their own future product-area milestones, not this one.
- No real voice search — the mic icon is a real, tappable, honest "coming soon" affordance; per this
  milestone's own "Future AI" requirement, `SearchController` already accepts any plain `String`
  query, so wiring real speech-to-text later needs no controller-level change, only a UI entry point
  that produces text.
- No incremental/paginated result loading — result lists are capped at a fixed `limit` (default 50)
  per domain rather than using an incremental-loading widget; acceptable at this milestone's scale
  (a `LIKE`-scanned local index over a dataset with no real content yet) and revisitable once real,
  large installed content makes pagination worth the added complexity.
- No automatic re-indexing triggered by dataset import or translation install/update completing —
  `SearchController` indexes lazily on first search instead, per §11h's reasoning (no real import/
  install trigger point exists in this codebase yet to hook into).
- No real Quran dataset import — same gap as every milestone since 2; without a real dataset
  installed, the shipped app's search screen renders its honest "not available yet" empty state.

## 22. What Milestone 9A (Production Quran Data Integration) deliberately did not do

- No Mushaf layout or word content of any kind — real or synthetic. The project owner's explicit
  instruction ("Do not create synthetic Mushaf layout data") is honored literally: `payload.mushafs`
  and `payload.mushafLines` are empty in the shipped dataset, asserted directly by a test, not just
  left empty by omission. The full replaceable architecture (`MushafDataSource`,
  `MushafWordIdResolver`, `resolveMushafLines`, `QulKfgqpcV2MushafDataSource`) is built and tested
  against the one real file that has been provided; it imports nothing until the remaining real word
  dataset arrives.
- No Mushaf glyph font — the QCF V2 font's redistribution terms were not independently verified
  (`SHIP_BLOCKED_LICENSE`, `docs/QURAN_DATA_PROVENANCE.md` §8), and no substitute font was silently
  wired in as if the question were resolved.
- No independent verification of the QUL layout file's own redistribution terms — its per-resource
  license page sits behind the same login gate that blocks automated fetching. Recorded as
  `SHIP_BLOCKED_LICENSE`, not assumed permitted and not inferred from QUL's MIT-licensed platform
  code, per this project's explicit "a software repository license does not automatically define the
  rights of third-party content referenced by that repository" rule.
- No additional languages beyond the two QuranEnc translations and one tafsir the governing spec
  named explicitly (`english_rwwad`, `german_rwwad`, `arabic_moyassar`) — adding more is a matter of
  calling `parseQuranEncTranslation`/`parseQuranEncTafsir` again with a different key, not a design
  change, whenever a future milestone wants to.
- No cross-source page-boundary validation between Tanzil's own page metadata (`<pages>` in
  `quran-data.xml`, imported for potential future use but not currently read by any importer) and
  QUL's Mushaf pagination — meaningless while the Mushaf layer has no imported content to compare
  against; revisit once real Mushaf data lands.
- No on-device/physical Android or iOS offline acceptance test (install → airplane mode → launch →
  verify) was run in this environment — no device was connected. What was verified instead: every
  seeding path in `BundledDatasetSeeder` reads only `rootBundle` assets and writes only to local
  Drift databases, with no HTTP client constructed anywhere in the seeding or app-boot path, and the
  full `flutter test` suite (real bundled assets, real in-memory databases) exercises the same code
  a real device boot would run. This is a real gap, not a hidden one — a physical-device pass is
  still owed before shipping.
- No compaction of the bundled JSON assets (~16 MB combined, dominated by ~9.9 MB for ~77k
  word-level canonical text rows plus per-verse translation/tafsir text) — acceptable at this
  milestone's scale and consistent with typical Quran-app asset sizes; a more compact on-disk
  encoding (e.g. arrays instead of keyed objects) is a pure size optimization revisitable later with
  zero effect on `QuranDatasetPayload`, `DatasetIntegrityValidator`, or any repository consumer.

## 23. What Milestone 9C (Mushaf Rendering and Font Packaging) deliberately did not do

- No build-time/flavor-based exclusion of the gated Mushaf/font assets from a release build — only
  a `kReleaseMode` runtime refusal in Dart code. A real test release AAB still physically contained
  the ~200MB font package and ~26MB Mushaf dataset. Recorded as an explicit, unresolved release
  blocker in `docs/QURAN_DATA_PROVENANCE.md`'s release checklist, not hidden or worked around.
- No font subsetting, merging, re-encoding, or custom atlas generation — every one of the 604 QCF
  V2 files is bundled byte-for-byte unmodified, per explicit instruction not to modify a font file
  whose modification rights have not been separately verified.
- No CDN-based runtime font delivery and no scraping of QUL/Tarteel's public font CDN — the only
  font source is the real, manually-obtained package the project owner supplied.
- No Play Asset Delivery or iOS On-Demand Resources — deliberately deferred (per instruction) as a
  future optimization if the current bundled-and-lazy-loaded approach's app-size impact proves
  unacceptable once licensing clears; see `docs/OFFLINE_MOBILE_ARCHITECTURE.md` §7.
- No physical-device testing of font load latency, memory behavior, or the Android/iOS offline
  acceptance walkthrough — no device was available in this environment. Numbers reported are from
  this sandbox's `flutter_test` engine only, explicitly caveated as such rather than presented as
  device-representative.
- No iOS build or compile check — no macOS/Xcode available in this environment.
- No `unicodeText` `MushafRenderingType` implementation — the enum value and the rendering
  branch that skips font-gating for it exist, but no real Mushaf source of that type has been
  integrated; QUL's KFGQPC V2 (`pageSpecificGlyphFont`) remains the only real Mushaf.
- No change to canonical `AyahWord`/`Ayah` schema, translation/tafsir architecture, or search — this
  milestone is scoped entirely to the Mushaf rendering/font layer built on top of already-existing,
  unmodified canonical data.

## 24. Line-Level Mushaf Rendering Rewrite, Surah Header, and Bismillah Investigation

Replaced §11e/§11k's per-word rendering (one `TextPainter`/shaping call per word, 100+
per page) with line-level shaping (one `TextPainter` per line, 8–15 per page): each
line's tokens are concatenated once, shaped once with the page's real QCF V2 font, and
per-token hit rectangles are recovered from that single shaped paragraph via
`TextPainter.getBoxesForSelection` — never computed by hand, never re-shaped per word.
One `CustomPainter` (`MushafPagePainter`) now paints an entire page, wrapped in a
`RepaintBoundary` (`isComplex: true, willChange: false`); the shaped
`MushafPageRenderModel` is cached by a `keepAlive` Riverpod provider keyed on
everything that actually changes what gets shaped, so an unrelated widget rebuild
reuses the same instance rather than re-shaping. Full current architecture:
`docs/MUSHAF_RENDERING.md` §1, §5.

Also investigated (per explicit instruction) whether the two QUL/KFGQPC special-line
fonts the project owner supplied could replace the existing non-final fallbacks for
`surahHeader`/`bismillah` lines:

- **Surah header — done and working.** QUL's official Surah Header color font
  (COLRv0/CPAL) plus its own ligature JSON give a single verified codepoint per surah
  (all 114 cross-checked against the font's real `cmap`, never sampled) whose glyph
  already contains the complete decorative frame+name artwork. A real Skia render
  confirmed it draws correctly. Wired in via `surahHeaderGlyphManifestProvider` +
  `_buildDecorativeSurahHeaderLine`, with the localized name always carried as a real
  accessibility node (`MushafPagePainter.semanticsBuilder`) separate from the visible
  glyph, and a plain-text fallback when the font isn't bundled.
  `docs/QURAN_DATA_PROVENANCE.md` §10.
- **Bismillah — investigated, not wired in.** The supplied `QCF2BSML.ttf` turned out to
  use the same per-arbitrary-codepoint, one-glyph-per-word encoding as the ordinary QCF
  page fonts (confirmed by direct rendering tests: plain canonical Arabic text renders
  as empty glyphs, while an arbitrary ASCII control string renders a real, correctly
  shaped Arabic phrase) — not a plain-Arabic-text font a shaping engine turns into
  letterforms. No companion word-by-word mapping resource for this specific font was
  provided, so the exact codepoint sequence for the Bismillah phrase in this font's own
  encoding is unknown; fabricating or visually reverse-engineering one was rejected as
  too risky for text repeated 112 times across the Mushaf. `bismillah` lines keep their
  pre-existing plain-system-font rendering. `docs/QURAN_DATA_PROVENANCE.md` §11.

`tool/quran_data/src/ttf_inspector.dart` was extended (still a from-scratch,
dependency-free parser, no external tool dependency) to read `cmap` (format 4 and
format 12 subtables) and `GSUB`/`COLR`/`CPAL` table presence — needed to verify both
fonts' actual codepoint mappings rather than assume one.

### What this did not do

- No change to Quran data, authoritative page/line mapping, or QPC V2 word mappings —
  scoped entirely to the rendering layer built on top of already-existing, unmodified
  data, per explicit instruction.
- No `ui.Picture`-level page caching (the "second stage" some specifications describe)
  — line-level shaping plus render-model memoization was the whole scope here; revisit
  only if real-device profiling (still not done — see below) shows it's still needed.
- No `flutter run --profile`/release-APK frame-timing measurement on a real Android
  device — no device was available in this environment. Scrolling smoothness is
  therefore not a verified claim; it should be measured before being treated as one.
- No page-render-model prewarming beyond the pre-existing font prewarming (±2 pages) —
  a page's render model is currently built on first watch, not proactively ahead of a
  swipe landing on it.
- No attempt to reverse-engineer or fabricate a QCF2BSML word→codepoint mapping — see
  above.

## 25. QPC Hafs Mushaf-migration Audit and the Three-Layer Quran Text Model

A compatibility audit evaluated whether Mushaf mode's page-specific QPC V2 rendering
(§11e/§11k/§24) could be replaced by the QPC Hafs Unicode script + a single
`UthmanicHafs_V22.ttf` font, to simplify the rendering pipeline. **Rejected, based on
measured results, not assumption**: full (not sampled) cross-checking of all 83,668
words confirmed the QPC Hafs word-by-word script is completely data-compatible with the
existing 15-line layout (identical `id`→`(surah,ayah,word)` mapping, zero gaps/
duplicates/missing references against every page's `first_word_id`/`last_word_id`), and
real-Skia rendering confirmed the font itself has no defect when paired with its own
script (a previous defect finding, §16 of `docs/QURAN_DATA_PROVENANCE.md`, turned out to
be a text/font *mismatch* — Tanzil text rendered through a font paired with a different
script — not a font defect). But direct side-by-side rendering of the same real pages
showed QPC Hafs does not reproduce QPC V2's page-specific hand-tuned justification or its
more elaborate traditional Madinah-Mushaf letterforms. Mushaf mode keeps QPC V2 as its
authoritative renderer. Full audit detail and the decision rationale:
`docs/MUSHAF_RENDERING.md` §2a.

> **Superseded, later milestone**: the "Mushaf mode keeps QPC V2 as its authoritative
> renderer" decision immediately above was itself later revisited and reversed — QPC V2
> was replaced in full by Quran Engine (`quran-ws/quran-engine`) as Tahfeez's only Mushaf
> rendering backend, and the QPC V2 renderer (`MushafPageLayoutEngine`/
> `MushafPagePainter`/`MushafPageRenderModel`/`QpcPageFontManager`, referenced throughout
> §11e/§11k/§24/§25 below) was deleted outright. This paragraph and the sections below it
> are kept as an accurate record of the reasoning at the time that decision was made, not
> as a description of the current renderer. See `docs/QURAN_ENGINE_MIGRATION.md` for the
> current Mushaf rendering architecture and the record of why and how this changed
> (§10 in particular: this was a deliberate, informed decision to accept an unresolved
> licensing risk, not a routine architecture swap). The three-layer Quran text model
> described just below this note is **unaffected** by that change — Quran Engine
> replaced only the middle layer's *rendering mechanism*, not the layering principle
> itself or the other two layers.

This audit settled Tahfeez's three-layer Quran text model, which was previously implicit
and is now made explicit as an architectural rule future work must not collapse without
review:

```
QuranRepository (Tanzil-sourced AyahWord/Ayah)
    → canonical Quran semantic identity: search, copy/share, references,
      integrity validation, word-by-word/audio-highlighting tap-targets
      — never displayed through a page-specific or private-use-area font

MushafRepository-shaped data (QPC V2 MushafToken + 604 page-specific fonts)
    → authentic, page-faithful printed-Mushaf presentation (Mushaf mode
      only) — §11e/§11k/§24; never used to back canonical identity

QuranDisplayRepository (planned; not yet implemented — QPC Hafs word-by-word,
§17 of docs/QURAN_DATA_PROVENANCE.md)
    → scalable Unicode display text for verse-by-verse/Ayah mode, paired
      only with its own UthmanicHafs_V22.ttf font (never fed arbitrary
      Tanzil text through that font — see §16's corrected finding)
```

All three map to the same stable `(surah, ayah, word)` identity but are deliberately
separate source layers — the same "canonical semantics vs. presentation stay separate"
principle §11e already established for QPC V2/`MushafToken`, extended to a second
presentation layer. `QuranDisplayRepository` does not yet exist as code: this section
records the target shape for when that import/wiring work happens, so it lands inside
this layering rather than bypassing it. When it is built, canonical word
identity/tap-targets/audio-highlighting must keep reading from `QuranRepository`'s
`AyahWord`, never from the QPC Hafs script's own `word` column (that script counts
ayah-end markers as words, so its count does not match `AyahWord`'s).
