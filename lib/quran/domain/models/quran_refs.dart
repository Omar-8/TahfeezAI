/// Small, shared reference value types used across the read-domain
/// repository interfaces.
///
/// These are intentionally lightweight records, not full domain models —
/// the real `Chapter`/`Verse`/`Mushaf` entities (mirroring the schema
/// validated in `docs/reference/06_DATA_MODEL_SPEC.md`) are defined by the
/// Quran Data Engine milestone (Milestone 2). Records are used here (rather
/// than classes or `freezed` models) because they are pure value
/// identifiers with structural equality built in, and are cheap to change
/// once real models exist.
library;

/// A single verse, identified by chapter and verse number (both 1-based, as
/// used throughout the Quran domain and the reference app).
typedef VerseRef = ({int chapterNo, int verseNo});

/// An inclusive verse range within one chapter.
typedef VerseRangeRef = ({int chapterNo, int fromVerseNo, int toVerseNo});
