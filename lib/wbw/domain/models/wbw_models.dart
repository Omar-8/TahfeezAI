import 'package:freezed_annotation/freezed_annotation.dart';

part 'wbw_models.freezed.dart';

/// Metadata for one downloadable word-by-word "language pack" — describable
/// whether or not it is actually installed locally. [id] is a stable,
/// dataset-supplied identifier (e.g. `'en-clearquran'`), never a local
/// autoincrement value, so the same pack id means the same thing before and
/// after installation.
///
/// Per `docs/CLEAN_ROOM_RULES.md`'s resource-provenance rules, [source] and
/// [license] are mandatory, not optional metadata — a pack's provenance must
/// be knowable before it is ever installed, and must be recorded in
/// `docs/THIRD_PARTY_RESOURCES.md` before any real (non-synthetic) pack
/// ships.
@freezed
abstract class WbwLanguagePack with _$WbwLanguagePack {
  const factory WbwLanguagePack({
    required String id,
    required String languageCode,
    required String displayName,
    required int version,
    required String checksum,
    required String source,
    required String license,
    required bool hasTranslation,
    required bool hasTransliteration,
  }) = _WbwLanguagePack;
}

/// One word's translation/transliteration for a specific [packId], joined
/// against canonical `AyahWord` by (ayahId, wordIndex) — an overlay on top
/// of canonical word indices, never a modification of canonical text, per
/// `docs/reference/14_WORD_BY_WORD_SPEC.md` §1 and
/// `docs/CLEAN_ROOM_RULES.md`'s Quran-correctness rules. Either field may be
/// absent independent of the other — a pack can offer only translation, only
/// transliteration, or both (see [WbwLanguagePack.hasTranslation]/
/// [WbwLanguagePack.hasTransliteration]).
@freezed
abstract class WbwWordEntry with _$WbwWordEntry {
  const factory WbwWordEntry({
    required String packId,
    required int ayahId,
    required int wordIndex,
    String? translation,
    String? transliteration,
  }) = _WbwWordEntry;
}
