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
