import 'package:freezed_annotation/freezed_annotation.dart';

part 'tafsir_models.freezed.dart';

/// The on-disk shape version [TafsirVerseText]/[TafsirWork] rows use —
/// distinct from a specific tafsir work's own [TafsirWork.version].
const supportedTafsirFormatVersion = 1;

/// Metadata for one downloadable tafsir work. [id] is a stable,
/// dataset-supplied identifier, never a local autoincrement value.
@freezed
abstract class TafsirWork with _$TafsirWork {
  const factory TafsirWork({
    required String id,
    required String displayName,
    required String languageCode,
    required String author,
    required int version,
    required String source,
    required String license,
    required String checksum,
    @Default(supportedTafsirFormatVersion) int formatVersion,
  }) = _TafsirWork;
}

/// One verse's tafsir commentary text for a specific tafsir [tafsirId],
/// joined against canonical ayah data by (chapterNo, verseNo) — never a
/// modification of canonical Quran text.
@freezed
abstract class TafsirVerseText with _$TafsirVerseText {
  const factory TafsirVerseText({
    required String tafsirId,
    required int chapterNo,
    required int verseNo,
    required String text,
  }) = _TafsirVerseText;
}
