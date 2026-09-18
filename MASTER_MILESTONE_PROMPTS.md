# Tahfeez AI — Complete Milestone Prompt Book

This file concatenates all milestone prompts for convenience.


---

<!-- MILESTONE_00_REFERENCE_SPEC.md -->

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


---

<!-- MILESTONE_01_FLUTTER_FOUNDATION.md -->

# Milestone 1 — Flutter Cross-Platform Foundation

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

Create the production foundation for Tahfeez AI on Android, iOS, and Web.

Do not build major feature screens yet.

## Technology

Use current stable, compatible releases of:

- Flutter / Dart;
- `flutter_riverpod`;
- `go_router`;
- `drift`;
- SQLite-native support for Android/iOS;
- Drift-compatible SQLite/WASM strategy for Web;
- `dio`;
- `freezed`;
- `json_serializable`;
- `just_audio`;
- `audio_service`.

If a dependency choice has materially changed since the specification was written, verify current official package/platform documentation before adopting it.

Do not add Firebase, Supabase, or a mandatory backend.

## Project structure

Use a feature/domain-oriented structure similar to:

```text
lib/
  app/
  core/
    database/
    routing/
    theme/
    localization/
    storage/
    networking/
    downloads/
    audio/
    logging/
    platform/
  quran/
    domain/
    data/
    application/
    presentation/
  features/
  memorization/
  ai/
```

Refine as needed, but keep clean boundaries.

## Foundation work

Implement:

1. `ProviderScope`;
2. `go_router` app shell;
3. Material 3 theme foundation;
4. system/light/dark theme support;
5. responsive breakpoints;
6. RTL-aware layout foundations;
7. localization infrastructure;
8. application error/logging abstraction;
9. database abstraction;
10. file/resource storage abstraction;
11. browser persistence abstraction;
12. network/connectivity abstraction;
13. resource download interfaces;
14. audio controller interface;
15. platform capability interfaces;
16. AI recognition interfaces.

## Future AI interface

Define a replaceable recognition contract, e.g. conceptual equivalents of:

- `RecitationRecognizer`
- `RecitationContext`
- `RecitationEvent`

Events should be capable of expressing later:

- recitation started;
- Quran position candidate;
- Ayah detected;
- word matched;
- word skipped;
- word incorrect;
- hesitation;
- self correction;
- confidence update;
- recitation ended;
- recognition error.

Do not implement actual AI.

## Repository interfaces

Define domain-first interfaces for:

- `QuranRepository`
- `UserDataRepository`
- `TranslationRepository`
- `TafsirRepository`
- `SearchRepository`
- `AudioRepository`
- `ResourceRepository`
- `MemorizationRepository`

The UI should not know how SQLite/files/network/audio libraries are implemented.

## Design foundations

Implement only enough UI to prove:

- Tahfeez light mode;
- Tahfeez dark mode;
- RTL;
- responsive breakpoints.

Do not copy QuranApp's colors.

Use initial Tahfeez design tokens consistent with `DESIGN_DIRECTION.md`, knowing Milestone 3 will refine them.

## Documentation

Create:

`docs/ARCHITECTURE.md`

Document:

- layers;
- dependency direction;
- repository pattern;
- database separation;
- offline strategy;
- platform adapters;
- Web persistence;
- audio;
- download/resource design;
- future AI boundary;
- testing strategy.

## Quality gate

Run and fix:

- formatter;
- static analysis;
- unit tests;
- Android build;
- Web build;
- iOS compile checks where the environment permits.

## Definition of Done

- The app boots on Android and Web and is structurally iOS-compatible.
- Light/dark/RTL foundations work.
- No backend is required.
- Architecture document exists.
- Core service interfaces are replaceable/testable.
- There are no placeholder architectural shortcuts that would require a rewrite for offline data or AI later.


---

<!-- MILESTONE_02_QURAN_DATA_ENGINE.md -->

# Milestone 2 — Offline Quran Data Engine

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

Build the offline Quran domain/data layer.

This milestone is primarily non-visual. Do not spend time styling screens.

## Database separation

Design conceptually separate stores:

### `quran.db`
Immutable/reference content such as:

- Surahs;
- Ayahs;
- scripts;
- words;
- Mushaf metadata;
- Mushaf line maps;
- navigation ranges;
- localized names;
- search source fields.

### `user.db`
Mutable user-owned state added in later milestones.

Do not mix user progress into immutable Quran data tables.

## Domain models

Support independent models for:

- Surah;
- Ayah;
- AyahWord;
- QuranScript;
- QuranScriptVariant;
- Mushaf;
- MushafPage;
- MushafLine;
- Juz;
- Hizb;
- navigation unit/range;
- localized Surah metadata.

`MushafLine` must support:

- Mushaf ID;
- page number;
- line number;
- line type;
- centered flag;
- start Ayah;
- start word;
- end Ayah;
- end word;
- optional Surah number.

Line types must include conceptual equivalents of:

- Surah header;
- Bismillah;
- Quran text.

Do not copy Room entities verbatim.

## Repository behavior

Implement domain-level methods for:

- get all Surahs;
- get Surah;
- get Ayah;
- get Ayah by stable ID;
- get verse range;
- get words for Ayah;
- get Mushaf;
- get page;
- get page lines;
- get words for a page line;
- get page for Ayah;
- get Juz/Hizb for page/location;
- get navigation ranges;
- validate locations;
- batch-load reader data.

