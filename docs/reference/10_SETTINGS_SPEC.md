# 10 — Settings Specification (Reference Behavior)

> Source: `com.quranapp.android.compose.screens.settings.*`,
> `com.quranapp.android.compose.navigation.SettingRoutes`, `com.quranapp.android.activities.
ActivitySettings`.

## 1. Entry points and scoping

`ActivitySettings` (`singleTask`) hosts a small internal Compose navigation graph
(`SettingRoutes`). It can be entered two ways, which change what is shown:

1. **Full settings** — from the app's own Settings entry point (not observed as a bottom-nav item;
   reached via other in-app affordances, e.g. from Home banners' "Manage" buttons or a top-level
   menu — `NEEDS_VERIFICATION` on the exact primary entry affordance since it isn't the 3-item
   bottom bar).
2. **Reader-settings-only** — opened from the reader's own settings icon
   (`docs/reference/04_READER_SPEC.md` §3) via `Keys.SHOW_READER_SETTINGS_ONLY = true`, which
   hides the "App Settings" and "Other Settings" categories (§2) and shows only "Reader Settings,"
   presenting a focused subset relevant to what's currently being read.

Both entry paths also accept a `Keys.NAV_DESTINATION` extra to deep-link straight to a specific
sub-screen (used by Home's resource-update banners to jump directly to, e.g., the Translations
download screen).

## 2. Settings list structure (three categories)

### App Settings (hidden in reader-settings-only mode)
| Item | Behavior |
|---|---|
| App Language | Navigates to `SettingRoutes.LANGUAGE`; subtitle shows current language |
| Theme | Navigates to `SettingRoutes.THEME`; subtitle shows resolved theme-mode label |
| Verse of the Day | Opens a "Daily Reminder" bottom sheet (not a full screen); subtitle shows On/Off |
| Arabic Text toggle | Inline switch (no navigation) — hides/shows Arabic text globally in the reader, presumably for translation-only reading preference |

### Reader Settings (always shown)
| Item | Behavior |
|---|---|
| Text Sizes | Opens a bottom sheet with independent Arabic and Translation size sliders; subtitle shows both as percentages |
| Translations | Navigates to `SettingRoutes.TRANSLATIONS`; subtitle shows count selected |
| Tafsir | Navigates to `SettingRoutes.TAFSIR`; subtitle shows selected tafsir name |
| Scripts | Navigates to `SettingRoutes.SCRIPT`; subtitle shows script name + variant if any |
| Word by Word | Navigates to `SettingRoutes.WWB` |

### Other Settings (hidden in reader-settings-only mode)
| Item | Behavior |
|---|---|
| Download Recitations | Navigates to `SettingRoutes.RECITATION_DOWNLOAD` |
| Resource Download Source | Opens a picker bottom sheet; subtitle shows current source name |
| App Logs | Navigates to `SettingRoutes.APP_LOGS`; subtitle "Crash logs" |

Categories are visually grouped under a small label header (`ListItemCategoryLabel`), a KEEP-
worthy grouped-list UX pattern independent of its exact visual styling.

## 3. Sub-screens

- **`LanguageSelectionScreen`** — app UI language picker (distinct from Quran translation
  language). See `docs/reference/15_LOCALIZATION_SPEC.md`.
- **`SettingsThemeScreen`** — theme mode (light/dark/system) and, per `FEATURES.md`'s "5+ material
  colors with dynamic support," a Material You dynamic-color toggle plus a fixed palette of
  preset color themes.
- **`TranslationSelectionScreen`** — multi-select list of installed translations to display
  simultaneously in the reader (supports "read multiple translations together" per `FEATURES.md`).
- **`TranslationDownloadScreen`** — browse/download available translations not yet installed,
  grouped by language; shows per-item download/update state.
