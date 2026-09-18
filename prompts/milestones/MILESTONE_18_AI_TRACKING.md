# Milestone 18 — AI Recitation Tracking Foundation

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

Add live Quran recitation position tracking.

Do **not** attempt full mistake detection or Tajweed yet.

## Recognition architecture

Use the replaceable interface created in Milestone 1.

Implement:

- audio capture abstraction;
- recognition session controller;
- Quran sequence matcher;
- alignment service;
- mock recognizer;
- real recognizer prototype/adapter.

The system should be structured as:

audio
→ acoustic/speech candidates
→ Quran-constrained matcher
→ Ayah/word position
→ application events

Do not architect this as generic unrestricted Arabic dictation only.

## Events

Support:

- started;
- Ayah candidate;
- Ayah detected;
- word position changed;
- confidence changed;
- paused/stopped;
- error.

## Context

Recognition should accept optional constraints:

- current Surah;
- expected range;
- memorization assignment.

This dramatically narrows the search space.

## UI

Create a distinctly Tahfeez recitation-practice experience:

- microphone/listening control;
- clear privacy state;
- live current Ayah;
- live current word;
- confidence/uncertain state;
- automatic reader following;
- stop/pause.

Use the Mushaf/reader word mapping from Milestone 7.

The AI visual language should follow `DESIGN_DIRECTION.md` and should not resemble generic audio waveform apps unnecessarily.

## Privacy

Do not persist raw microphone recordings by default.

Clearly document when audio leaves the device if a cloud recognizer is used.

## Mock implementation

The full UI and application event pipeline must be testable with a deterministic mock recognizer.

## Documentation

Create:

`docs/AI_RECOGNITION_ARCHITECTURE.md`

## Definition of Done

A mocked or prototype recognizer can drive live Ayah/word following without coupling UI to a specific AI provider.