Do not query SQLite separately for each visible word/verse.

## Dataset strategy

Do **not** import QuranApp's bundled database by default.

Create:

`docs/DATA_RESOURCE_REQUIREMENTS.md`

For each required dataset document:

- purpose;
- required fields;
- format;
- candidate independent sources;
- license status;
- redistribution requirements;
- integrity verification.

Only integrate a real dataset after its source and terms are recorded in `THIRD_PARTY_RESOURCES.md`.

## Integrity

Add deterministic validation for:

- exactly 114 Surahs;
- valid Ayah numbering;
- valid range boundaries;
- stable IDs;
- ordered words;
- valid page mappings;
- ordered Mushaf lines;
- valid line word ranges;
- no missing required Quran text;
- dataset version/hash metadata.

Canonical Quran text must remain unchanged. Search-normalized representations must be derived separately.

## Definition of Done

- Quran domain works without Flutter widgets.
- Repository APIs are tested.
- Dataset can be replaced without rewriting UI.
- No network is needed to query installed core Quran data.
- Integrity tests fail loudly when data is incomplete or inconsistent.


---

<!-- MILESTONE_03_DESIGN_SYSTEM.md -->

# Milestone 3 — Tahfeez AI Design System

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

Create Tahfeez AI's distinctive production design system.

This milestone is the visual foundation for all future UI.

The target is **modern, elegant, calm, and approximately 50–60% familiar in overall Quran-app design language**, not a QuranApp clone.

## Non-negotiable design direction

Follow `docs/DESIGN_DIRECTION.md` as the authority.

Do not reproduce:

- QuranApp exact colors;
- QuranApp custom artwork;
- QuranApp icons;
- exact component measurements simply because they were observed;
- exact card compositions where Tahfeez can improve them.

## Theme system

Implement semantic tokens for:

- colors;
- spacing;
- radii;
- elevation;
- typography;
- motion;
- icon sizes;
- content widths;
- breakpoints.

Suggested semantic types:

- `TahfeezColors`
- `TahfeezSpacing`
- `TahfeezRadii`
- `TahfeezTypography`
- `TahfeezMotion`

Support:

- System mode;
- Light;
- Dark.

Provide Tahfeez color families:

- Emerald/Green default;
- Blue;
- Burgundy;
- Purple;
- Violet;
- Gold/Sand;
- Monochrome.

Support platform dynamic/system color only where appropriate and optional.

## Light mode

Treat light mode as a premium primary experience.

Start from the warm/off-white, emerald, white-surface direction in `DESIGN_DIRECTION.md`, then adjust for:

- WCAG contrast;
- Quran readability;
- consistent Material 3 relationships;
- selected states;
- disabled states;
- errors;
- warnings;
- success.

## Dark mode

Design dark mode independently, with low-glare layered surfaces.

## Reusable components

Build Tahfeez-owned components for common needs:

- app bar;
- card;
- settings tile;
- section header;
- list row;
- action chip;
- filter chip;
- segmented/tabs;
- resource row;
- bottom sheet;
- dialog;
- loading state;
- empty state;
- error state;
- download progress;
- mini-player shell;
- Quran section card;
- verse action bar;
- responsive scaffold.

Use Material Symbols or another independently licensed icon set.

## Typography

Separate:

- application typography;
- Quran typography.

Application fonts must support Arabic + Latin gracefully.

Never use application typography as the Quran rendering solution.

## Component gallery

Create an internal/dev-only component gallery showing:

- all themes;
- light/dark;
- Arabic RTL;
- English LTR;
- cards;
- lists;
- sheets;
- dialog states;
- chips;
- player shell;
- loading/error/empty;
- memorization-state placeholders.

## Definition of Done

- Tahfeez has a recognizable identity independent of QuranApp.
- Light mode is polished, not an afterthought.
- Dark mode is equally coherent.
- RTL works.
- Components are reusable and token-driven.
- Future screens do not need arbitrary local colors/radii/spacing.


---

<!-- MILESTONE_04_HOME_NAVIGATION.md -->

# Milestone 4 — Home and Main Navigation

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

Build the main Tahfeez shell and Home.

Use the reference Home feature inventory, but compose it according to Tahfeez's design direction rather than reproducing QuranApp exactly.

## Main navigation

At this stage support:

- Home;
- Quran;
- Search.

Quran should remain highly discoverable/prominent.

Do not over-invest in an exact clone of the reference center action. Create a Tahfeez-owned solution using the Tahfeez component system.

Reserve architecture for adding `Memorize` as a primary destination in Milestone 17.

## Home information hierarchy

Support the reference-equivalent feature areas:

1. resource/update notices;
2. Recommended / Daily Ayah;
3. Continue Reading / read history;
4. featured Quran reading;
5. Quran collections/exploration;
6. persistent mini-player region when active.

Tahfeez may reorder or visually combine sections if it improves clarity.

## Tahfeez-specific direction

Even before memorization is implemented, design the Home so it can later accommodate:

- Today's Memorization;
- Today's Revision;
- Memorization progress.

Do not paint the architecture into a reading-only corner.

## Visual behavior

Prefer:

