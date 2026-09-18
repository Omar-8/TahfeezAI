# 12 — Bookmarks & Reading History Specification (Reference Behavior)

> Source: `com.quranapp.android.compose.screens.{BookmarksScreen,ReadHistoryScreen,
ExportImportScreen}`, `com.quranapp.android.viewModels.{BookmarksViewModel,ReadHistoryViewModel}`,
> `com.quranapp.android.db.entities.user.*`, `com.quranapp.android.db.bookmark.*`.

## 1. Data shape (cross-reference)

See `docs/reference/06_DATA_MODEL_SPEC.md` §3 for the full `BookmarkEntity`/`ReadHistoryEntity`
schema. Key facts repeated here for convenience: a bookmark's `fromVerseNo == toVerseNo` for a
single-verse bookmark and differs for a range bookmark (same table, no separate "type" column);
bookmarks carry an optional free-text `note`; read-history rows carry enough context (read type,
reader mode, division number, chapter/verse range, Mushaf code/variant/page) to restore the exact
prior reading position, not just "you were in Chapter 2."

## 2. Bookmarks screen (`ActivityBookmark`)

- Flat list (not grouped by chapter) of all bookmarks, each row presumably showing chapter/verse
  reference, a note preview if present, and the bookmark date (`NEEDS_VERIFICATION` on exact row
  content beyond what's inferable from `BookmarksViewModel`'s `uiState.bookmarks`).
- **Selection mode**: long-press (or similar) enters multi-select (`combinedClickable`); a
  system-back-press while selecting clears the selection instead of leaving the screen
  (`BackHandler(enabled = selecting)`).
- **Delete actions**: delete-single (per-row), delete-selected (bulk, from multi-select), and
  delete-all, each routed through one confirmation dialog (`BookmarkDeleteDialog`) parameterized
  by a `BookmarkDeleteTarget` (`All` / `Single(id)` / `Selected(ids)`) — i.e., one shared
  confirmation UI for all three delete scopes rather than three separate dialogs.
- **Viewing/editing a bookmark**: tapping a bookmark (outside selection mode) opens
  `BookmarkViewerSheet` — a bottom sheet showing the full verse text and the note, with edit/
  delete actions, reused both here and from within the reader itself
  (`docs/reference/04_READER_SPEC.md` §10).
- **Empty state**: `MessageCard` composable is imported and available for use; exact empty-state
  copy/illustration is `NEEDS_VERIFICATION`.
- **Loading state**: `Loader` composable available for the initial bookmark-list load.

## 3. Read History screen (`ActivityReadHistory`)

- Reached from Home's "View all" on the Read History section (`docs/reference/11_HOME_SPEC.md`
  §4) as well as directly.
- Presumably a chronological list grouped or sorted by `datetime` descending; each entry opens the
  reader at the exact stored position via `ReaderFactory.prepareHistoryIntent`
  (`docs/reference/04_READER_SPEC.md` §18). Exact grouping (by day, ungrouped, etc.) and whether
  individual history entries can be deleted (vs. only bulk-cleared) is `NEEDS_VERIFICATION` — not
  confirmed from the files inspected, though the underlying DAO almost certainly supports
  per-row deletion given the entity's own auto-increment `id`.
- Read history entries accumulate automatically as the user reads (written by the reader
  ViewModel on navigation/session events), not via any explicit user action — this is passive,
  always-on tracking, consistent with an offline-first, no-account app (the data never leaves the
  device).

## 4. Export / Import

`ActivityExportImport` (`ExportImportScreen`) offers three independently-selectable export/import
scopes (`ExportKeys`), each as its own card with its own confirmation copy:

1. **Everything** — Settings + Bookmarks together.
2. **Settings only**.
3. **Bookmarks only**.

**Read history is explicitly excluded from export/import** — only settings and bookmarks are
portable. This is a meaningful product decision: history is treated as ephemeral/device-local
telemetry-adjacent data, while bookmarks (deliberate user curation) and settings (configuration)
are treated as data worth carrying to a new device or backing up. Tahfeez's own Import/Export
milestone should make (and document) an equally explicit decision here rather than silently
including or excluding history.

Import shows a warning message (`warnImportSettings`) — implying import can be destructive
(overwrite vs. merge behavior is `NEEDS_VERIFICATION`, but a warning being shown at all suggests
overwrite-like semantics for at least the Settings scope).

## 5. Legacy migration (historical context only)

`UserDataMigrationManager` + `ReadHistoryMigration` perform a one-time migration from a pre-Room
`SQLiteOpenHelper`-based bookmark store into the current Room `UserDatabase`, gated by
`SharedPreferences` flags so it runs at most once per install. This is purely a reference-app
implementation-history detail; Tahfeez has no legacy store to migrate from and does not need an
equivalent mechanism, but should still design its own user-data schema with an eye toward *future*
migrations (Drift's built-in migration support), since the reference app's own history shows this
concern is realistic over an app's lifetime.

## 6. Sharing

Bookmarked/read verses can be shared via the same verse-share mechanism as any other verse in the
reader (`docs/reference/04_READER_SPEC.md` §9); there is no bookmark-specific share format beyond
sharing the underlying verse(s).

## 7. Loading / empty / error / offline states

- **Loading**: initial list load shows `Loader`.
- **Empty**: Bookmarks — `NEEDS_VERIFICATION` on exact copy; likely an illustration + "no
  bookmarks yet" message consistent with the Home read-history empty state's tone
  (`docs/reference/11_HOME_SPEC.md` §4).
- **Error**: not applicable beyond generic local-database failure (no network dependency for
  reading/writing bookmarks or history).
- **Offline**: fully offline; bookmarks, history, and export/import all operate on local SQLite
  and the local filesystem (for export files) with no network dependency at all.

## 8. NEEDS_VERIFICATION summary

- Exact bookmark list row content/sort order.
- Whether read-history supports per-item delete from its own screen.
- Export file format (JSON structure) and whether import merges or replaces existing data.
- Exact bookmarks/read-history empty-state presentation.
