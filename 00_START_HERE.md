# Tahfeez AI — Prompt Kit

This kit is designed for building **Tahfeez AI** as an independent, offline-first Quran and memorization application for Android, iOS, and Web.

The project may study **AlfaazPlus/QuranApp** as a reference for functionality, information architecture, Quran-domain requirements, and successful UX patterns. Tahfeez AI must remain an independently implemented and independently branded product.

## Product target

Tahfeez AI should aim for:

- feature breadth comparable to QuranApp for reading/study/audio/offline use;
- approximately **50–60% familiarity in design language**, not pixel-level similarity;
- a clearly distinct Tahfeez AI brand;
- a more spacious, modern, calm, and premium UI;
- excellent light mode and dark mode;
- Android, iOS, and Web/PWA support from one primary Flutter codebase;
- core Quran reading and installed resources working offline;
- future AI-assisted memorization and recitation tracking;
- no mandatory account and no backend dependency for core use.

## Files to keep in the project root

Copy these files into the project under `docs/`:

- `CLEAN_ROOM_RULES.md`
- `DESIGN_DIRECTION.md`
- `PROJECT_BRIEF.md`
- `THIRD_PARTY_RESOURCES_TEMPLATE.md`

Milestone 0 creates the `docs/reference/` specification set.
Milestone 1 creates `docs/ARCHITECTURE.md`.

## How to run the milestones

Run milestones in order.

1. Give Claude Code the relevant milestone file.
2. Tell it to execute the milestone completely.
3. Do not begin the next milestone until the Definition of Done is satisfied.
4. Commit after each milestone.
5. Keep the reference specification and architecture documents updated when deliberate design decisions change.
6. Never silently weaken offline behavior or Quran correctness to finish a milestone faster.

## Important separation

`docs/reference/`
= what the reference QuranApp does.

`docs/DESIGN_DIRECTION.md`
= how Tahfeez AI should look and feel.

`docs/ARCHITECTURE.md`
= how Tahfeez AI should be engineered.

`docs/CLEAN_ROOM_RULES.md`
= what may and may not be reused.

When visual details conflict, **DESIGN_DIRECTION wins** while required functionality is preserved.

When architectural implementation details conflict with the Android reference, **ARCHITECTURE wins** because Tahfeez is a Flutter cross-platform application.

## Optional Milestone 7B

Milestone 7B is an advanced glyph-atlas rendering milestone. Do it only after the regular Mushaf renderer is already correct and stable.
