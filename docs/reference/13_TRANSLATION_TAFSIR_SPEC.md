# 13 — Translation & Tafsir Specification (Reference Behavior)

> Source: `com.quranapp.android.utils.reader.factory.QuranTranslationFactory`,
> `com.quranapp.android.utils.reader.translation.*`, `com.quranapp.android.utils.reader.tafsir.
TafsirManager`, `com.quranapp.android.db.translation.*`, `com.quranapp.android.db.tafsir.*`,
> `com.quranapp.android.compose.screens.tafsir.TafsirReaderScreen`, `api.models.translation.*`,
> `api.models.tafsir.*`.

## 1. Storage model (distinct from Room)

Unlike the canonical Quran/User/Topics/SearchIndex/ExternalQuran data (all Room, see
`docs/reference/06_DATA_MODEL_SPEC.md`), **installed translations and tafsirs are stored via a
plain `SQLiteOpenHelper`-based helper** (`QuranTranslDBHelper`, `QuranTafsirDbHelper`), where
**each installed translation/tafsir gets its own dynamically-created SQLite table** named after
its slug (e.g., a table literally named `en_hilali-khan`), with a shared `*_info` table
(`QuranTranslInfoEntry`/`QuranTafsirInfoContract`) recording which slugs are installed and their
metadata (display name, author, language, version). This is a deliberate pattern choice for
resources whose *set* changes at runtime (translations/tafsirs are added and removed one at a
time by the user) that Room's compile-time-fixed entity list cannot easily express — dropping a
table (`DROP TABLE IF EXISTS '$slug'`) is how uninstalling a translation reclaims its storage.
This is a valid architectural precedent, but Tahfeez (using Drift) should evaluate whether an
equivalent dynamic-table approach or a single normalized `(book_slug, chapter_no, verse_no, text)`
table with an index is the better fit for Drift's migration model — the reference app's choice
here is not a mandate to replicate literally, just documented context.

## 2. Translation factory responsibilities

`QuranTranslationFactory` (per-request instance, backed by a process-wide shared DB helper):
- `isTranslationDownloaded(slug)` — checks table existence via `sqlite_master`.
- `deleteTranslation(slug)` — drops the table and its info row in one transaction.
- Reads translation text + footnotes for a chapter (`COL_TEXT`, `COL_FOOTNOTES` columns, footnotes
  stored as a JSON array string per verse, parsed into `Footnote` objects on read).
- Exposes `TranslationBookInfoModel` (display name, author, language, `isUrdu` flag used for
  font-family selection — see `docs/reference/04_READER_SPEC.md` §14) for chip/label rendering
  without loading full verse content.
- Multiple translations can be simultaneously active; the reader stacks each selected
  translation's text under the Arabic verse in the order they were selected
  (`docs/reference/04_READER_SPEC.md` §5), each ending in its own translator attribution line.

## 3. Translation versioning and download

- `TranslationVersionManager`/`Store` — same reconcile-against-remote-manifest pattern as
  Recitations (`docs/reference/09_OFFLINE_RESOURCES_SPEC.md` §2); outdated installed translations
  surface via Home's resource-update banner and the Translations download screen.
- `TranslationDownloadScreen` — browse translations grouped by language, download individually.
- `TranslationSelectionScreen` — multi-select which of the *installed* translations are active in
  the reader right now (distinct from "installed" — a translation can be downloaded but
  deselected).
- Once downloaded, a translation's search text is separately indexed into `SearchIndexDatabase`
  by `TranslationSearchIndexWorker` (`docs/reference/07_SEARCH_SPEC.md` §8) — this indexing is a
  second, independent background step after download, not part of the download itself.

## 4. Footnotes and verse references

Translation text can contain inline footnote markers and inline verse-reference links, both
rendered as clickable spans inside the `AnnotatedString` translation body
(`docs/reference/04_READER_SPEC.md` §14): footnote markers open `FootnotePresenter`; verse
references open `QuickReference` (a lightweight in-place preview) rather than fully navigating
away, preserving reading flow.

## 5. Tafsir

- `TafsirManager` fetches an available-tafsirs manifest (via Retrofit from the project's own API,
  cached to a local manifest file) and exposes `AvailableTafsirsModel`/`TafsirInfoModel`
  (per-tafsir id, display name, author, language, version).
- `TafsirSelectionScreen` — picks the single active tafsir (subtitle in main Settings shows one
  name, implying single-select unlike translations' multi-select — `NEEDS_VERIFICATION` on
  whether this is a hard single-select constraint or just the common case).
- **Reading tafsir is a separate, dedicated screen** (`ActivityTafsir`, `singleTask`,
  `TafsirReaderScreen`), not inline in the main reader — reached via the verse action bar's
  Tafsir icon (`docs/reference/04_READER_SPEC.md` §5) or the `com.quranapp.android.action.
OPEN_TAFSIR` intent action, and scoped to a specific chapter+verse on entry (presumably navigable
  to adjacent verses within the tafsir screen itself — `NEEDS_VERIFICATION`).
- `TafsirDownloadWorker` handles background download of tafsir content, matching the same
  versioned-resource pattern as translations/recitations.
- Tafsir storage: `QuranTafsirDbHelper`/`QuranTafsirContract`/`QuranTafsirInfoContract` mirror the
  translation storage pattern (per-tafsir dynamic table + shared info table).

## 6. Loading / empty / error / offline states

- **Loading**: download-browse screens show per-item progress; tafsir/translation reader screens
  show a loader while fetching the requested chapter/verse's stored text.
- **Empty**: a reader session with zero translations selected simply omits the translation stack
  entirely (not an "empty state" message — it's a valid, common configuration for
  Arabic-only reading, consistent with the Arabic-text-toggle setting in
  `docs/reference/10_SETTINGS_SPEC.md` §2 existing as its own control).
- **Error**: a requested chapter/verse with no stored text for the active translation/tafsir
  (e.g., mid-download, or a corrupted table) — exact fallback UI `NEEDS_VERIFICATION`.
- **Offline**: fully offline once a translation/tafsir table exists locally; only the manifest
  fetch and the download itself require network.

## 7. NEEDS_VERIFICATION

- Whether tafsir supports multi-select like translations, or is strictly single-active.
- Exact behavior of `TafsirReaderScreen`'s in-screen navigation (adjacent-verse stepping, chapter
  switch).
- Exact footnote JSON schema.
- Whether translation `downloadPath` values point at a per-app-managed CDN or a general public
  dataset mirror — relevant to Tahfeez's own translation-sourcing decision, and to
  `docs/THIRD_PARTY_RESOURCES.md` provenance verification once Tahfeez selects specific
  translation/tafsir sources.