- warm light background;
- clear page greeting/title;
- larger, calmer primary cards;
- modern rounded surfaces;
- restrained borders/shadows;
- tasteful horizontal rails where useful;
- card/grid adaptation on tablet.

Do not use QuranApp wallpaper or artwork.

## Responsive

Phone:
- vertical feed;
- bottom navigation.

Tablet:
- adaptive card grid;
- navigation rail if clearly better.

Desktop:
- constrained content width and adaptive navigation.

## Data states

Wire real repositories where available.

For future data sources, implement intentional:

- loading;
- empty;
- offline;
- unavailable-resource states.

Do not insert fake production Quran data.

## Tests

Test:

- navigation destinations;
- section rendering;
- RTL;
- light/dark;
- mini-player reserved space;
- adaptive layouts.

## Definition of Done

The Home feels recognizably Tahfeez, includes all important reading/reference entry points, and can later evolve into a memorization-first dashboard without redesigning the app shell.


---

<!-- MILESTONE_05_QURAN_INDEX_NAV.md -->

# Milestone 5 — Quran Index and Navigation

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

Build fast offline navigation to Quran content.

## Navigation modes

Support:

- Surah;
- Juz;
- Hizb;
- Page;
- direct Ayah selection.

## Unified location model

Create a single domain concept such as `QuranLocation` capable of expressing:

- Surah;
- Ayah;
- Ayah range;
- Juz;
- Hizb;
- page.

Do not invent separate incompatible navigation argument schemes per screen.

## Quran index UI

Design a Tahfeez-owned index screen.

It may be inspired by familiar Quran index conventions, but it should use:

- Tahfeez typography;
- Tahfeez spacing;
- Tahfeez tabs/segmented controls;
- Tahfeez list rows;
- warm light-mode surfaces.

Surah items should show useful installed metadata such as:

- Surah number;
- Arabic name;
- localized name;
- Ayah count;
- revelation metadata where sourced.

## Search/filter

Provide fast filtering in long indexes where helpful.

## Routing

Every index result should route through `QuranLocation`.

Routes should be deep-link-safe and serializable.

Remember recent/current context where appropriate.

## Offline

All navigation metadata must come from installed local Quran data.

## Definition of Done

A user can reach any Surah, Juz, Hizb, Page, or Ayah quickly without network access and without screen-specific routing hacks.


---

<!-- MILESTONE_06_VERSE_READER.md -->

# Milestone 6 — Verse-by-Verse Reader

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

Create a production-quality semantic Quran reader before advanced Mushaf rendering.

## Reading modes supported now

Support:

- full Surah;
- verse range;
- individual Ayah;
- Juz;
- Hizb;
- continuous scrolling.

## Verse presentation

Each verse should be an independent domain/presentation unit supporting:

- Arabic Quran text;
- Ayah marker;
- selected translation slots;
- future word-by-word;
- bookmark state;
- playback/current state.

Do not hard-code Quran text into widgets.

## Reader chrome

Build Tahfeez-owned reader controls:

- location/title;
- back/navigation;
- reader options;
- mode switch;
- verse selection;
- contextual actions.

Use collapsible/minimal chrome so Quran content becomes the visual focus.

## Verse actions

Provide hooks/actions for:

- play;
- bookmark;
- share;
- tafsir;
- copy where appropriate;
- range selection;
- word details later.

Where later functionality is not implemented yet, wire interfaces or intentional disabled states rather than fake behavior.

## Performance

Use:

- lazy rendering;
- stable keys;
- batch repository loads;
- cached derived presentation data;
- no database query per build/per word.

## User state

Persist:

- current location;
- last read;
- reader mode;
- enough context to restore after restart.

Create/read history through the user-data abstraction once available.

## Auto-scroll/audio integration

Prepare clean interfaces for:

- current Ayah highlighting;
- auto-scroll;
- mini player;
- expanded player.

Do not couple the reader directly to `just_audio`.

## Styling

The reader should be quieter than Home.

Use Tahfeez design tokens, but reduce decorative chrome around Quran text.

## Definition of Done

The reader is fully usable offline, performant on long ranges, restorable after restart, and architecturally ready for translation, tafsir, WBW, audio, and memorization.


---

<!-- MILESTONE_07_MUSHAF_RENDERER.md -->

# Milestone 7 — Accurate Mushaf Renderer

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

Build Tahfeez's printed-page-style Mushaf reader.

The Mushaf should aim for fidelity to the **actual Mushaf layout**, not visual similarity to QuranApp branding.

## Data contract

Consume structured data:

`MushafPage`
- page number;
- Juz;
- Hizb;
- Mushaf ID;
- lines.

`MushafLine`
- line number;
- type;
- centered;
- exact word range;
- optional Surah reference.

Line types:

- Quran text;
- Surah header;
- Bismillah.

Do not render a page by placing all Quran text into one wrapping widget.

## Layout engine

Create a UI-independent `MushafPageLayoutEngine`.

For each line:

1. resolve exact words;
2. measure words;
3. calculate total natural width;
4. calculate available width;
5. determine scale;
6. calculate inter-word spacing;
7. honor centered/special lines;
8. prevent clipping;
9. prevent accidental wrap;
10. output deterministic word/glyph placements.

Use reasonable min/max scaling constraints.

