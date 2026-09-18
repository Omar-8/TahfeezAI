# Milestone 3 — Tahfeez AI Design System

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

Create Tahfeez AI's distinctive production design system.

This milestone is the visual foundation for all future UI.

The target is **modern, elegant, calm, and approximately 50–60% familiar in overall Quran-app design language**, not a QuranApp clone.

## Non-negotiable design direction

Follow `docs/DESIGN_DIRECTION.md` as the authority.

Do not reproduce:

- QuranApp exact colors;
- QuranApp custom artwork;
- QuranApp icons;
- exact component measurements simply because they were observed;
- exact card compositions where Tahfeez can improve them.

## Theme system

Implement semantic tokens for:

- colors;
- spacing;
- radii;
- elevation;
- typography;
- motion;
- icon sizes;
- content widths;
- breakpoints.

Suggested semantic types:

- `TahfeezColors`
- `TahfeezSpacing`
- `TahfeezRadii`
- `TahfeezTypography`
- `TahfeezMotion`

Support:

- System mode;
- Light;
- Dark.

Provide Tahfeez color families:

- Emerald/Green default;
- Blue;
- Burgundy;
- Purple;
- Violet;
- Gold/Sand;
- Monochrome.

Support platform dynamic/system color only where appropriate and optional.

## Light mode

Treat light mode as a premium primary experience.

Start from the warm/off-white, emerald, white-surface direction in `DESIGN_DIRECTION.md`, then adjust for:

- WCAG contrast;
- Quran readability;
- consistent Material 3 relationships;
- selected states;
- disabled states;
- errors;
- warnings;
- success.

## Dark mode

Design dark mode independently, with low-glare layered surfaces.

## Reusable components

Build Tahfeez-owned components for common needs:

- app bar;
- card;
- settings tile;
- section header;
- list row;
- action chip;
- filter chip;
- segmented/tabs;
- resource row;
- bottom sheet;
- dialog;
- loading state;
- empty state;
- error state;
- download progress;
- mini-player shell;
- Quran section card;
- verse action bar;
- responsive scaffold.

Use Material Symbols or another independently licensed icon set.

## Typography

Separate:

- application typography;
- Quran typography.

Application fonts must support Arabic + Latin gracefully.

Never use application typography as the Quran rendering solution.

## Component gallery

Create an internal/dev-only component gallery showing:

- all themes;
- light/dark;
- Arabic RTL;
- English LTR;
- cards;
- lists;
- sheets;
- dialog states;
- chips;
- player shell;
- loading/error/empty;
- memorization-state placeholders.

## Definition of Done

- Tahfeez has a recognizable identity independent of QuranApp.
- Light mode is polished, not an afterthought.
- Dark mode is equally coherent.
- RTL works.
- Components are reusable and token-driven.
- Future screens do not need arbitrary local colors/radii/spacing.
