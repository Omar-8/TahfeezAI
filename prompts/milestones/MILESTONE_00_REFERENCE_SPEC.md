# Milestone 0 — Clean-Room Reference Specification

## Mandatory context

Before working, read:

- `docs/CLEAN_ROOM_RULES.md`
- `docs/DESIGN_DIRECTION.md`
- `docs/PROJECT_BRIEF.md`

If `docs/ARCHITECTURE.md` already exists, read it before changing architecture.

Read the relevant files in `docs/reference/` produced by Milestone 0.

### Authority rules

- `CLEAN_ROOM_RULES.md` controls reference/reuse boundaries.
- `DESIGN_DIRECTION.md` controls Tahfeez visual and UX direction.
- `ARCHITECTURE.md` controls implementation architecture after it exists.
- `docs/reference/` describes required reference behavior, not Tahfeez's exact appearance.
- If reference visual details conflict with Tahfeez design direction, preserve the functionality and redesign the presentation.
- Aim for roughly **50–60% visual familiarity**, not pixel parity.
- Use Tahfeez AI branding and independently written Flutter code.
- Maintain offline-first behavior unless the feature inherently requires network access.


## Objective

Study the current default branch of:

`https://github.com/AlfaazPlus/QuranApp`

and produce a comprehensive behavioral/product specification.

This milestone is **analysis only**. Do not build Tahfeez UI or port implementation code.

## Important design interpretation

While analyzing the reference, distinguish:

1. **behavior/functionality that Tahfeez should support**;
2. **generic/common UX patterns that are useful inspiration**;
3. **distinctive visual implementation details that Tahfeez should not reproduce exactly**.

The reference documentation must describe what the reference does accurately, while `DESIGN_DIRECTION.md` decides how Tahfeez presents it.

## Repository areas to inspect

Inspect at minimum:

- `README.md`
- `FEATURES.md`
- license/contributor/resource documentation
- Android manifest
- Gradle/module configuration
- Compose screens
- Compose components
- navigation
- theme/color/typography system
- repositories
- ViewModels/state holders
- Room databases
- entities/DAOs
- QuranRepository
- UserRepository
- reader code
- ReaderItemsBuilder
- Mushaf models
- Mushaf page/line mapping
- QuranTextMeasurer
- atlas/glyph rendering architecture
- search package
- search normalization/indexes
- recitation/media player
- audio state models
- download workers/managers
- translations
- tafsir
- word-by-word
- bookmarks
- reading history
- import/export
- settings
- onboarding
- Home components
- Verse of the Day
- reference/Quran collections
- localization
- widgets
- sharing
- deep links

Do not copy source code into the Tahfeez project.

## Required output

Create:

`docs/reference/01_FEATURE_MATRIX.md`
`docs/reference/02_SCREEN_INVENTORY.md`
`docs/reference/03_NAVIGATION_MAP.md`
`docs/reference/04_READER_SPEC.md`
`docs/reference/05_MUSHAF_SPEC.md`
`docs/reference/06_DATA_MODEL_SPEC.md`
`docs/reference/07_SEARCH_SPEC.md`
`docs/reference/08_AUDIO_SPEC.md`
`docs/reference/09_OFFLINE_RESOURCES_SPEC.md`
`docs/reference/10_SETTINGS_SPEC.md`
`docs/reference/11_HOME_SPEC.md`
`docs/reference/12_BOOKMARK_HISTORY_SPEC.md`
`docs/reference/13_TRANSLATION_TAFSIR_SPEC.md`
`docs/reference/14_WORD_BY_WORD_SPEC.md`
`docs/reference/15_LOCALIZATION_SPEC.md`
`docs/reference/16_PLATFORM_FEATURES_SPEC.md`
`docs/reference/17_TEST_PARITY_MATRIX.md`
`docs/reference/18_VISUAL_REFERENCE_NOTES.md`
`docs/reference/PARITY_CHECKLIST.md`

## Screen documentation

For every user-facing screen capture:

- purpose;
- entry routes;
- visible sections;
- order of sections;
- major actions;
- secondary actions;
- loading state;
- empty state;
- error state;
- offline state;
- navigation destinations;
- data required;
- settings affecting the screen;
- platform-specific behavior;
- responsive assumptions;
- generic UX pattern vs distinctive reference styling.