## Rendering

First version should be font-based.

Support:

- RTL;
- Arabic shaping;
- exact line count from selected Mushaf;
- page margins;
- Surah header;
- Bismillah;
- Ayah markers;
- page number;
- Juz/Hizb context;
- word hit testing;
- Ayah/word mapping.

## Interaction

A visible word must map back to:

- Ayah ID;
- word index;
- Quran location.

This is necessary for later:

- WBW;
- playback;
- memorization;
- AI highlighting.

## Device modes

Phone:
- one page;
- horizontal page movement.

Tablet landscape:
- optional two-page spread.

Desktop:
- one/two page depending width;
- constrained physical-page-like proportions.

## Reader appearance

Support reader appearance hooks for:

- Light;
- Warm;
- Sepia;
- Dark;
- Black.

Do not let application card styling leak into the Mushaf page.

## Verification

Create visual/golden tests for representative pages:

- Al-Fatihah;
- beginning of Al-Baqarah;
- middle Quran page;
- page with Surah transition;
- final page.

Also add layout invariants:

- expected line count;
- no line overflow;
- no unexpected wrap;
- deterministic placements.

## Future atlas boundary

Define a replaceable interface for a future glyph-atlas renderer without implementing it now.

## Definition of Done

Do not call this milestone complete merely because all pages render.

It is complete when representative pages render consistently and correctly, word hit testing works, and the renderer is stable enough to become the foundation for memorization/AI overlays.


---

<!-- MILESTONE_07B_GLYPH_ATLAS.md -->

# Milestone 7B — Optional Glyph-Atlas Mushaf Rendering

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


## When to run

Only run after Milestone 7 is correct and stable.

## Objective

Explore an independent high-fidelity glyph-atlas pipeline for Tahfeez.

Do not copy QuranApp's atlas implementation, binary format, file names, or code.

## Tooling concept

Use a suitable shaping engine such as HarfBuzz during an offline preprocessing/build step.

Create Tahfeez's own versioned atlas format containing only required data such as:

- glyph ID;
- atlas image/page;
- source rectangle/UV;
- dimensions;
- x/y offset;
- advance;
- units-per-em;
- word-to-glyph mapping;
- page/script metadata.

## Licensing

Only generate atlases from fonts whose licenses permit the intended processing and redistribution.

Record each font/resource in `THIRD_PARTY_RESOURCES.md`.

## Flutter renderer

Implement a `CustomPainter` or other appropriate renderer behind the existing Mushaf rendering abstraction.

It should preserve:

- word hit testing;
- Ayah mapping;
- memorization overlays;
- current word highlighting.

## Comparison

Compare font renderer vs atlas renderer using representative Mushaf pages.

Do not replace the font renderer until:

- visual tests demonstrate a meaningful accuracy improvement;
- performance is acceptable;
- platform consistency is proven.

## Definition of Done

The atlas implementation is independent, versioned, license-audited, testable, and interchangeable with the normal font renderer.


---

<!-- MILESTONE_08_SCRIPTS_WBW.md -->

# Milestone 8 — Quran Scripts and Word-by-Word

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

Support multiple Quran script families/variants and a complete word-by-word resource layer.

## Scripts

Design `QuranScript` and `QuranScriptVariant` abstractions.

Architecture should accommodate:

- Uthmani;
- IndoPak;
- KFQPC-style/page-font approaches;
- future atlas-based scripts.

Do not assume every script has:

- identical word strings;
- identical page mappings;
- identical page count;
- identical line count.

Script selection may change:

- source words;
- Mushaf;
- font;
- line map;
- renderer;
- downloadable resources.

## Word-by-word

Create versioned downloadable WBW resources.

Data should support:

- language;
- word translation;
- optional transliteration;
- version;
- checksum;
- source/license metadata.

Preferences:

- selected language;
- show translation;
- show transliteration;
- tooltip translation;
- tooltip transliteration;
- word audio enabled.

## Reader interaction

Tap a Quran word to open a Tahfeez-owned word detail sheet.

It may show:

- Arabic word;
- translation;
- transliteration;
- play word audio;
- location context.

## Resource states

Support:

- not installed;
- queued;
- downloading with progress;
- installed;
- update available;
- failed;
- deleting.

Installed WBW must remain usable offline.

## Styling

Do not duplicate the reference settings/resource rows exactly.

Use Tahfeez resource-row and bottom-sheet components.

## Definition of Done

Scripts are swappable without UI rewrites, WBW is versioned/downloadable/offline, and word hit testing connects correctly from both reader modes.


---

<!-- MILESTONE_09_TRANSLATION_TAFSIR.md -->

# Milestone 9 — Translations and Tafsir

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

Implement high-quality downloadable/offline translation and tafsir.

## Translation resource model

Support metadata such as:

- ID/slug;
- display name;
- language;
- author/organization;
- version;
- source;
- license;
- checksum;
- format version;
- installed/update state.

Support:

- multiple selected translations simultaneously;
- ordering;
- footnotes;
- Quran cross references;
- download;
- update;
- delete;
- offline read.

Use independently defined Tahfeez file/resource formats.

## Tafsir

Support:

- multiple tafsir works;
- multiple languages;
- active selection;
- download/update/delete;
- offline reading;
- text-size setting.

## Reader integration

