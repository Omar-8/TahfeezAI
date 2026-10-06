import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../ai/matching/local_quran_position_tracker.dart';
import '../../../ai/matching/quran_phoneme_index.dart';
import 'acoustic_verification_controller.dart'
    show quranPhoneticReferenceProvider;
import 'quran_match_controller.dart' show quranWordCorpusProvider;

/// The expected pronunciation and the whole-Quran phoneme index the
/// on-device position tracker locates the reciter with (built once, in
/// the background).
final quranPhonemeResourcesProvider = FutureProvider<PhonemeResources>((
  ref,
) async {
  final reference = await ref.watch(quranPhoneticReferenceProvider.future);
  final corpus = await ref.watch(quranWordCorpusProvider.future);
  final ayahs = <(int, int)>[];
  for (var p = 0; p < corpus.length; p++) {
    final w = corpus.words[p];
    if (w.ref.wordIndex == 0) ayahs.add((w.ref.ayahId, p));
  }
  final index = await compute(
    (args) => QuranPhonemeIndex.build(args.$1, args.$2),
    (reference, ayahs),
  );
  return (reference: reference, index: index);
});
