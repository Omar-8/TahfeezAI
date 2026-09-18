# Milestone 19 — Mistake Detection and Adaptive Tahfeez Coach

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

Add constrained word-level memorization feedback and adaptive review planning.

This is not Tajweed scoring.

## Expected-range alignment

When the user practices a selected range, compare recognized sequence events with the known expected Quran sequence.

Detect:

- CORRECT;
- SKIPPED;
- INCORRECT/SUBSTITUTED;
- ADDED;
- HESITATION;
- SELF_CORRECTED.

Every event should map to exact:

- Surah;
- Ayah;
- word index;
- practice session.

## UI feedback

Design non-destructive Quran overlays for:

- current word;
- correct progress;
- skipped word;
- incorrect word;
- hesitation;
- self-correction.

Do not alter Quran characters.

Avoid excessive red/green visual noise. The Quran should remain readable and dignified.

## Session records

Persist:

- range;
- duration;
- attempts;
- prompts;
- mistakes;
- self corrections;
- hesitation count;
- completion;
- recognizer/model version.

## Memory strength

Build a documented `MemoryStrengthEngine`.

Consider signals such as:

- recall success;
- mistakes;
- hints;
- hesitation;
- self corrections;
- elapsed time;
- previous review interval.

Treat the score as a learning heuristic, not as a declaration of religious correctness.

## Coach

Generate local review recommendations such as:

- weak ranges;
- frequently missed words;
- long-unreviewed ranges;
- scheduled revision;
- recent low-confidence sessions.

The first coach version can be deterministic and local; it does not require a general-purpose LLM.

## Analytics UI

Build Tahfeez-owned analytics:

- Surah/range progress;
- due reviews;
- weak Ayahs;
- recurring word mistakes;
- history.

Make this visually distinct and modern rather than copying any Tarteel/QuranApp screen.

## Testing

Use deterministic simulated recognition streams to verify alignment and scoring.

## Definition of Done

Mistake events are reproducible/tested, analytics update correctly, and Tahfeez can recommend revision based on local learning history.
