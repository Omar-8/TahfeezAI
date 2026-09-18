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
