# Milestone 20 — Parity Audit, Offline Audit, Hardening, Release

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

Prepare Tahfeez AI for production-quality release and measure feature parity honestly.

## Part A — Reference parity audit

Read:

`docs/reference/PARITY_CHECKLIST.md`

For every reference capability classify:

- DONE;
- PARTIAL;
- INTENTIONALLY DIFFERENT;
- NOT SUPPORTED;
- BUG.

Do not mark DONE without a test/manual verification path.

Visual differences are expected when they follow `DESIGN_DIRECTION.md`.

## Part B — Tahfeez product audit

Verify Tahfeez-specific features:

- Memorize destination;
- plans;
- hide/reveal;
- review scheduling;
- AI tracking;
- AI mistakes;
- coach/analytics.

## Part C — Offline audit

Disable networking and verify:

- app launches;
- Quran opens;
- verse reader works;
- Mushaf works;
- navigation works;
- search works;
- bookmarks/history work;
- installed translations work;
- installed tafsir works;
- installed WBW works;
- downloaded audio works;
- memorization works;
- local reminders work where supported.

## Part D — Performance

Profile:

- cold startup;
- DB initialization;
- search latency;
- long reader scrolling;
- Mushaf layout/render;
- page swiping;
- memory;
- audio transitions;
- download extraction;
- AI event UI performance.

Optimize real bottlenecks.

## Part E — Quran integrity

Add/verify:

- Surah count;
- Ayah counts;
- canonical data version/hash;
- page mappings;
- Mushaf line boundaries;
- word indexes;
- script relationships;
- resource checksums.

Fail safely if critical Quran data is corrupt.

## Part F — On-device AI evaluation

Evaluate current viable on-device recognition options.

Requirements:

- replaceable model;
- versioned downloadable model files if needed;
- checksum;
- Android/iOS support;
- Web fallback;
- CPU/RAM/battery measurement;
- privacy documentation.

Do not claim "offline AI" if accuracy is not acceptable.

A hybrid architecture is acceptable.

## Part G — License/resource audit

Audit every:

- dependency;
- Quran dataset;
- translation;
- tafsir;
- font;
- audio source;
- word-by-word dataset;
- AI model;
- icon set;
- illustration.

Generate appropriate third-party notices from the verified register.

## Part H — Visual consistency audit

Review all major screens in:

- Tahfeez light;
- Tahfeez dark;
- Arabic RTL;
- English LTR;
- phone;
- tablet;
- desktop.

Look for:

- accidental QuranApp imitation beyond the intended inspiration level;
- inconsistent old/default Flutter widgets;
- arbitrary colors/spacing;
- cramped screens;
- poor light mode;
- poor contrast;
- unstyled error/offline states.

Refine toward Tahfeez identity.

## Part I — Release

Prepare:

- Android release;
- iOS release;
- Web/PWA release.

Preserve:

- no mandatory account;
- no ads by default;
- no tracking by default;
- offline-first Quran experience.

Create:

`docs/RELEASE_READINESS.md`

## Definition of Done

Tahfeez is stable, license/resource provenance is documented, offline behavior is verified, feature gaps are transparent, and the visual product feels cohesive and independently branded.
