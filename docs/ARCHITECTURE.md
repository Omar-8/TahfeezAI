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
| Core app database (`lib/core/database/app_database.dart`) | App-level bookkeeping only (a generic key/value table) — no Quran or user content | Milestone 1 (this milestone) |
| Quran database | Canonical chapters/verses/scripts/Mushaf maps/navigation units — **immutable** | Milestone 2 (Quran Data Engine) |
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

## 12. What Milestone 1 deliberately did not do

- No feature screens (Home, Reader, Search, Settings, ...) — only the one foundation-proof
  screen, per the milestone's explicit scope.
- No concrete implementations of `QuranRepository`, `TranslationRepository`,
  `TafsirRepository`, `SearchRepository`, `UserDataRepository`, `ResourceRepository`, or
  `MemorizationRepository` — interfaces only, by design (§3).
- No `audio_service` background session wiring (§8) — only a minimal foreground `just_audio`
  implementation to prove the seam.
- No actual Quran data, translations, tafsir, or downloadable resources of any kind.
- No AI recognition implementation of any kind (§10) — interfaces only, as the milestone
  explicitly requires.
