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
