import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../domain/models/tafsir_models.dart';
import '../tafsir_providers.dart';

part 'tafsir_verse_text.g.dart';

/// One verse's commentary for the active tafsir — a single-lookup provider,
/// appropriate because the Tafsir reader screen shows exactly one verse at
/// a time (`docs/reference/13_TRANSLATION_TAFSIR_SPEC.md` §5's "separate,
/// dedicated screen ... scoped to a specific chapter+verse"), unlike the
/// verse-by-verse reader's batched-by-range translation loading.
@riverpod
Future<TafsirVerseText?> tafsirVerseText(
  Ref ref, {
  required int chapterNo,
  required int verseNo,
  required String tafsirId,
}) {
  return ref.watch(tafsirRepositoryProvider).getVerseText((
    chapterNo: chapterNo,
    verseNo: verseNo,
  ), tafsirId: tafsirId);
}
