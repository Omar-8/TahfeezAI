# 14 — Word-by-Word (WBW) Specification (Reference Behavior)

> Source: `com.quranapp.android.utils.reader.wbw.*`, `com.quranapp.android.db.entities.wbw.*`,
> `com.quranapp.android.compose.components.reader.{QuranTextWbw,WbwTooltip}`,
> `com.quranapp.android.compose.components.reader.dialogs.WbwSheet`,
> `com.quranapp.android.compose.screens.settings.SettingsWbwScreen`.

## 1. Data shape (cross-reference)

`WbwWordEntity` (composite PK `wbwId`+`ayahId`+`wordIndex`) stores per-word `translation` and
`transliteration` strings for one WBW "language pack" (`wbwId`). `WbwAudioTimingEntity` stores
per-word `startMillis`/`endMillis` for a given `audioId`, keyed the same way. Both live in
`ExternalQuranDatabase`, the downloadable-resource database, not the immutable canonical
`QuranDatabase` — WBW content is treated as an optional overlay on top of canonical word indices
(`AyahWordEntity.wordIndex`), never as a modification of canonical text. See
`docs/reference/06_DATA_MODEL_SPEC.md` §4.

## 2. Manager and manifest

- `WbwManager` fetches an available-WBW manifest (`available_wbw_info_v2.json`, via the project's
  own API, cached to a local file mirrored in the reference repo's own `inventory/wbw/` snapshot)
  listing installable WBW language packs and, presumably, a separate roster of WBW-audio sets
  (`api.models.wbw.AvailableWbwInfoModel`).
- `WbwDownloadWorker` downloads a WBW language pack's text (translation + transliteration) into
  `ExternalQuranDatabase`.
- `WbwVersionManager`/`Store` — same reconcile-against-remote pattern as other resource
  categories (`docs/reference/09_OFFLINE_RESOURCES_SPEC.md` §2); outdated WBW packs surface via
  Home's resource-update banner.
- `WbwAudioDownloadWorker`/`WbwAudioBulkDownloadWorker` — separate downloadable resource for
  per-word audio (distinct from full-verse recitation audio), with its own progress bus
  (`WbwAudioDownloadProgressBus`).

## 3. Settings

`SettingsWbwScreen` — lets the user:
- Pick the active WBW language (one active at a time in the reader, distinct from translations'
  multi-select — `NEEDS_VERIFICATION` on whether more than one WBW language can be shown
  simultaneously per word).
- Browse/download/update/delete installed WBW language packs — matching Milestone-0's required
  verification list ("downloadable languages," "active language," "update/delete states").

## 4. In-reader interaction

- Tapping any Arabic word (when WBW is enabled) shows that word's translation + transliteration,
  via `WbwTooltip` (a lightweight inline popover) and/or `WbwSheet` (a fuller bottom-sheet
  presentation) — `NEEDS_VERIFICATION` on exactly which one is the default vs. an alternate/
  expanded view (e.g., tooltip for a quick glance, sheet for a longer look or multiple words).
- `QuranTextWbw` renders the Arabic line with each word wrapped as an individually tappable
  target, feeding taps through to whichever WBW presentation is active — this is the same
  tap-target/word-index model used for Mushaf-mode word taps (`docs/reference/05_MUSHAF_SPEC.md`
  §8), so WBW works consistently in both verse-by-verse and Mushaf reading modes.
- If per-word audio is downloaded for the active WBW audio set, tapping (or a dedicated play
  affordance on) a word plays that single word's pronunciation, timed via
  `WbwAudioTimingEntity` — `NEEDS_VERIFICATION` on the exact trigger gesture (tap-to-hear vs. a
  separate icon).

## 5. Loading / empty / error / offline states

- **Loading**: WBW tooltip/sheet content loads from local SQLite once the pack is downloaded, so
  no loading state is expected in normal use; the download/browse screen shows per-item progress.
- **Empty**: with no WBW language installed/enabled, word taps are simply inert (WBW is an opt-in
  overlay, not a required reading mode).
- **Error**: a word with missing WBW data for the active language (e.g., partially-downloaded
  pack) — exact fallback `NEEDS_VERIFICATION`.
- **Offline**: fully offline once a language pack (and, for audio, its word-audio set) is
  downloaded; only the manifest fetch and download require network.

## 6. NEEDS_VERIFICATION

- Whether multiple WBW languages can be shown per word simultaneously (stacked translation +
  transliteration is already two lines per word — whether a *second* language stacks further is
  unconfirmed).
- Exact tooltip vs. sheet trigger logic.
- Word-audio playback trigger gesture.
