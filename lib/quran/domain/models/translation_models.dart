import 'package:freezed_annotation/freezed_annotation.dart';

import 'quran_refs.dart';

part 'translation_models.freezed.dart';

/// The on-disk shape version [TranslationVerseText]/[TranslationBook] rows
/// use — distinct from a specific translation edition's own [TranslationBook.version].
/// A resource declaring a different value fails to install
/// (`ResourceFormatVersionException`) rather than being read incorrectly.
const supportedTranslationFormatVersion = 1;

/// Metadata for one downloadable translation edition — describable whether
/// or not it is actually installed locally. [slug] is a stable,
/// dataset-supplied identifier (e.g. `'en-hilali-khan'`), never a local
/// autoincrement value.
///
/// Per `docs/CLEAN_ROOM_RULES.md`'s resource-provenance rules, [source] and
/// [license] are mandatory metadata, not optional — a translation's
/// provenance must be knowable before it is ever installed.
@freezed
abstract class TranslationBook with _$TranslationBook {
  const factory TranslationBook({
    required String slug,
    required String displayName,
    required String languageCode,
    required String author,
    required int version,
    required String source,
    required String license,

    /// The checksum every installed verse's text must collectively hash to
    /// (`computeResourceChecksum`, `core/downloads/resource_integrity.dart`)
    /// — verified before install, never after.
    required String checksum,
    @Default(supportedTranslationFormatVersion) int formatVersion,
  }) = _TranslationBook;
}

/// One inline footnote referenced from [TranslationVerseText.text] by
/// [marker] (a 1-based marker number a caller renders as a superscript/
/// clickable span at the matching position in the translation body).
@freezed
abstract class TranslationFootnote with _$TranslationFootnote {
  const factory TranslationFootnote({
    required int marker,
    required String text,
  }) = _TranslationFootnote;
}

/// One verse's translated text for a specific [slug], joined against
/// canonical ayah data by (chapterNo, verseNo) — an overlay on top of
/// canonical verses, never a modification of canonical Quran text, per
/// `docs/CLEAN_ROOM_RULES.md`'s Quran-correctness rules.
///
/// [crossReferences] models the reference app's inline verse-reference
/// links (`docs/reference/13_TRANSLATION_TAFSIR_SPEC.md` §4) as plain
/// [VerseRef]s a reader can offer a "quick preview" for — independently
/// designed, not the reference app's exact link/markup format.
@freezed
abstract class TranslationVerseText with _$TranslationVerseText {
  const factory TranslationVerseText({
    required String slug,
    required int chapterNo,
    required int verseNo,
    required String text,
    @Default([]) List<TranslationFootnote> footnotes,
    @Default([]) List<VerseRef> crossReferences,
  }) = _TranslationVerseText;
}