Verse-by-verse reader:

- multiple translation blocks;
- footnote preview;
- reference preview;
- tafsir action.

Mushaf:

- use a separate bottom/side sheet or panel so the printed page remains visually clean.

## Tafsir reader

Build a Tahfeez-owned reader supporting:

- Surah/Ayah context;
- previous/next navigation;
- adjustable text size;
- source metadata;
- offline state.

## Resource safety

Downloads must:

- be staged;
- validate format;
- verify checksum;
- activate atomically;
- never replace a working resource with a corrupt download.

## Licensing

Do not bundle any translation/tafsir until its redistribution/offline terms are recorded.

## Definition of Done

Installed translations and tafsir are fully usable offline, multiple translations can coexist, and the visual treatment fits Tahfeez rather than mirroring the reference.


---

<!-- MILESTONE_10_SEARCH.md -->

# Milestone 10 — Advanced Offline Quran Search

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

Implement fast, fully offline Quran search with advanced behavior.

## Indexes

Use SQLite FTS5 or an equivalent local indexed approach for:

- Arabic Quran text;
- Surah names/aliases;
- installed translations.

## Normalization

Create an independent `SearchNormalizer`.

Support appropriate search forms for:

- Arabic diacritics;
- common Alef variants;
- punctuation;
- whitespace;
- full-word;
- partial-word.

Do not mutate canonical Quran text.

## Search domains

Support:

- Quran text;
- Surah;
- translation;
- quick navigation.

## UI

Build a Tahfeez search experience with:

- dedicated search field/app bar;
- filter control;
- optional voice-search entry;
- recent history;
- quick links when empty;
- Surah matches;
- Quran matches;
- translation matches;
- clear loading/empty/error states.

Do not recreate reference tabs/cards pixel-for-pixel.

Use Tahfeez spacing, typography, chips, and filters.

## Navigation

Every result should resolve to `QuranLocation`.

## Search history

Persist locally and allow clear/delete behavior.

## Future AI

Voice recognition output should later be able to enter the same SearchController as text input.

## Tests

Test representative Arabic normalization and exact/partial behavior.

## Definition of Done

Core Quran search is fast with no network, translation search works for installed resources, and result navigation is deterministic.


---

<!-- MILESTONE_11_USER_DATA_SHARE.md -->

# Milestone 11 — Bookmarks, Reading History, Sharing, Backup

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

Build Tahfeez's user-owned Quran data features.

## User database

Implement models for:

### Bookmark
- stable ID;
- Surah/chapter;
- start Ayah;
- end Ayah;
- optional note;
- created/updated timestamps.

### Reading history
- location type;
- reader mode;
- chapter/division;
- verse range;
- Mushaf/script;
- page;
- timestamp.

Keep schema independent from QuranApp.

## Bookmark UX

Support:

- single Ayah;
- range;
- add/edit note;
- open in reader;
- delete;
- multi-select;
- bulk delete;
- visible bookmark state in reader.

Create a polished Tahfeez bookmarks screen.

## Reading history

Support:

- continue reading;
- recent items;
- history list;
- remove item;
- clear history where appropriate;
- Home integration.

## Sharing

Build a Tahfeez share composer with options for:

- Arabic;
- one/multiple selected translations;
- Quran reference;
- range;
- footnotes if supported;
- bookmark note if user chooses.

Do not copy reference export/share wording.

## Backup/import

Define a versioned Tahfeez backup schema.

Support:

- bookmarks;
- settings;
- supported user state;
- import validation;
- merge/replace choices where appropriate.

Never silently overwrite user data.

Web:
- download/upload files.

Mobile:
- file picker/share sheet.

## Definition of Done

User data is local/offline, range bookmarks and notes work, backup format is versioned, and import failures cannot corrupt the current database.


---

<!-- MILESTONE_12_AUDIO.md -->

# Milestone 12 — Recitation and Audio Player

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

Implement Tahfeez's shared Quran recitation engine.

## Architecture

Use a single application-level `AudioController`.

UI must not depend directly on `just_audio`.

Use `audio_service` for mobile background/system integration where supported.

## Playback state

Model at least:

- current Surah/Ayah;
- resolving/loading;
- download progress;
- playing;
- paused;
- buffering;
- verse sync available;
- current reciter;
- translation reciter;
- speed;
- repeat;
- audio mode;
- end behavior.

## Audio modes

Support:

1. Quran only;
2. Translation only;
3. Quran + Translation.

When both are selected, support configurable verse grouping such as:

- 1
- 2
- 3
- 5
- 10

where the resource structure permits it.

## Controls

Support:

- reciter selection;
- translation reciter;
- play/pause;
- next/previous Ayah;
- seek where meaningful;
- speed;
- repeat count;
- end behavior;
- offline source selection;
- download.

## Reader integration

Implement:

- current Ayah highlighting;
- optional current word hooks if timing exists;
- auto-scroll;
- mini player;
- expanded player;
- Spotlight-like focus mode as a Tahfeez-owned design.

## Tahfeez visual direction

This is a major UI milestone.

Create:

- elegant low-profile mini player;
- polished expanded player;
- light/dark consistency;
- large touch controls;
- readable reciter/settings state;
- quiet integration with Quran reading.

Do not recreate the reference player's exact layout.

