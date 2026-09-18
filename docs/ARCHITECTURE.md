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
  quran/domain/                 QuranRepository, TranslationRepository, TafsirRepository, SearchRepository.
  user_data/domain/             UserDataRepository (bookmarks, reading history).
  memorization/domain/          MemorizationRepository.
  ai/domain/                    RecitationRecognizer, RecitationContext, RecitationEvent (interfaces only).
  features/                     Reserved for feature-area presentation code; empty until Milestone 4+.
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
