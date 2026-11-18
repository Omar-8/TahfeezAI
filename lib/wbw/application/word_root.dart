import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Each word's root, from the Quranic Arabic Corpus
/// (`tool/quran_data/build_word_roots.py`, `docs/THIRD_PARTY_RESOURCES.md`).
const kWordRootsAsset = 'assets/quran/word_roots.json';

/// The words' roots: per ayah, one per word in order ("" for a word with
/// none — a particle, a pronoun).
class WordRoots {
  const WordRoots(this._byAyah);

  factory WordRoots.fromJson(Map<String, Object?> json) => WordRoots({
    for (final MapEntry(:key, :value)
        in (json['roots']! as Map<String, Object?>).entries)
      int.parse(key): (value! as String).split(','),
  });

  final Map<int, List<String>> _byAyah;

  /// The root of the word at [wordIndex] of [ayahId], its letters joined
  /// («قول», owner 2026-11-18), or `null` where it has none.
  String? of(int ayahId, int wordIndex) {
    final words = _byAyah[ayahId];
    if (words == null || wordIndex < 0 || wordIndex >= words.length) {
      return null;
    }
    final root = words[wordIndex];
    return root.isEmpty ? null : root;
  }
}

WordRoots _parse(String raw) =>
    WordRoots.fromJson(jsonDecode(raw) as Map<String, Object?>);

/// Every word's root — read once, the first time one is asked for (off the
/// UI thread where there is one).
final wordRootsProvider = FutureProvider<WordRoots>((ref) async {
  final raw = await rootBundle.loadString(kWordRootsAsset);
  return compute(_parse, raw);
});

/// The word's root («قول»), `null` where it has none; loading while the
/// roots are read.
final wordRootProvider =
    FutureProvider.family<String?, ({int ayahId, int wordIndex})>(
      (ref, word) async =>
          (await ref.watch(wordRootsProvider.future))
              .of(word.ayahId, word.wordIndex),
    );