- **`TafsirSelectionScreen`** — pick the single active tafsir (implied singular, unlike
  translations' multi-select, since the main settings subtitle shows one tafsir name, not a
  count — `NEEDS_VERIFICATION` on whether multiple tafsirs can be simultaneously active in the
  reader the way translations can).
- **`ScriptsScreen`** — pick Quran script family + variant (Uthmani Hafs / Indopak / KFQPC v1 /
  KFQPC v2), see `docs/reference/05_MUSHAF_SPEC.md` §7.
- **`SettingsWbwScreen`** — pick active WBW language, manage installed WBW language packs (see
  `docs/reference/14_WORD_BY_WORD_SPEC.md`).
- **`RecitationDownloadScreen`** — browse reciters, see download/update state per reciter, trigger
  bulk or per-chapter downloads.
- **`AppLogsScreen`** — view/export crash logs (`ActivityAppLogs`/`components.appLogs`), a
  diagnostics feature distinct from Storage Cleanup.

## 4. Daily Reminder / Verse of the Day toggle

Presented as a bottom sheet directly from the main settings list (not a dedicated screen),
suggesting it's a lightweight single-purpose control (on/off plus, presumably, a time-of-day
picker for the reminder notification — `NEEDS_VERIFICATION` on whether a time picker is included,
though `POST_NOTIFICATIONS` and `SCHEDULE_EXACT_ALARM` manifest permissions confirm a
scheduled-notification mechanism exists). This is the "Verse Reminder" / "Verse of the Day
Reminder" feature from `README.md`/`FEATURES.md`.

## 5. Arabic text size / translation text size

Independent multiplier-based scaling (not a fixed small/medium/large enum) for Arabic and
translation text, each shown as a percentage in the settings subtitle and adjustable via sliders
in a shared "Text Sizes" bottom sheet — matching `FEATURES.md`'s "Customize Arabic text size" /
"Customise translation text size" as two independently-controlled settings.

## 6. What is *not* in this settings list

Notably absent from the reference app's Settings graph (confirmed by `SettingRoutes` having no
corresponding entries): a dedicated "Export/Import" route and a dedicated "Storage Cleanup" route
— both are separate top-level Activities (`ActivityExportImport`, `ActivityStorageCleanup`)
launched from elsewhere (not confirmed to be linked from Settings itself in the files inspected;
`NEEDS_VERIFICATION` on their exact entry point, though `ActivityAbout` is a very plausible
container for both, alongside app version/credits).

## 7. Loading / empty / error / offline states

- **Loading**: resource-download screens (Translations/Tafsir/Recitation download) show live
  progress per item via the progress buses described in
  `docs/reference/09_OFFLINE_RESOURCES_SPEC.md` §3; `NEEDS_VERIFICATION` on skeleton/shimmer use
  while the available-items manifest itself is loading.
- **Empty**: not generally applicable — every settings list is statically populated from
  preferences/enums, not from potentially-empty server data, except download-browse screens
  which could show "no results" for a search/filter with no matches (`NEEDS_VERIFICATION`).
- **Error**: manifest-fetch failure on a download-browse screen would need a retry affordance;
  exact treatment `NEEDS_VERIFICATION`.
- **Offline**: settings values themselves are always readable/editable offline (local
  preferences). Only the download-browse screens' *available-to-download* lists require network
  to refresh; previously-cached manifests may still allow browsing (but not downloading) offline —
  `NEEDS_VERIFICATION`.

## 8. Tahfeez interpretation

Per `docs/DESIGN_DIRECTION.md`, Tahfeez should preserve the *capability* set here (language,
theme mode + dynamic color + preset palettes, daily reminder, Arabic-text toggle, independent
text-size scaling, translation/tafsir/script/WBW selection, recitation downloads, a download-
source preference, and diagnostics/logs) using Tahfeez's own grouped-settings visual language and
its own Riverpod-backed preferences layer, not this screen's exact three-category split or sheet-
vs-screen choices where a better Tahfeez-native composition is available.