Do not put copied screenshots/assets into Tahfeez source.

## Features to explicitly verify

### Home

Verify:

- update/resource banners;
- Recommended / Verse of the Day behavior;
- read history;
- featured reading;
- Quran collections;
- mini player;
- bottom/main navigation behavior.

Record the information hierarchy, but label exact artwork/theme treatment as reference-only.

### Main navigation

Verify the prominence and destinations of:

- Home;
- Quran/index;
- Search;
- any other contextual navigation.

Tahfeez is allowed to change navigation later when Memorize becomes a primary product area.

### Reader

Verify:

- verse-by-verse mode;
- Mushaf mode;
- chapter/Juz/Hizb reading;
- page reading;
- toolbar/chrome;
- collapsing behavior;
- navigation;
- selection;
- bookmark actions;
- sharing;
- tafsir;
- translations;
- word-by-word;
- audio;
- auto-scroll;
- mini/expanded player;
- spotlight behavior;
- current playback highlighting;
- reader settings.

### Mushaf

Verify:

- Mushaf metadata;
- pages;
- line count;
- variable-line support;
- line types;
- Surah header lines;
- Bismillah lines;
- Ayah lines;
- centered lines;
- start/end Ayah;
- start/end word indexes;
- script/variant relationship;
- page scale;
- line fitting;
- atlas-capable rendering;
- touch mapping if present.

### Search

Verify:

- Arabic Quran text;
- translation search;
- Surah aliases;
- filters;
- search history;
- quick links;
- voice search entry;
- exact/full word;
- partial word;
- result grouping/navigation.

### Audio

Verify:

- Quran-only;
- translation-only;
- both;
- reciter;
- translation reciter;
- repeat;
- speed;
- verse grouping;
- audio-end behavior;
- verse synchronization;
- background player;
- automatic reader scrolling;
- spotlight;
- download progress;
- cache vs explicitly downloaded audio;
- offline behavior.

### Bookmarks/user data

Verify:

- single Ayah bookmark;
- range bookmark;
- note;
- edit/delete;
- selection/bulk operations;
- read history;
- backup/import/export;
- share behavior.

### Settings

Verify:

- language;
- theme mode;
- theme families;
- dynamic color;
- daily reminder;
- Arabic text toggle;
- text sizes;
- translations;
- tafsir;
- Quran scripts/variants;
- word-by-word;
- recitation downloads;
- resource sources;
- cleanup/logging/diagnostics;
- import/export.

### Word by word

Verify:

- downloadable languages;
- active language;
- translation;
- transliteration;
- word audio;
- update/delete states;
- tooltip behavior.

### Reference content

Verify the feature categories for:

- duas;
- guidance/solutions;
- prophets;
- etiquette;
- major sins;
- Quran/science;
- ontology/topics;
- thematic topics.

Do not assume Tahfeez may redistribute the same authored reference files.

## Visual reference document

`18_VISUAL_REFERENCE_NOTES.md` should record broad design observations only, such as:

- density;
- screen composition;
- navigation prominence;
- use of cards/lists;
- use of sheets;
- relative sizing;
- Material 3 patterns;
- reader minimalism;
- audio integration.

For each observation classify it:

- KEEP AS UX PRINCIPLE
- TAHFEEZ SHOULD EVOLVE
- DO NOT COPY EXACTLY

Do not turn this into a pixel-spec clone.

## License/resource questions

Create a section listing all unresolved rights questions for:

- Quran databases;
- Quran fonts;
- atlas resources;
- translations;
- tafsir;
- word-by-word;
- audio;
- icons/artwork;
- reference-content prose.

Update `docs/THIRD_PARTY_RESOURCES.md` only when a resource's terms are actually verified.

## Definition of Done

- Every advertised feature has a corresponding reference entry.
- Every major screen has a screen entry.
- Reader/Mushaf/audio/search/offline behavior is documented beyond README-level detail.
- Unknown behavior is marked `NEEDS_VERIFICATION` rather than guessed.
- A complete checkbox parity matrix exists.
- The visual reference notes explicitly support Tahfeez's 50–60% inspiration target rather than pixel parity.