## Offline

Explicitly downloaded local audio should take precedence.

If offline and audio is unavailable, display a clear unavailable/download-required state.

## Web

Support browser-compatible playback while gracefully handling browser limitations for background/system controls.

## Definition of Done

Playback survives normal navigation, reader synchronization works, downloaded audio works offline, and both mini/expanded players feel native to Tahfeez.


---

<!-- MILESTONE_13_RESOURCE_MANAGER.md -->

# Milestone 13 — Offline Resource and Download Manager

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

Create one reliable resource system for all optional downloadable content.

## Resource types

Support:

- translation;
- tafsir;
- word-by-word;
- word audio;
- recitation;
- script/font;
- Mushaf atlas;
- reference collection;
- future AI model.

## State machine

Use a clear resource lifecycle such as:

- notInstalled;
- checking;
- queued;
- downloading(progress);
- extracting;
- verifying;
- installed;
- updateAvailable;
- failed.

## Manifest

Every resource should have versioned metadata:

- ID;
- type;
- name;
- version;
- format version;
- size;
- URL/source;
- checksum;
- source/license metadata.

## Download safety

Implement:

- cancel;
- retry;
- resumable behavior where feasible;
- free-space check;
- temporary staging;
- extraction;
- checksum verification;
- atomic activation;
- cleanup;
- previous-version safety where reasonable.

Never make a partially downloaded resource active.

## Storage UI

Build Tahfeez-owned screens for:

- available resources;
- installed resources;
- update available;
- storage usage;
- cleanup;
- active download progress.

Use Tahfeez resource components rather than copying reference rows.

## Platform storage

Native:
- app filesystem + database metadata.

Web:
- persistent browser storage abstraction;
- Drift/SQLite web persistence;
- appropriate Cache/OPFS/IndexedDB strategy.

Do not claim browser storage is guaranteed indefinitely.

## Offline invariant

Deleting all optional resources must not break core Quran reading.

## Definition of Done

All resource types use one coherent lifecycle, corruption is handled safely, cleanup works, and airplane-mode startup remains functional.


---

<!-- MILESTONE_14_SETTINGS_LOCALIZATION.md -->

# Milestone 14 — Settings, Themes, Localization

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

Build the complete Tahfeez Settings experience and production localization foundation.

## Settings categories

### Application

- language;
- theme mode;
- theme family;
- dynamic/system color if supported;
- Daily Ayah reminder;
- Arabic text visibility.

### Reader

- Arabic text size;
- translation text size;
- tafsir text size;
- translations;
- tafsir;
- Quran script/variant;
- word-by-word;
- reader mode;
- reader appearance;
- auto-scroll speed.

### Audio/resources

- recitation resources;
- resource manager;
- storage cleanup;
- download behavior.

### Data/privacy

- export/import;
- search history;
- privacy choices.

### About

- app version;
- third-party notices;
- resource licenses;
- diagnostics/logs where appropriate.

## Theme UI

Expose all Tahfeez theme families from Milestone 3.

Light mode must look intentionally designed.

Theme preview UI should be Tahfeez-specific.

## Localization

Use Flutter localization infrastructure.

Initially ship/support:

- English;
- Arabic;
- German.

Architecture must support 20+ languages later.

Do not copy the reference app's localized strings as Tahfeez translations.

## RTL

Test Arabic thoroughly:

- settings;
- reader;
- navigation;
- bottom sheets;
- search;
- indexes.

Quran text direction must remain correct regardless of application locale.

## Definition of Done

Settings expose the full reader/resource/theme feature set, theme changes are immediate and persistent, and English/Arabic/German are production-ready.


---

<!-- MILESTONE_15_VOTD_COLLECTIONS.md -->

# Milestone 15 — Daily Ayah, Quran Collections, Reminders

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

Implement Tahfeez's daily Quran and exploration layer.

## Daily Ayah

Create:

- daily Ayah card;
- Arabic;
- selected translation;
- open in reader;
- share;
- local reminder;
- configurable reminder time.

Use a deterministic, documented selection method or independently curated dataset.

Do not copy reference recommendation text/data without licensing verification.

## Quran collections architecture

Create data-driven models such as:

- `QuranCollection`
- `CollectionSection`
- `QuranReference`
- optional source/description.

Support broad categories comparable in usefulness to:

- Quran duas;
- guidance/solutions;
- prophets;
- etiquette;
- major sins;
- Quran/science references;
- thematic topics;
- ontology/topic exploration.

Tahfeez may rename/reorganize categories.

## Resource rule

Do not copy authored prose/reference JSON simply because the reference app contains it.

Use independently licensed or independently authored collection data and record sources.

## Home integration

Use Tahfeez cards/grid design.

This is a good place to make Home feel more distinct from QuranApp.

Consider combining:

- Daily Ayah;
- Continue Reading;
- Explore Quran;

in a cleaner Tahfeez hierarchy.

## Notifications

Mobile:
- local notifications.

Web:
- use browser notification capability when appropriate;
- gracefully handle unsupported/background restrictions.

## Definition of Done

Daily Ayah and installed collections work offline, every Quran reference deep-links correctly, and the Home exploration experience feels distinctly Tahfeez.


---

<!-- MILESTONE_16_RESPONSIVE_PWA.md -->

