import '../models/quran_refs.dart';

/// Read access to the **immutable** canonical Quran dataset: chapters,
/// verses, and navigation units (Juz/Hizb/Rub/Manzil/page), independent of
/// script/Mushaf edition, translation, or tafsir.
///
/// This interface is deliberately small for Milestone 1 — the Quran Data
/// Engine milestone (2) defines the real entity models (mirroring
/// `docs/reference/06_DATA_MODEL_SPEC.md`) and a fuller repository surface
/// (Mushaf page/line lookups, search-adjacent metadata, etc.). What matters
/// now is the boundary: UI code depends on [QuranRepository], never on
/// Drift/SQL directly, and this repository must never expose a way to
/// mutate canonical text (see `docs/CLEAN_ROOM_RULES.md` §"Quran
/// correctness").
abstract class QuranRepository {
  Future<int> chapterCount();

  Future<int> verseCountForChapter(int chapterNo);

  Future<String> chapterName(int chapterNo, {required String languageCode});

  Future<bool> isVerseRangeValid(VerseRangeRef range);
}
