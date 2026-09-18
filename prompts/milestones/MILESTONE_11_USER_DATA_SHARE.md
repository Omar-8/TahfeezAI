# Milestone 11 — Bookmarks, Reading History, Sharing, Backup

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

Build Tahfeez's user-owned Quran data features.

## User database

Implement models for:

### Bookmark
- stable ID;
- Surah/chapter;
- start Ayah;
- end Ayah;
- optional note;
- created/updated timestamps.

### Reading history
- location type;
- reader mode;
- chapter/division;
- verse range;
- Mushaf/script;
- page;
- timestamp.

Keep schema independent from QuranApp.

## Bookmark UX

Support:

- single Ayah;
- range;
- add/edit note;
- open in reader;
- delete;
- multi-select;
- bulk delete;
- visible bookmark state in reader.

Create a polished Tahfeez bookmarks screen.

## Reading history

Support:

- continue reading;
- recent items;
- history list;
- remove item;
- clear history where appropriate;
- Home integration.

## Sharing

Build a Tahfeez share composer with options for:

- Arabic;
- one/multiple selected translations;
- Quran reference;
- range;
- footnotes if supported;
- bookmark note if user chooses.

Do not copy reference export/share wording.

## Backup/import

Define a versioned Tahfeez backup schema.

Support:

- bookmarks;
- settings;
- supported user state;
- import validation;
- merge/replace choices where appropriate.

Never silently overwrite user data.

Web:
- download/upload files.

Mobile:
- file picker/share sheet.

## Definition of Done

User data is local/offline, range bookmarks and notes work, backup format is versioned, and import failures cannot corrupt the current database.