# Milestone 16 — Responsive Tablet/Desktop/Web and PWA

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

Make Tahfeez excellent on large screens and installable/offline-capable on the Web.

## Do not stretch mobile

Phone:
- compact primary navigation;
- one-page Mushaf;
- sheets.

Tablet:
- adaptive navigation rail;
- richer grid;
- optional two-page Mushaf;
- side-by-side contextual content where helpful.

Desktop/Web:
- adaptive navigation;
- constrained reading width;
- optional side panel for tafsir/translation/notes/player;
- one/two-page Mushaf based on viewport;
- keyboard-friendly interactions.

## Tahfeez desktop identity

Do not create a literal Android tablet clone.

Use editorial spacing and a calmer Quran reading layout.

## PWA

Implement:

- installable manifest;
- application-shell caching;
- installed Quran core available offline;
- fonts cached appropriately;
- persistent local DB;
- resource persistence where browser allows;
- useful offline-state handling.

Request persistent browser storage where appropriate.

Never promise that browser-managed storage can never be evicted.

## Keyboard

Add useful keyboard support such as:

- arrows/page movement;
- search shortcut;
- escape closes overlays;
- focus management.

## Testing

Test representative viewports:

- small mobile;
- large mobile;
- tablet portrait;
- tablet landscape;
- laptop;
- desktop.

Test English and Arabic.

Test offline restart of installed PWA.

## Definition of Done

Tahfeez feels intentionally designed on each form factor and remains useful offline on Web within browser-platform constraints.


---

<!-- MILESTONE_17_MEMORIZATION.md -->

# Milestone 17 — Offline Memorization Engine

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

Make Tahfeez meaningfully different from a generic Quran reader by adding a full memorization system without requiring AI.

## Primary navigation evolution

Now that memorization exists, reassess primary navigation.

Preferred target:

- Home
- Quran
- Memorize
- Search

Use adaptive navigation for larger screens.

Do not retain the earlier navigation solely because the reference app used it.

## Domain models

Implement:

- MemorizationPlan;
- MemorizationAssignment;
- MemorizedRange;
- ReviewSchedule;
- MemorizationSession;
- AyahMemoryState;
- WordMemoryState;
- PracticeAttempt.

## Practice modes

Support:

1. Read;
2. Listen & Repeat;
3. Hide & Recall;
4. Verse Test;
5. Review;
6. continuous-recitation preparation.

## Features

Allow:

- select range;
- create daily target;
- repeat Ayah N times;
- repeat range;
- progressively hide;
- hide all;
- tap to reveal;
- first-word hint;
- next-word hint;
- combine adjacent Ayahs;
- rate easy/medium/hard;
- record confidence;
- record attempts;
- schedule review.

## Spaced repetition

Implement a documented local heuristic.

Do not market the heuristic as a religious correctness score.

## Mushaf integration

Use the **same** Quran/Mushaf renderer.

Add non-destructive visual overlay states for:

- visible;
- dimmed;
- hidden;
- revealed;
- current;
- weak.

Never alter stored Quran text to hide/reveal it.

## Home evolution

Introduce Tahfeez-owned cards such as:

- Today's Memorization;
- Today's Revision;
- progress summary.

This should make the Home substantially more distinct from QuranApp.

## Audio

Reuse the AudioController for repetitions.

## Offline

The complete memorization system must work offline.

## Definition of Done

A user can create a Hifz plan, practice, hide/reveal, repeat audio, track attempts, and receive locally scheduled revision without AI or network.


---

<!-- MILESTONE_18_AI_TRACKING.md -->

# Milestone 18 — AI Recitation Tracking Foundation

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

Add live Quran recitation position tracking.

Do **not** attempt full mistake detection or Tajweed yet.

## Recognition architecture

Use the replaceable interface created in Milestone 1.

Implement:

- audio capture abstraction;
- recognition session controller;
- Quran sequence matcher;
- alignment service;
- mock recognizer;
- real recognizer prototype/adapter.

The system should be structured as:

audio
→ acoustic/speech candidates
→ Quran-constrained matcher
→ Ayah/word position
→ application events

Do not architect this as generic unrestricted Arabic dictation only.

## Events

Support:

- started;
- Ayah candidate;
- Ayah detected;
- word position changed;
- confidence changed;
- paused/stopped;
- error.

## Context

Recognition should accept optional constraints:

- current Surah;
- expected range;
- memorization assignment.

This dramatically narrows the search space.

## UI

Create a distinctly Tahfeez recitation-practice experience:

- microphone/listening control;
- clear privacy state;
- live current Ayah;
- live current word;
- confidence/uncertain state;
- automatic reader following;
- stop/pause.

Use the Mushaf/reader word mapping from Milestone 7.

The AI visual language should follow `DESIGN_DIRECTION.md` and should not resemble generic audio waveform apps unnecessarily.

## Privacy

Do not persist raw microphone recordings by default.

Clearly document when audio leaves the device if a cloud recognizer is used.

## Mock implementation

The full UI and application event pipeline must be testable with a deterministic mock recognizer.

## Documentation

Create:

`docs/AI_RECOGNITION_ARCHITECTURE.md`

## Definition of Done

A mocked or prototype recognizer can drive live Ayah/word following without coupling UI to a specific AI provider.


---

