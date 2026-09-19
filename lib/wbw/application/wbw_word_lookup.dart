import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../domain/models/wbw_models.dart';
import '../wbw_providers.dart';

part 'wbw_word_lookup.g.dart';

/// One word's translation/transliteration from [packId] — a `family`
/// provider (one per distinct (pack, ayah, word) triple) so the word detail
/// sheet's lookup is a single, cheap, cache-friendly read rather than
/// re-fetching a whole pack's data just to show one word.
@riverpod
Future<WbwWordEntry?> wbwWordLookup(
  Ref ref, {
  required String packId,
  required int ayahId,
  required int wordIndex,
}) {
  return ref
      .watch(wbwRepositoryProvider)
      .getWord(packId: packId, ayahId: ayahId, wordIndex: wordIndex);
}
