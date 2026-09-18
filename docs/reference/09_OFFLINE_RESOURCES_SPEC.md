# 09 — Offline Resources Specification (Reference Behavior)

> Source: `com.quranapp.android.utils.workers.*`, `com.quranapp.android.utils.reader.{translation,
wbw}.*Version*`, `com.quranapp.android.utils.mediaplayer.Recitation*Version*`,
> `com.quranapp.android.utils.reader.atlas.Atlas*`, `com.quranapp.android.compose.screens.
storageCleanup.*`, reference repo `inventory/` snapshot.

## 1. Resource categories

The app treats each of the following as an independently downloadable, independently versioned
resource category, each with its own WorkManager worker(s):

| Category | Download worker(s) | Bulk worker |
|---|---|---|
| Recitation audio (per reciter/chapter) | `RecitationAudioDownloadWorker` | `RecitationBulkDownloadWorker` |
| Word-by-word (text) | `WbwDownloadWorker` | — |
| Word-by-word audio | `WbwAudioDownloadWorker` | `WbwAudioBulkDownloadWorker` |
| Translations | `TranslationDownloadWorker` | — |
| Translation search index (derived, not user-visible as a "download") | `TranslationSearchIndexWorker` | — |
| Tafsir | `TafsirDownloadWorker` | — |
| Atlas glyph bundles | `AtlasDownloadWorker` | — |
| Script/typeface fonts | `ScriptFontsDownloadWorker` | — |

Two additional background workers exist for non-download purposes but live in the same package:
`VerseOfTheDayWorker` (periodic VOTD refresh/selection) and `RecommendedReminderWorker`
(scheduling the recommendation/reminder notification pipeline).

## 2. Versioning and staleness model

Each downloadable category has a dedicated `*VersionManager` + `*VersionStore` pair
(`RecitationVersionManager`/`Store`, `TranslationVersionManager`/`Store`,
`WbwVersionManager`/`Store`) following the same shape:

1. A remote manifest (fetched separately, cached under `inventory/` in the reference repo's own
   snapshot as `available_*_info*.json` — see `docs/reference/16_PLATFORM_FEATURES_SPEC.md` for
   how manifests are fetched) lists the current version number(s) for every available resource
   item.
2. A local `*VersionStore` records the version number that was actually downloaded/installed for
   each item the user has.
