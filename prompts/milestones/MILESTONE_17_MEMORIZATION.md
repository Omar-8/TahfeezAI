# Milestone 17 — Offline Memorization Engine

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

Make Tahfeez meaningfully different from a generic Quran reader by adding a full memorization system without requiring AI.

## Primary navigation evolution

Now that memorization exists, reassess primary navigation.

Preferred target:

- Home
- Quran
- Memorize
- Search

Use adaptive navigation for larger screens.

Do not retain the earlier navigation solely because the reference app used it.

## Domain models

Implement:

- MemorizationPlan;
- MemorizationAssignment;
- MemorizedRange;
- ReviewSchedule;
- MemorizationSession;
- AyahMemoryState;
- WordMemoryState;
- PracticeAttempt.

## Practice modes

Support:

1. Read;
2. Listen & Repeat;
3. Hide & Recall;
4. Verse Test;
5. Review;
6. continuous-recitation preparation.

## Features

Allow:

- select range;
- create daily target;
- repeat Ayah N times;
- repeat range;
- progressively hide;
- hide all;
- tap to reveal;
- first-word hint;
- next-word hint;
- combine adjacent Ayahs;
- rate easy/medium/hard;
- record confidence;
- record attempts;
- schedule review.

## Spaced repetition

Implement a documented local heuristic.

Do not market the heuristic as a religious correctness score.

## Mushaf integration

Use the **same** Quran/Mushaf renderer.

Add non-destructive visual overlay states for:

- visible;
- dimmed;
- hidden;
- revealed;
- current;
- weak.

Never alter stored Quran text to hide/reveal it.

## Home evolution

Introduce Tahfeez-owned cards such as:

- Today's Memorization;
- Today's Revision;
- progress summary.

This should make the Home substantially more distinct from QuranApp.

## Audio

Reuse the AudioController for repetitions.

## Offline

The complete memorization system must work offline.

## Definition of Done

A user can create a Hifz plan, practice, hide/reveal, repeat audio, track attempts, and receive locally scheduled revision without AI or network.
