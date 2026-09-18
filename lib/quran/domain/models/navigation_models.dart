import 'package:freezed_annotation/freezed_annotation.dart';

part 'navigation_models.freezed.dart';

/// The four traditional ways the Quran is divided for reading/memorization
/// plans, beyond chapters: 30 Juz, 60 Hizb (two per Juz), 240 Rub (quarter-
/// Hizb), and 7 Manzil.
enum NavigationUnitType { juz, hizb, rub, manzil }

/// One contiguous segment of a navigation unit *within a single chapter*.
///
/// A navigation unit (e.g. Juz 1) commonly spans more than one chapter, so
/// it is represented as one row per chapter it touches rather than a single
/// [startAyahNo]/[endAyahNo] pair — mirroring the structural reality
/// validated in `docs/reference/06_DATA_MODEL_SPEC.md` §2, independently
/// modeled here (own field names, own aggregate types — see [Juz]/[Hizb]
/// below).
@freezed
abstract class NavigationRange with _$NavigationRange {
  const factory NavigationRange({
    required NavigationUnitType type,
    required int unitNo,
    required int surahNo,
    required int startAyahNo,
    required int endAyahNo,
  }) = _NavigationRange;
}

/// One Juz, aggregating every chapter segment it spans — the convenience
/// shape callers actually want, built from one or more [NavigationRange]
/// rows of type [NavigationUnitType.juz].
@freezed
abstract class Juz with _$Juz {
  const factory Juz({
    required int juzNo,
    required List<NavigationRange> ranges,
  }) = _Juz;
}

/// One Hizb, aggregating every chapter segment it spans. Analogous to [Juz]
/// but for [NavigationUnitType.hizb] ranges.
@freezed
abstract class Hizb with _$Hizb {
  const factory Hizb({
    required int hizbNo,
    required List<NavigationRange> ranges,
  }) = _Hizb;
}
