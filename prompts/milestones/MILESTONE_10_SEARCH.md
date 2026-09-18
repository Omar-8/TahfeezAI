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
