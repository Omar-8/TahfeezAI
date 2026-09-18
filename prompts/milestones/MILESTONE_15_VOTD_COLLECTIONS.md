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
