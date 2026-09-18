# Milestone 1 — Flutter Cross-Platform Foundation

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

Create the production foundation for Tahfeez AI on Android, iOS, and Web.

Do not build major feature screens yet.

## Technology

Use current stable, compatible releases of:

- Flutter / Dart;
- `flutter_riverpod`;
- `go_router`;
- `drift`;
- SQLite-native support for Android/iOS;
- Drift-compatible SQLite/WASM strategy for Web;
- `dio`;
- `freezed`;
- `json_serializable`;
- `just_audio`;
- `audio_service`.

If a dependency choice has materially changed since the specification was written, verify current official package/platform documentation before adopting it.

Do not add Firebase, Supabase, or a mandatory backend.

## Project structure

Use a feature/domain-oriented structure similar to:

```text
lib/
  app/
  core/
    database/
    routing/
    theme/
    localization/
    storage/
    networking/
    downloads/
    audio/
    logging/
    platform/
  quran/
    domain/
    data/
    application/
    presentation/
  features/
  memorization/
  ai/
```

Refine as needed, but keep clean boundaries.

## Foundation work

Implement:

1. `ProviderScope`;
2. `go_router` app shell;
3. Material 3 theme foundation;
4. system/light/dark theme support;
5. responsive breakpoints;
6. RTL-aware layout foundations;
7. localization infrastructure;
8. application error/logging abstraction;
9. database abstraction;
10. file/resource storage abstraction;
11. browser persistence abstraction;
12. network/connectivity abstraction;
13. resource download interfaces;
14. audio controller interface;
15. platform capability interfaces;
16. AI recognition interfaces.

## Future AI interface

Define a replaceable recognition contract, e.g. conceptual equivalents of:

- `RecitationRecognizer`
- `RecitationContext`
- `RecitationEvent`

Events should be capable of expressing later:

- recitation started;
- Quran position candidate;
- Ayah detected;
- word matched;
- word skipped;
- word incorrect;
- hesitation;
- self correction;
- confidence update;
- recitation ended;
- recognition error.

Do not implement actual AI.

## Repository interfaces

Define domain-first interfaces for:

- `QuranRepository`
- `UserDataRepository`
- `TranslationRepository`
- `TafsirRepository`
- `SearchRepository`
- `AudioRepository`
- `ResourceRepository`
- `MemorizationRepository`

The UI should not know how SQLite/files/network/audio libraries are implemented.

## Design foundations

Implement only enough UI to prove:

- Tahfeez light mode;
- Tahfeez dark mode;
- RTL;
- responsive breakpoints.

Do not copy QuranApp's colors.

Use initial Tahfeez design tokens consistent with `DESIGN_DIRECTION.md`, knowing Milestone 3 will refine them.

## Documentation

Create:

`docs/ARCHITECTURE.md`

Document:

- layers;
- dependency direction;
- repository pattern;
- database separation;
- offline strategy;
- platform adapters;
- Web persistence;
- audio;
- download/resource design;
- future AI boundary;
- testing strategy.

## Quality gate

Run and fix:

- formatter;
- static analysis;
- unit tests;
- Android build;
- Web build;
- iOS compile checks where the environment permits.

## Definition of Done

- The app boots on Android and Web and is structurally iOS-compatible.
- Light/dark/RTL foundations work.
- No backend is required.
- Architecture document exists.
- Core service interfaces are replaceable/testable.
- There are no placeholder architectural shortcuts that would require a rewrite for offline data or AI later.
