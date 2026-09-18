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
