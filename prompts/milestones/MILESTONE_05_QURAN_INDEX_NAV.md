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