<!-- MILESTONE_19_AI_MISTAKES_COACH.md -->

# Milestone 19 — Mistake Detection and Adaptive Tahfeez Coach

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

Add constrained word-level memorization feedback and adaptive review planning.

This is not Tajweed scoring.

## Expected-range alignment

When the user practices a selected range, compare recognized sequence events with the known expected Quran sequence.

Detect:

- CORRECT;
- SKIPPED;
- INCORRECT/SUBSTITUTED;
- ADDED;
- HESITATION;
- SELF_CORRECTED.

Every event should map to exact:

- Surah;
- Ayah;
- word index;
- practice session.

## UI feedback

Design non-destructive Quran overlays for:

- current word;
- correct progress;
- skipped word;
- incorrect word;
- hesitation;
- self-correction.

Do not alter Quran characters.

Avoid excessive red/green visual noise. The Quran should remain readable and dignified.

## Session records

Persist:

- range;
- duration;
- attempts;
- prompts;
- mistakes;
- self corrections;
- hesitation count;
- completion;
- recognizer/model version.

## Memory strength

Build a documented `MemoryStrengthEngine`.

Consider signals such as:

- recall success;
- mistakes;
- hints;
- hesitation;
- self corrections;
- elapsed time;
- previous review interval.

Treat the score as a learning heuristic, not as a declaration of religious correctness.

## Coach

Generate local review recommendations such as:

- weak ranges;
- frequently missed words;
- long-unreviewed ranges;
- scheduled revision;
- recent low-confidence sessions.

The first coach version can be deterministic and local; it does not require a general-purpose LLM.

## Analytics UI

Build Tahfeez-owned analytics:

- Surah/range progress;
- due reviews;
- weak Ayahs;
- recurring word mistakes;
- history.

Make this visually distinct and modern rather than copying any Tarteel/QuranApp screen.

## Testing

Use deterministic simulated recognition streams to verify alignment and scoring.

## Definition of Done

Mistake events are reproducible/tested, analytics update correctly, and Tahfeez can recommend revision based on local learning history.


---

<!-- MILESTONE_20_HARDENING_RELEASE.md -->

# Milestone 20 — Parity Audit, Offline Audit, Hardening, Release

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

Prepare Tahfeez AI for production-quality release and measure feature parity honestly.

## Part A — Reference parity audit

Read:

`docs/reference/PARITY_CHECKLIST.md`

For every reference capability classify:

- DONE;
- PARTIAL;
- INTENTIONALLY DIFFERENT;
- NOT SUPPORTED;
- BUG.

Do not mark DONE without a test/manual verification path.

Visual differences are expected when they follow `DESIGN_DIRECTION.md`.

## Part B — Tahfeez product audit

Verify Tahfeez-specific features:

- Memorize destination;
- plans;
- hide/reveal;
- review scheduling;
- AI tracking;
- AI mistakes;
- coach/analytics.

## Part C — Offline audit

Disable networking and verify:

- app launches;
- Quran opens;
- verse reader works;
- Mushaf works;
- navigation works;
- search works;
- bookmarks/history work;
- installed translations work;
- installed tafsir works;
- installed WBW works;
- downloaded audio works;
- memorization works;
- local reminders work where supported.

## Part D — Performance

Profile:

- cold startup;
- DB initialization;
- search latency;
- long reader scrolling;
- Mushaf layout/render;
- page swiping;
- memory;
- audio transitions;
- download extraction;
- AI event UI performance.

Optimize real bottlenecks.

## Part E — Quran integrity

Add/verify:

- Surah count;
- Ayah counts;
- canonical data version/hash;
- page mappings;
- Mushaf line boundaries;
- word indexes;
- script relationships;
- resource checksums.

Fail safely if critical Quran data is corrupt.

## Part F — On-device AI evaluation

Evaluate current viable on-device recognition options.

Requirements:

- replaceable model;
- versioned downloadable model files if needed;
- checksum;
- Android/iOS support;
- Web fallback;
- CPU/RAM/battery measurement;
- privacy documentation.

Do not claim "offline AI" if accuracy is not acceptable.

A hybrid architecture is acceptable.

## Part G — License/resource audit

Audit every:

- dependency;
- Quran dataset;
- translation;
- tafsir;
- font;
- audio source;
- word-by-word dataset;
- AI model;
- icon set;
- illustration.

Generate appropriate third-party notices from the verified register.

## Part H — Visual consistency audit

Review all major screens in:

- Tahfeez light;
- Tahfeez dark;
- Arabic RTL;
- English LTR;
- phone;
- tablet;
- desktop.

Look for:

- accidental QuranApp imitation beyond the intended inspiration level;
- inconsistent old/default Flutter widgets;
- arbitrary colors/spacing;
- cramped screens;
- poor light mode;
- poor contrast;
- unstyled error/offline states.

Refine toward Tahfeez identity.

## Part I — Release

Prepare:

- Android release;
- iOS release;
- Web/PWA release.

Preserve:

- no mandatory account;
- no ads by default;
- no tracking by default;
- offline-first Quran experience.

Create:

`docs/RELEASE_READINESS.md`

## Definition of Done

Tahfeez is stable, license/resource provenance is documented, offline behavior is verified, feature gaps are transparent, and the visual product feels cohesive and independently branded.
