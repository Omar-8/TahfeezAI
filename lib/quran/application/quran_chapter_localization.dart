import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../domain/models/surah_models.dart';
import '../quran_providers.dart';

part 'quran_chapter_localization.g.dart';

/// One chapter's localized name/meaning for one language — a thin,
/// per-chapter lookup used wherever a screen needs to show a chapter's
/// name for a small, fixed number of chapters (a reading session's
/// chapter-info card, a chapter-boundary header, a Mushaf page's
/// chapter-name line), as opposed to
/// `lib/features/quran/application/quran_index_providers.dart`'s
/// `indexedSurahsProvider`, which needs every chapter's name at once and
/// batches accordingly.
///
/// Shared under `quran/application` (not one feature's `application/`
/// folder) because the Reader (Milestone 6) and Mushaf renderer (Milestone
/// 7) both need the identical lookup — the same
/// "shared-by-more-than-one-feature belongs in `quran/application`"
/// pattern `docs/ARCHITECTURE.md` already established for
/// `hasInstalledQuranDataset`, `RecentQuranLocationController`, and
/// `quranScriptCodeProvider`.
@riverpod
Future<SurahLocalization?> chapterLocalization(
  Ref ref,
  int surahNo, {
  required String languageCode,
}) {
  final repository = ref.watch(quranRepositoryProvider);
  return repository.getSurahLocalization(surahNo, languageCode: languageCode);
}
