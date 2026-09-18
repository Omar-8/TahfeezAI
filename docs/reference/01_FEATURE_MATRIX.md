# 01 — Feature Matrix (Reference Behavior)

> Every advertised/observed feature of `AlfaazPlus/QuranApp`, mapped to the reference doc that
> details it. Organized by `docs/PROJECT_BRIEF.md`'s product areas (Read / Listen / Organize /
> Explore / Memorize / AI) so Tahfeez's own roadmap can be compared directly against it. "Ref
> confirmed" = directly observed in source; "Ref claimed" = stated in `FEATURES.md`/`README.md`
> but not independently line-by-line verified in code during this milestone.

## Read

| Feature | Status | Detail |
|---|---|---|
| Verse-by-verse reading mode | Ref confirmed | `04_READER_SPEC.md` §2 |
| Mushaf mode (variable lines) | Ref confirmed | `05_MUSHAF_SPEC.md` |
| Translation-first reading mode | Ref confirmed | `04_READER_SPEC.md` §2 |
| Chapter / Juz / Hizb reading | Ref confirmed | `04_READER_SPEC.md` §1, `06_DATA_MODEL_SPEC.md` §2 |
| Page-based reading & navigation | Ref confirmed | `05_MUSHAF_SPEC.md`, `04_READER_SPEC.md` §4 |
| Jump to verse/chapter/juz/hizb/page | Ref confirmed | `04_READER_SPEC.md` §4, `07_SEARCH_SPEC.md` §2 |
| Multiple Quran scripts (Uthmani Hafs, Indopak, KFQPC v1/v2) | Ref claimed + partly confirmed | `05_MUSHAF_SPEC.md` §7 |
| Arabic text size control | Ref confirmed | `10_SETTINGS_SPEC.md` §5 |
| Translation text size control | Ref confirmed | `10_SETTINGS_SPEC.md` §5 |
| Arabic text on/off toggle | Ref confirmed | `10_SETTINGS_SPEC.md` §2 |
| 45+ translations, 20+ languages | Ref confirmed (48 editions / 24 languages in inspected manifest) | `09_OFFLINE_RESOURCES_SPEC.md` §5, `13_TRANSLATION_TAFSIR_SPEC.md` |
| Read multiple translations together | Ref confirmed | `13_TRANSLATION_TAFSIR_SPEC.md` §2 |
| Footnote preview | Ref confirmed | `04_READER_SPEC.md` §7 |
| Verse-reference preview (quick reference) | Ref confirmed (component exists) | `04_READER_SPEC.md` §7 |
| 10+ tafsirs, 5+ languages | Ref confirmed (manifest present, count NV) | `13_TRANSLATION_TAFSIR_SPEC.md` §5 |
| Word-by-word translation + transliteration | Ref confirmed | `14_WORD_BY_WORD_SPEC.md` |
| Word-by-word audio | Ref confirmed | `14_WORD_BY_WORD_SPEC.md` §2, §4 |
| Chapter info screen | Ref confirmed | `02_SCREEN_INVENTORY.md` §4 |
| Similar verses cross-reference | Ref confirmed | `04_READER_SPEC.md` §7 |
| Sajdah verse marking | Ref confirmed (schema field) | `06_DATA_MODEL_SPEC.md` §2 (`AyahEntity.sajdahType`) |

## Listen

| Feature | Status | Detail |
|---|---|---|
| 18+ Quran reciters | Ref confirmed (19 in inspected manifest) | `08_AUDIO_SPEC.md` §4 |
| 10+ translation-audio reciters | Ref confirmed (11 in inspected manifest) | `08_AUDIO_SPEC.md` §4 |
| Play Quran only / translation only / both | Ref confirmed | `08_AUDIO_SPEC.md` §2 |
| Custom repeat (verse-group + count) | Ref confirmed | `08_AUDIO_SPEC.md` §2 |
| Playback speed control | Ref confirmed | `08_AUDIO_SPEC.md` §2 |
| Audio-end behavior (stop/next-chapter/repeat-chapter) | Ref confirmed | `08_AUDIO_SPEC.md` §3 |
| Verse synchronization / auto-scroll | Ref confirmed | `08_AUDIO_SPEC.md` §5, `04_READER_SPEC.md` §11 |
| Spotlight mode | Ref confirmed | `08_AUDIO_SPEC.md` §6, `04_READER_SPEC.md` §12 |
| Background playback | Ref confirmed | `08_AUDIO_SPEC.md` §1, §9 |
| Explicit audio downloads (per chapter / bulk) | Ref confirmed | `08_AUDIO_SPEC.md` §7 |
| Streaming cache (undownloaded reciters) | Ref confirmed | `08_AUDIO_SPEC.md` §7 |
| Home-screen player widget | Ref confirmed | `16_PLATFORM_FEATURES_SPEC.md` §2 |
| Android Auto integration | Ref confirmed (manifest capability) | `16_PLATFORM_FEATURES_SPEC.md` §3 |

## Organize

