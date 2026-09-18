# 17 — Test Parity Matrix

## 1. Reference app's actual test coverage (important finding)

The reference repository ships **no meaningful automated test suite**. Its entire test surface
is two unmodified Android Studio project templates:

- `app/src/test/java/com/quranapp/android/ExampleUnitTest.java` — the default JUnit template
  (`assertEquals(4, 2 + 2)`).
- `app/src/androidTest/java/com/quranapp/android/ExampleInstrumentedTest.java` and
  `MainActivityTest.java` — default instrumented-test templates.
- Its CI workflow (`.github/workflows/ci.yml`) runs exactly one job: `./gradlew assembleDebug`
  (build a debug APK and upload it as an artifact). **No `test`, `connectedCheck`, or lint task
  runs in CI.**

**Consequence for this milestone**: there is no reference test suite to derive a "test parity"
matrix from in the normal sense (matching Tahfeez tests 1:1 to existing reference tests). Instead,
this document defines the test coverage Tahfeez itself needs to reach confidence that each
reference *behavior* documented in `docs/reference/01`–`16` has been correctly and independently
reimplemented, per this milestone's Definition of Done ("Reader/Mushaf/audio/search/offline
behavior is documented beyond README-level detail" implies it must also be *testable* beyond
README-level detail).

## 2. Required test coverage by area (Tahfeez-defined target, not reference-derived)

| Area | Unit tests | Integration/widget tests | Notes |
|---|---|---|---|
| Quran data integrity | Chapter/verse count validation, navigation-range (Juz/Hizb/Rub/Manzil) boundary correctness, checksum/hash verification of the canonical dataset | Golden-file comparison against a known-good verified dataset snapshot | Directly required by `CLAUDE.md`'s "Add integrity checks around Quran datasets" |
| Mushaf pagination | Line-fitting algorithm (given width/font, produces expected fitted size), page/line boundary correctness for at least one full script dataset | Full-page render snapshot tests (golden images) per script | See `docs/reference/05_MUSHAF_SPEC.md` |
| Reader mode switching | Position-carry-over logic (verse ⇄ page ⇄ translation mode) | Widget test: switching modes preserves reading position | See `docs/reference/04_READER_SPEC.md` §2 |
| Search normalization | Arabic diacritic/tatweel/alef-variant stripping, Latin lowercasing, per-language script classification | FTS query round-trip: normalized query matches normalized index content | See `docs/reference/07_SEARCH_SPEC.md` §3–4; this is Quran-correctness-adjacent and should never touch canonical text |
| Search query building | Token filtering (min length, operator escaping), prefix-term construction | End-to-end: known query → expected result set on a fixed fixture dataset | |
| Bookmarks | CRUD correctness, single vs. range shape, note persistence | Widget test: bookmark add/remove from reader + Bookmarks screen list update | |
| Read history | Position-restore round-trip (write a history entry, reopen, verify exact position) | Widget test: Home "Continue Reading" opens correct position | |
| Audio playback | Verse-clip boundary computation from timing metadata, repeat-count/verse-group-size logic, audio-end-behavior transitions | Platform-specific: background playback survives app backgrounding (manual/device test where automated coverage is impractical) | See `docs/reference/08_AUDIO_SPEC.md` |
| Offline resource versioning | Version-reconcile logic (local vs. remote manifest → outdated set), stale-cache invalidation | Integration: simulate a manifest bump, verify outdated flag + cache invalidation | See `docs/reference/09_OFFLINE_RESOURCES_SPEC.md` §2 |
| Settings persistence | Every preference round-trips (write → read back) | Widget test: changing a reader preference immediately reflects in an open reader screen | |
| Export/Import | Round-trip fidelity (export then import reproduces original bookmarks/settings exactly); explicit exclusion of read history | Widget test: scoped export/import cards | |
| Localization | Fallback-chain resolution (exact tag → language-only → English), numeral-system coercion | Widget test: RTL layout mirroring for at least one RTL locale | See `docs/reference/15_LOCALIZATION_SPEC.md` |
| Deep links | Every documented URL pattern resolves to the correct route/screen with correct parameters | Widget/integration test per pattern | See `docs/reference/16_PLATFORM_FEATURES_SPEC.md` §1 |
| Offline-first guarantee | N/A (architectural) | Integration: airplane-mode smoke test covering every capability `docs/PROJECT_BRIEF.md` §"Offline philosophy" lists as required-offline | This is the single highest-value integration test suite for this project's stated values |

## 3. Quran-correctness test gate (non-negotiable per `CLAUDE.md`)

Per `CLAUDE.md`'s "Do not claim a milestone is complete until its Definition of Done is satisfied
and analysis/tests/build checks pass" and "Never silently edit Quran text," any milestone that
touches Quran text storage, search indexing, or Mushaf rendering must include an automated check
that:
1. Canonical Quran text in the datastore matches a verified source checksum after every write
   path that could touch it (import, migration, resource update).
2. The normalized/search-index representation is provably derived-only (a test that mutates the
   index and asserts canonical text is unaffected, and vice versa).

## 4. What "parity" means here

"Test parity" for this project should be read as: *Tahfeez's own test suite achieves the coverage
this matrix defines*, not *Tahfeez copies or matches reference test files* — because no reference
test files worth matching exist. Each milestone's own Definition of Done should reference the
relevant row(s) of this table.

## 5. NEEDS_VERIFICATION

- Whether the reference project maintains any private/internal test suite not present in the
  public repository (plausible for a production app with real users, but unconfirmed and outside
  this milestone's scope to investigate further).
