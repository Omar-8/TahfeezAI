# 15 — Localization Specification (Reference Behavior)

> Source: `app/src/main/res/values*` resource qualifiers, `com.quranapp.android.compose.utils.
{AppLocale,Localize}`, `com.quranapp.android.compose.screens.settings.LanguageSelectionScreen`.

## 1. Supported UI languages

The reference app ships **22 translated app-UI-language resource directories** beyond the base
`values/` (English default): `ar`, `bn`, `ckb` (Central Kurdish/Sorani), `de`, `es`, `fa`
(Persian), `fil` (Filipino), `fr`, `gu` (Gujarati), `hi`, `in` (Indonesian — Android's legacy code
for `id`), `it`, `ky` (Kyrgyz), `ml` (Malayalam), `pt`, `ru`, `sd` (Sindhi), `ta` (Tamil), `tr`,
`ur`, `zh-rCN` (Simplified Chinese), `zh-rTW` (Traditional Chinese). This matches `FEATURES.md`'s
"App is available in 22 languages" exactly. Non-language resource qualifier directories present
alongside these (`values-land`, `values-night`, `values-ldrtl`) are orientation/theme/layout-
direction qualifiers, not additional languages.

Each language directory carries essentially the full string catalog (~418–432 of the base 440
string resources per directory in the snapshot inspected), i.e. translation coverage is
near-complete across all 22 languages rather than a partial subset receiving only a few strings.

## 2. UI language is independent of Quran-content language

Per Milestone-0's structure, **app UI language** (Settings → App Language,
`LanguageSelectionScreen`) is a fully separate concern from:
- **Quran translation language** (which translations are installed/selected —
  `docs/reference/13_TRANSLATION_TAFSIR_SPEC.md`),
- **Tafsir language**,
- **Word-by-word language** (`docs/reference/14_WORD_BY_WORD_SPEC.md`),
- **Search language behavior** (`SearchNormalizer.scriptForLang`,
  `docs/reference/07_SEARCH_SPEC.md` §3).

A user can, for example, run the app UI in French while reading an English translation with Urdu
word-by-word — none of these settings force the others to match. Tahfeez should preserve this
same independence between "interface language" and "content language(s)."

## 3. Locale resolution

`AppLocale` (a `data class`) resolves the effective locale as:
1. If the stored preference is the sentinel "system default" value, use the OS's current system
   locale (`LocaleManagerCompat.getSystemLocales`, falling back to `Resources.getSystem()
.configuration`).
2. Otherwise, prefer `AppCompatDelegate.getApplicationLocales()` (the modern per-app-language
   Android API) if set, else parse the stored language tag directly.
3. A `fallbackLanguageCodes()` sequence (`[full-tag, language-only, "en"]`) is exposed for
   resource lookups that need a graceful multi-step fallback (e.g., resolving a chapter-name
   localization row when the exact stored tag has no row but the base language does).

Tahfeez, being a single Flutter codebase, should implement the equivalent fallback chain (exact
locale → language-only → English) in its own localization delegate rather than relying on the
platform's default single-level fallback, since Quran/reference content localization tables will
not necessarily cover every locale variant.

## 4. Numeral systems (a non-obvious, worth-preserving detail)

For Arabic and Persian specifically, the user can independently choose which digit glyphs are
used for numbers throughout the app (page numbers, verse numbers, counts), via a Unicode locale
extension keyword (`nu`) applied to the platform `Locale`:
- **Arabic (`ar`)**: Western digits (`0–9`, `NumeralSystem.LATN`) or Arabic-Indic digits (`٠–٩`,
  `NumeralSystem.ARAB`).
- **Persian (`fa`)**: Western digits or Extended Arabic-Indic/Persian digits (`۰–۹`,
  `NumeralSystem.ARABEXT`).
- All other languages have no numeral-system choice exposed (`numeralSystemsForLanguage` returns
  empty), always rendering Western digits.
- The choice is validated against the current language (`coerceNumeralForLanguage`) so a stale
  numeral preference from a previously-selected language does not silently leak into an unrelated
  language.

This is a real, user-facing localization-quality detail that a "translate the strings and call it
done" approach would miss. Tahfeez should plan for the same capability at least for Arabic
(Arabic-Indic digit display is a commonly-expected feature for Arabic-speaking users of Quran
apps) even if broader numeral-system coverage is deferred.

## 5. RTL support

`android:supportsRtl="true"` in the manifest plus a `values-ldrtl` qualifier directory confirms
full RTL layout mirroring is implemented (not just Arabic text rendering within an LTR shell).
Tahfeez (Flutter) gets bidi layout mirroring largely "for free" via `Directionality`/`TextDirection`
when the active locale is RTL, but should verify every custom-drawn or manually-positioned UI
element (not just text) mirrors correctly, matching the reference app's explicit RTL resource
investment.

## 6. Dark mode as a resource qualifier

`values-night` exists as a resource-qualifier directory (holding `colors.xml`), i.e., some color
values are chosen via Android's night-mode resource qualifier system rather than purely at the
Compose theme level — an implementation detail specific to the Android/View-resource system that
has no direct Flutter equivalent (Flutter themes are resolved in Dart, not via resource
qualifiers); Tahfeez's theming approach (Milestone 3) already plans for Riverpod-driven theme
state, so no action is implied here beyond noting the reference app treats dark-mode-specific
values as first-class resources, consistent with `docs/DESIGN_DIRECTION.md`'s "dark mode should be
designed independently, not generated by simply inverting light colors."

## 7. Localized Quran-adjacent content

Chapter names (`SurahLocalizationEntity`), chapter search aliases (`SurahSearchAliasEntity`), and
topic content (`TopicLocalizationEntity`) are localized independently of the app-UI string catalog
— stored as data rows (per `docs/reference/06_DATA_MODEL_SPEC.md`), not as `strings.xml` entries,
because their coverage/language set can differ from (and typically is smaller than) the 22
UI languages.

## 8. NEEDS_VERIFICATION

- Exact language-coverage gaps between the 440-entry base catalog and each 418–432-entry
  translated catalog (i.e., which specific strings remain untranslated in which languages).
- Whether `LanguageSelectionScreen` requires an app restart or applies immediately
  (`AppCompatDelegate.setApplicationLocales` typically applies without a full process restart on
  modern Android, but the reference app's exact UX around the transition — e.g., a brief recreate
  — is not confirmed here).
- Full list of localized chapter-name/topic languages vs. the 22 UI languages (likely a subset).
