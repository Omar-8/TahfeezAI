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
