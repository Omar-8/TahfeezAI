/// How the reader presents Quran content.
///
/// Mirrors `docs/reference/04_READER_SPEC.md` §2's three-mode concept
/// (independently named/modeled, not copied), so the reader's chrome and
/// persisted preference are already shaped for [mushaf]/[translation] once
/// their milestones (7, 9) land — only [verseByVerse] is implemented today.
enum ReaderMode { verseByVerse, mushaf, translation }
