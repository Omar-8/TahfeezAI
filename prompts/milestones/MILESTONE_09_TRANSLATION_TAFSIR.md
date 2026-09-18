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
