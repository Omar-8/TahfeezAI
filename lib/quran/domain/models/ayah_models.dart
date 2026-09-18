import 'package:freezed_annotation/freezed_annotation.dart';

part 'ayah_models.freezed.dart';

/// Whether a verse requires a prostration (Sajdah) when recited, and of
/// which kind. `null` on [Ayah.sajdah] means the verse has no Sajdah at all
/// — this is a nicer domain type than a raw nullable/defaulted integer flag.
enum SajdahType { recommended, obligatory }

/// A single verse (Ayah), identified by its stable [id] as well as its
/// human-facing (chapter, verse) position, carrying the structural metadata
/// (Juz/Hizb/Rub/Manzil/Ruku membership) needed for navigation without a
/// join. Canonical Arabic text is intentionally **not** stored here — it
/// lives in [AyahWord], scoped per [QuranScript], because the same verse's
/// word-level text differs by script.
@freezed
abstract class Ayah with _$Ayah {
  const factory Ayah({
    /// A stable identifier for this verse, independent of any script. By
    /// convention `id == chapterNo * 1000 + verseNo` (chapters never exceed
    /// 286 verses, so this never collides) — a plain, deterministic
    /// numbering scheme, not a reference-app implementation detail.
    required int id,
    required int chapterNo,
    required int verseNo,
    required int juzNo,
    required int hizbNo,
    required int rubNo,
    required int manzilNo,
    required int rukuNo,
    SajdahType? sajdah,
  }) = _Ayah;
}

/// One word of one verse's canonical text, in one [QuranScript]. Word order
/// within a verse is [wordIndex] (0-based, contiguous — see
/// `dataset_integrity.dart`'s "ordered words" check).
@freezed
abstract class AyahWord with _$AyahWord {
  const factory AyahWord({
    required int ayahId,
    required int scriptId,
    required int wordIndex,
    required String text,
  }) = _AyahWord;
}

/// A verse together with its words in one script — the shape reader UI
/// actually needs, returned by [QuranRepository]'s batch-loading methods so
/// callers never have to stitch verses and words together themselves.
@freezed
abstract class AyahWithWords with _$AyahWithWords {
  const factory AyahWithWords({
    required Ayah ayah,
    required List<AyahWord> words,
  }) = _AyahWithWords;
}
