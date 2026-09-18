import '../../../quran/domain/models/quran_refs.dart';

/// Read/write access to Tahfeez's core differentiator: memorization plans,
/// review scheduling, and per-range memorization strength.
///
/// There is no reference behavior to study for this domain — per
/// `docs/reference/01_FEATURE_MATRIX.md`'s "Memorize / AI — not present in
/// reference" section, this is entirely Tahfeez-original and will be
/// designed from `docs/DESIGN_DIRECTION.md`'s memorization visual-language
/// guidance when the Memorization milestone (17) is implemented. This
/// interface exists now purely so `lib/memorization/` has an established
/// domain boundary from the very first milestone, matching
/// `docs/PROJECT_BRIEF.md`'s framing of memorization as a first-class
/// product area rather than a bolt-on.
abstract class MemorizationRepository {
  Stream<double> watchMemorizationStrength(VerseRangeRef range);

  Future<void> markReviewed(VerseRangeRef range, {required bool successful});

  Future<List<VerseRangeRef>> dueForReviewToday();
}
