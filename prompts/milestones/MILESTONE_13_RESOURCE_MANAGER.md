# Milestone 13 — Offline Resource and Download Manager

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

Create one reliable resource system for all optional downloadable content.

## Resource types

Support:

- translation;
- tafsir;
- word-by-word;
- word audio;
- recitation;
- script/font;
- Mushaf atlas;
- reference collection;
- future AI model.

## State machine

Use a clear resource lifecycle such as:

- notInstalled;
- checking;
- queued;
- downloading(progress);
- extracting;
- verifying;
- installed;
- updateAvailable;
- failed.

## Manifest

Every resource should have versioned metadata:

- ID;
- type;
- name;
- version;
- format version;
- size;
- URL/source;
- checksum;
- source/license metadata.

## Download safety

Implement:

- cancel;
- retry;
- resumable behavior where feasible;
- free-space check;
- temporary staging;
- extraction;
- checksum verification;
- atomic activation;
- cleanup;
- previous-version safety where reasonable.

Never make a partially downloaded resource active.

## Storage UI

Build Tahfeez-owned screens for:

- available resources;
- installed resources;
- update available;
- storage usage;
- cleanup;
- active download progress.

Use Tahfeez resource components rather than copying reference rows.

## Platform storage

Native:
- app filesystem + database metadata.

Web:
- persistent browser storage abstraction;
- Drift/SQLite web persistence;
- appropriate Cache/OPFS/IndexedDB strategy.

Do not claim browser storage is guaranteed indefinitely.

## Offline invariant

Deleting all optional resources must not break core Quran reading.

## Definition of Done

All resource types use one coherent lifecycle, corruption is handled safely, cleanup works, and airplane-mode startup remains functional.
