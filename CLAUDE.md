# Tahfeez AI — Suggested Claude Code Project Instructions

You may merge the following rules into the project's `CLAUDE.md`.

## Mandatory reading

Before any substantial task, read:

- `docs/CLEAN_ROOM_RULES.md`
- `docs/DESIGN_DIRECTION.md`
- `docs/PROJECT_BRIEF.md`
- `docs/ARCHITECTURE.md` if it exists

For feature work, also read the relevant `docs/reference/*.md` files.

## Product

The application is **Tahfeez AI**, a Flutter Quran and memorization app for Android, iOS, and Web.

It is:

- offline-first;
- no mandatory account;
- no mandatory backend;
- privacy-oriented;
- Quran-correctness-focused;
- designed for future AI recitation assistance.

## Reference app

AlfaazPlus/QuranApp is a reference for:

- feature discovery;
- Quran-domain behavior;
- workflows;
- information hierarchy;
- common UX patterns.

It is not a codebase to port or a visual skin to clone.

## Visual direction

Aim for approximately **50–60% familiarity**, not pixel parity.

Tahfeez should be:

- more modern;
- more spacious;
- premium/calm;
- strong in light mode;
- excellent in dark mode;
- responsive beyond phones;
- increasingly memorization-first.

Never copy reference logos, icons, artwork, screenshots, or exact theme constants.

## Engineering

Prefer:

- Riverpod for state/dependency injection;
- go_router for routing;
- Drift/SQLite for local structured data;
- repository/domain boundaries;
- immutable Quran data separate from mutable user data;
- platform adapters rather than platform checks scattered throughout widgets;
- testable services;
- explicit offline/error/loading states.

Do not put SQL, filesystem logic, download code, audio-library calls, or AI-provider calls directly in presentation widgets.

## Quran correctness

Never generate canonical Quran text with AI.
Never silently edit Quran text.
Use source-verified Quran datasets.
Keep normalized search text separate from canonical display text.
Add integrity checks around Quran datasets.

## Resource provenance

Update `docs/THIRD_PARTY_RESOURCES.md` before shipping any external Quran text, font, translation, tafsir, audio, icon set, artwork, or AI model.

## Completion

Do not claim a milestone is complete until its Definition of Done is satisfied and analysis/tests/build checks pass.