| Feature | Status | Detail |
|---|---|---|
| Single-verse bookmark | Ref confirmed | `12_BOOKMARK_HISTORY_SPEC.md` §1–2 |
| Range bookmark | Ref confirmed (schema-level; in-reader multi-select UX NV) | `12_BOOKMARK_HISTORY_SPEC.md` §1 |
| Bookmark notes | Ref confirmed | `12_BOOKMARK_HISTORY_SPEC.md` §1 |
| Bookmark bulk/selection delete | Ref confirmed | `12_BOOKMARK_HISTORY_SPEC.md` §2 |
| Reading history (auto-tracked) | Ref confirmed | `12_BOOKMARK_HISTORY_SPEC.md` §3 |
| Resume exact reading position | Ref confirmed | `12_BOOKMARK_HISTORY_SPEC.md` §3, `04_READER_SPEC.md` §18 |
| Export/Import (settings + bookmarks; history excluded) | Ref confirmed | `12_BOOKMARK_HISTORY_SPEC.md` §4 |
| Verse sharing | Ref confirmed (mechanism); exact share-card content NV | `04_READER_SPEC.md` §9, `16_PLATFORM_FEATURES_SPEC.md` §4 |

## Explore

| Feature | Status | Detail |
|---|---|---|
| Verse of the Day (in-app + widget) | Ref confirmed | `11_HOME_SPEC.md` §3, `16_PLATFORM_FEATURES_SPEC.md` §2 |
| Daily reminder notification | Ref confirmed (permissions + settings entry) | `10_SETTINGS_SPEC.md` §4, `16_PLATFORM_FEATURES_SPEC.md` §5 |
| Recommended content banner | Ref confirmed | `11_HOME_SPEC.md` §3 |
| Featured reading shortcuts | Ref confirmed | `11_HOME_SPEC.md` §5 |
| Duas from the Quran | Ref confirmed (category exists) | `11_HOME_SPEC.md` §6, `02_SCREEN_INVENTORY.md` §15 |
| Solutions from the Quran | Ref confirmed | same |
| Prophets mentioned in the Quran | Ref confirmed | same |
| Etiquette from the Quran | Ref confirmed | same |
| Major sins in the Quran | Ref confirmed | same |
| Quran & Science | Ref confirmed | same |
| Ontology Explorer / Thematic Topics | Ref confirmed | same |
| Search (Arabic, translation, chapter alias, quick links, voice, history) | Ref confirmed | `07_SEARCH_SPEC.md` |

## Cross-cutting (Settings / Platform / Product)

| Feature | Status | Detail |
|---|---|---|
| No ads, no purchases, no account | Ref confirmed | `16_PLATFORM_FEATURES_SPEC.md` §8 |
| No tracking/analytics/data collection | Ref confirmed (self-hosted crash logs only) | `16_PLATFORM_FEATURES_SPEC.md` §5, §8 |
| Minimal permissions | Ref confirmed | `16_PLATFORM_FEATURES_SPEC.md` §8 |
| Dark/light themes, 5+ Material color presets + dynamic color | Ref confirmed (7 presets + dynamic observed) | `18_VISUAL_REFERENCE_NOTES.md` §8 |
| 22-language UI localization | Ref confirmed | `15_LOCALIZATION_SPEC.md` §1 |
| RTL support | Ref confirmed | `15_LOCALIZATION_SPEC.md` §5 |
| Arabic/Persian numeral-system choice | Ref confirmed | `15_LOCALIZATION_SPEC.md` §4 |
| Resource download-source selection | Ref confirmed | `10_SETTINGS_SPEC.md` §2, `09_OFFLINE_RESOURCES_SPEC.md` §6 |
| Storage cleanup per resource category | Ref confirmed | `09_OFFLINE_RESOURCES_SPEC.md` §4 |
| Self-hosted crash logs / diagnostics | Ref confirmed | `16_PLATFORM_FEATURES_SPEC.md` §5 |
| Deep links (App Links + custom actions) | Ref confirmed | `16_PLATFORM_FEATURES_SPEC.md` §1 |
| Onboarding (language/theme/translations/tafsir) | Ref confirmed | `02_SCREEN_INVENTORY.md` §14 |
| Offline-first for all installed content | Ref confirmed | `09_OFFLINE_RESOURCES_SPEC.md` §7 |

## Memorize / AI — not present in reference

The reference app has **no memorization or AI recitation-tracking features of any kind**. Every
item in `docs/PROJECT_BRIEF.md`'s "Memorize" and "AI" product areas (memorization plans, listen/
repeat drilling, hide/reveal, review scheduling, strength tracking, testing, live location
detection, live word following, mistake detection, hesitation/self-correction events, adaptive
review coach, on-device recognition) is **Tahfeez-original** — there is nothing to study or
compare against in `AlfaazPlus/QuranApp` for these areas. This is expected and correct: it is
Tahfeez's core differentiator per `docs/PROJECT_BRIEF.md`, to be designed independently in later
milestones (17–19) using the memorization visual-language guidance already specified in
`docs/DESIGN_DIRECTION.md` §"Memorization visual language."

## Summary

Every feature `FEATURES.md`/`README.md` advertises has a corresponding entry above and a
supporting reference-doc section. Items marked "Ref claimed" without full independent
verification are flagged as such rather than asserted as confirmed, per this milestone's
requirement to mark unverified behavior as `NEEDS_VERIFICATION` rather than guess.
