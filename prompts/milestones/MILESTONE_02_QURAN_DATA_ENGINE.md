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
