import 'package:freezed_annotation/freezed_annotation.dart';

part 'script_models.freezed.dart';

/// A Quran script family (e.g. an Uthmani-style script, an Indopak-style
/// script). Kept separate from [QuranScriptVariant] — rather than the
/// single self-referencing table the reference app uses internally (see
/// `docs/reference/05_MUSHAF_SPEC.md` §7) — because "family" and "variant"
/// are genuinely different concepts for callers: a script always exists,
/// a variant is optional refinement of one.
@freezed
abstract class QuranScript with _$QuranScript {
  const factory QuranScript({
    required int id,
    required String code,
    required String displayName,
  }) = _QuranScript;
}

/// A specific edition/version of a [QuranScript] family (e.g. two
/// typesetting revisions of the same script). Not every script has
/// variants; a [Mushaf] may reference a script directly with no variant.
@freezed
abstract class QuranScriptVariant with _$QuranScriptVariant {
  const factory QuranScriptVariant({
    required int id,
    required int scriptId,
    required String code,
    required String displayName,
  }) = _QuranScriptVariant;
}
