# Tahfeez AI

An offline-first Quran and memorization app for Android, iOS, and Web, built with Flutter.

This file is the standard Flutter package README. For project context, start with
[`00_START_HERE.md`](00_START_HERE.md) and `docs/`:

- [`docs/PROJECT_BRIEF.md`](docs/PROJECT_BRIEF.md) — vision, platforms, product areas.
- [`docs/DESIGN_DIRECTION.md`](docs/DESIGN_DIRECTION.md) — visual/UX direction.
- [`docs/CLEAN_ROOM_RULES.md`](docs/CLEAN_ROOM_RULES.md) — reference/reuse boundaries.
- [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md) — engineering architecture.
- [`docs/reference/`](docs/reference/) — the frozen reference-app behavioral specification.
- [`prompts/milestones/`](prompts/milestones/) — the milestone plan this project is built from.

## Development setup

After cloning, generate the code this project depends on (localization, Drift, Freezed, Riverpod
providers) before running or analyzing:

```sh
flutter pub get
flutter gen-l10n
dart run build_runner build --delete-conflicting-outputs
```

Then, as usual:

```sh
flutter run                 # pick a connected device/emulator/Chrome
flutter analyze
flutter test
```

Generated sources (`*.g.dart`, `*.freezed.dart`, `lib/core/localization/generated/`) are not
committed — see `.gitignore` and `docs/ARCHITECTURE.md`'s testing/build notes.
