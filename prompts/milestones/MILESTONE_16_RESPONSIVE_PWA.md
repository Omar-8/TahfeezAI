# Milestone 16 — Responsive Tablet/Desktop/Web and PWA

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

Make Tahfeez excellent on large screens and installable/offline-capable on the Web.

## Do not stretch mobile

Phone:
- compact primary navigation;
- one-page Mushaf;
- sheets.

Tablet:
- adaptive navigation rail;
- richer grid;
- optional two-page Mushaf;
- side-by-side contextual content where helpful.

Desktop/Web:
- adaptive navigation;
- constrained reading width;
- optional side panel for tafsir/translation/notes/player;
- one/two-page Mushaf based on viewport;
- keyboard-friendly interactions.

## Tahfeez desktop identity

Do not create a literal Android tablet clone.

Use editorial spacing and a calmer Quran reading layout.

## PWA

Implement:

- installable manifest;
- application-shell caching;
- installed Quran core available offline;
- fonts cached appropriately;
- persistent local DB;
- resource persistence where browser allows;
- useful offline-state handling.

Request persistent browser storage where appropriate.

Never promise that browser-managed storage can never be evicted.

## Keyboard

Add useful keyboard support such as:

- arrows/page movement;
- search shortcut;
- escape closes overlays;
- focus management.

## Testing

Test representative viewports:

- small mobile;
- large mobile;
- tablet portrait;
- tablet landscape;
- laptop;
- desktop.

Test English and Arabic.

Test offline restart of installed PWA.

## Definition of Done

Tahfeez feels intentionally designed on each form factor and remains useful offline on Web within browser-platform constraints.