3. `reconcileAfterManifestRefresh()` (seen concretely on `RecitationVersionManager`, §4 of the
   Audio spec) diffs local vs. remote per item, marking items **outdated** and deleting/
   invalidating any now-stale cached derived data (e.g., clearing timing files and stream cache
   when a reciter's `timingVersion` increments).
4. Outdated items are surfaced via a `StateFlow<UpdateUiState>` that both the Home banners
   (`docs/reference/11_HOME_SPEC.md` §2) and the relevant Settings download screen observe, so the
   "N updates available" count is always live and consistent across screens.

Some resources version multiple independent facets separately (e.g., a reciter has both an
`audioVersion` and a `timingVersion` — updating the timing metadata does not necessarily require
re-downloading the (large) audio file, only re-validating/re-caching timing-dependent state).
Tahfeez's own resource-manager design (Milestone 13) should support this same "a resource can have
more than one independently-versioned facet" model rather than a single flat version number per
resource, since it directly affects how much re-download work an update actually requires.

## 3. Download progress reporting

Dedicated progress event buses exist per download-heavy category (`RecitationDownloadProgressBus`,
`WbwAudioDownloadProgressBus`) that UI can subscribe to for live per-item progress
(percentage/bytes), decoupling the WorkManager worker (which may run detached from any visible UI)
from whatever screen is currently displaying progress (Settings download screens, Storage Cleanup
screens, or Home banners simultaneously).

## 4. Storage cleanup

A dedicated `ActivityStorageCleanup` with per-category screens
(`StorageCleanupMainScreen`, `StorageCleanupRecitationScreen`, `StorageCleanupScriptsScreen`,
`StorageCleanupTafsirScreen`, `StorageCleanupTranslationScreen`) lets the user inspect and free
storage used by each downloaded resource category individually — a direct implementation of
`FEATURES.md`/Milestone-0's "resource update states" and "cleanup/logging/diagnostics" settings
requirement. This is distinct from Settings' resource *download* screens (which add resources);
Storage Cleanup is specifically about reclaiming space from resources already downloaded.

## 5. Resource provenance and licensing — required verification

The cloned reference repository ships (or references, via `inventory/`) a substantial set of
first-party and third-party content that Tahfeez must **not** copy without independent
verification, per `docs/CLEAN_ROOM_RULES.md`:

- **Quran script/font data**: `inventory/fonts/` contains hundreds of per-Mushaf-page `.TTF` font
  files (a KFQPC-style font family) plus packaged font ZIP bundles; `inventory/quran_scripts/`
  contains a full Quran-text-as-glyph-codepoint JSON dataset (`script_kfqpc_v1.json`) mapping each
  ayah to private-use-area glyph sequences tied to that specific font. **This is exactly the kind
  of proprietary, tightly-licensed Quran font/text pairing `docs/CLEAN_ROOM_RULES.md` prohibits
  copying.** Tahfeez must independently source or license any Quran script/font (e.g., a
  separately-licensed Uthmani or Indopak font family with documented redistribution rights) before
  any Mushaf-mode milestone ships, and must record it in `docs/THIRD_PARTY_RESOURCES.md` per
  `docs/CLEAN_ROOM_RULES.md` §"Resource register."
- **Translations**: `inventory/translations/` manifest (`available_translations_info.json`)
  enumerates **48 translation editions across 24 languages** as of the snapshot inspected (close
  to, and consistent with, `FEATURES.md`'s "45+ translations in 20+ languages" marketing figure —
  exact live count will drift over time, `NEEDS_VERIFICATION`), each translation entry recording
  book title, author/translator, language, and a `downloadPath`. Each translation is a distinct
  copyrighted or openly-licensed work (e.g., Hilali & Khan, Pickthall, Yusuf Ali for English) with
  its own license terms — Tahfeez must verify each translation's redistribution/offline-bundling
  permission individually before shipping it, not assume the app's own GPL-3.0 license covers
  them (`docs/CLEAN_ROOM_RULES.md` explicitly calls this out).
- **Tafsirs**: `inventory/tafsirs/available_tafsirs_info.json` — same per-item licensing caveat
  applies.
- **Word-by-word data**: `inventory/wbw/available_wbw_info.json` /
  `available_wbw_info_v2.json` — per-language WBW translation/transliteration text has its own
  provenance (commonly derived from corpus.quran.com-style datasets in comparable apps) that must
  be independently verified.
- **Recitation audio**: `inventory/recitations/available_recitations_info*.json` — audio
  recordings are typically licensed from the reciter or a hosting service (the reference
  repository's own `README.md` credits `quranicaudio.com` and `everyayah.com`); redistribution
  and offline-caching rights must be verified per reciter/source, not assumed blanket.
- **Reference-content prose** (duas, prophets, etiquette, major sins, Quran & Science, topics):
  authored prose content with its own authorship/copyright status, independent of the Quran text
  itself. Per `docs/CLEAN_ROOM_RULES.md`, "do not assume Tahfeez may redistribute the same
  authored reference files."

None of the above resource files should be copied into the Tahfeez repository. This document
records their *existence and shape* as observed in the reference app for planning purposes only.

## 6. Download source selection

Settings exposes a "Resource Download Source" picker (`DownloadSourceUtils`,
`ResourceDownloadSrcSheet`, `docs/reference/10_SETTINGS_SPEC.md` §"Other Settings") — implying
resources can be fetched from more than one CDN/mirror, presumably to route around
regionally-blocked or slow hosts. Exact list of available sources is `NEEDS_VERIFICATION`.

## 7. Offline behavior summary (cross-reference)

Everything in `docs/PROJECT_BRIEF.md`'s offline-first list — read Quran, navigate, Mushaf mode,
verse-by-verse mode, search, bookmarks, reading history, settings, and any *already-installed*
translation/tafsir/WBW/audio — matches the reference app's actual behavior: the canonical Quran
dataset and default script ship with (or are provisioned once at) install, and every other
resource category above is opt-in-download, versioned, and cleanly falls back to "unavailable
until downloaded" rather than degrading core reading. Tahfeez's Resource Manager milestone should
preserve this same offline-core / opt-in-enhancement shape.

## 8. Consolidated unresolved rights questions

Per Milestone 0's requirement to list all unresolved rights questions in one place, the full set
observed while studying the reference repository is:

| Category | Unresolved question | Where discussed |
|---|---|---|
| Quran text dataset(s) | Which upstream dataset(s) can Tahfeez legally use, and under what license, for canonical Arabic text + per-verse metadata (Juz/Hizb/Rub/Manzil/Sajdah)? | §5 above |
| Quran script/font | Which specific script/font family (Uthmani, Indopak, or another) has clear, checked redistribution rights for Tahfeez's exact use (bundled in-app, offline, cross-platform)? The reference app's own KFQPC-derived font/glyph dataset must not be used. | §5 above, `05_MUSHAF_SPEC.md` §7 |
| Atlas/glyph-rasterization assets | If Tahfeez ever adopts an atlas-style renderer (optional Milestone 7B), what are the rights to any prebuilt texture/placement data it might consider using or referencing, versus building its own from a licensed font? | `05_MUSHAF_SPEC.md` §5 |
| Translations | For each specific translation edition Tahfeez wants to ship, what are that edition's redistribution and offline-bundling terms? | §5 above |
| Tafsir | Same per-tafsir question as translations. | §5 above |
| Word-by-word data | What is the provenance and license of any WBW translation/transliteration corpus Tahfeez sources? | §5 above |
| Audio | For each reciter/recording Tahfeez wants to offer, what are the hosting/redistribution/offline-caching terms, and from which source (direct reciter agreement, a hosting service like the reference app's credited `quranicaudio.com`/`everyayah.com`, or another)? | §5 above |
| Icons / artwork | Tahfeez must use its own or separately-licensed icon set and artwork (per `docs/CLEAN_ROOM_RULES.md`); no icon/artwork decision has been made yet at this milestone, so there is nothing to verify yet beyond the standing rule "do not copy the reference app's icon or artwork assets." This should be revisited once Tahfeez's Design System milestone selects an icon set. | `CLEAN_ROOM_RULES.md`, `18_VISUAL_REFERENCE_NOTES.md` |
| Reference-content prose (duas, prophets, etiquette, major sins, science, topics) | What is the authorship/copyright status of any specific reference-content text Tahfeez considers using, independent of the Quran text itself? | §5 above |
| AI model(s) | Not applicable to the reference app (it has no AI features to compare against — see `01_FEATURE_MATRIX.md`'s Memorize/AI section). Once Tahfeez selects any AI model/service for future recitation-assistance milestones, its license/terms must be recorded in `docs/THIRD_PARTY_RESOURCES.md` per `CLAUDE.md`'s "Resource provenance" rule. | N/A this milestone |

None of these questions are resolved by this milestone. Per Milestone 0's instructions,
`docs/THIRD_PARTY_RESOURCES.md` is **not** created or populated here — it should only be created
once a specific resource's terms have actually been verified, which is out of scope for this
analysis-only milestone.

## 9. NEEDS_VERIFICATION

- Whether the base canonical Quran text (default script) itself ships bundled in the APK or is
  downloaded on first launch (relevant to Tahfeez's own "what ships in the binary vs. first-run
  download" decision).
- Exact list of alternate download sources.
- Whether download workers respect a "Wi-Fi only" / metered-network preference (common in
  comparable apps but not directly confirmed here).
