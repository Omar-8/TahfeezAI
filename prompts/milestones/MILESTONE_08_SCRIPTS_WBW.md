# Milestone 8 — Quran Scripts and Word-by-Word

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

Support multiple Quran script families/variants and a complete word-by-word resource layer.

## Scripts

Design `QuranScript` and `QuranScriptVariant` abstractions.

Architecture should accommodate:

- Uthmani;
- IndoPak;
- KFQPC-style/page-font approaches;
- future atlas-based scripts.

Do not assume every script has:

- identical word strings;
- identical page mappings;
- identical page count;
- identical line count.

Script selection may change:

- source words;
- Mushaf;
- font;
- line map;
- renderer;
- downloadable resources.

## Word-by-word

Create versioned downloadable WBW resources.

Data should support:

- language;
- word translation;
- optional transliteration;
- version;
- checksum;
- source/license metadata.

Preferences:

- selected language;
- show translation;
- show transliteration;
- tooltip translation;
- tooltip transliteration;
- word audio enabled.

## Reader interaction

Tap a Quran word to open a Tahfeez-owned word detail sheet.

It may show:

- Arabic word;
- translation;
- transliteration;
- play word audio;
- location context.

## Resource states

Support:

- not installed;
- queued;
- downloading with progress;
- installed;
- update available;
- failed;
- deleting.

Installed WBW must remain usable offline.

## Styling

Do not duplicate the reference settings/resource rows exactly.

Use Tahfeez resource-row and bottom-sheet components.

## Definition of Done

Scripts are swappable without UI rewrites, WBW is versioned/downloadable/offline, and word hit testing connects correctly from both reader modes.
