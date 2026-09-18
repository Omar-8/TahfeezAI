import '../../../quran/domain/models/quran_refs.dart';

/// A bookmarked verse or verse range, with an optional note.
///
/// Mirrors the shape validated in
/// `docs/reference/06_DATA_MODEL_SPEC.md` §3 (a single verse is
/// `range.fromVerseNo == range.toVerseNo`; a distinct range is not — one
/// shape covers both, matching the reference app's own schema decision).
class Bookmark {
  const Bookmark({
    required this.id,
    required this.range,
    this.note,
    required this.createdAt,
  });

  final int id;
  final VerseRangeRef range;
  final String? note;
  final DateTime createdAt;
}

/// Read/write access to the **mutable** user data domain: bookmarks and
/// reading history.
///
/// Deliberately kept separate from [QuranRepository] both here and at the
/// storage layer (a dedicated user database, introduced by the User Data &
/// Sharing milestone, 11) — this is the immutable/mutable split validated
/// against the reference app in `docs/reference/06_DATA_MODEL_SPEC.md` §1,
/// and it is a Tahfeez architectural requirement per `CLAUDE.md`, not just
/// an observation about the reference app.
abstract class UserDataRepository {
  Stream<List<Bookmark>> watchBookmarks();

  Future<void> addBookmark(VerseRangeRef range, {String? note});

  Future<void> removeBookmark(int bookmarkId);

  Future<void> recordReadPosition(VerseRef position);
}
