# Milestone 12 — Recitation and Audio Player

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

Implement Tahfeez's shared Quran recitation engine.

## Architecture

Use a single application-level `AudioController`.

UI must not depend directly on `just_audio`.

Use `audio_service` for mobile background/system integration where supported.

## Playback state

Model at least:

- current Surah/Ayah;
- resolving/loading;
- download progress;
- playing;
- paused;
- buffering;
- verse sync available;
- current reciter;
- translation reciter;
- speed;
- repeat;
- audio mode;
- end behavior.

## Audio modes

Support:

1. Quran only;
2. Translation only;
3. Quran + Translation.

When both are selected, support configurable verse grouping such as:

- 1
- 2
- 3
- 5
- 10

where the resource structure permits it.

## Controls

Support:

- reciter selection;
- translation reciter;
- play/pause;
- next/previous Ayah;
- seek where meaningful;
- speed;
- repeat count;
- end behavior;
- offline source selection;
- download.

## Reader integration

Implement:

- current Ayah highlighting;
- optional current word hooks if timing exists;
- auto-scroll;
- mini player;
- expanded player;
- Spotlight-like focus mode as a Tahfeez-owned design.

## Tahfeez visual direction

This is a major UI milestone.

Create:

- elegant low-profile mini player;
- polished expanded player;
- light/dark consistency;
- large touch controls;
- readable reciter/settings state;
- quiet integration with Quran reading.

Do not recreate the reference player's exact layout.

## Offline

Explicitly downloaded local audio should take precedence.

If offline and audio is unavailable, display a clear unavailable/download-required state.

## Web

Support browser-compatible playback while gracefully handling browser limitations for background/system controls.

## Definition of Done

Playback survives normal navigation, reader synchronization works, downloaded audio works offline, and both mini/expanded players feel native to Tahfeez.
