import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/similar_ayahs.dart';

/// The bundled similar ayahs (`tool/quran_data/build_similar_ayahs.py`).
const kSimilarAyahsAsset = 'assets/quran/similar_ayahs.json';

SimilarAyahs _parse(String raw) =>
    SimilarAyahs.fromJson(jsonDecode(raw) as Map<String, Object?>);

/// Every ayah's look-alikes — read once, the first time one is asked for
/// (off the UI thread where there is one).
final similarAyahsProvider = FutureProvider<SimilarAyahs>((ref) async {
  final raw = await rootBundle.loadString(kSimilarAyahsAsset);
  return compute(_parse, raw);
});

/// [ayahId]'s look-alikes, the most alike first (empty while loading).
final ayahLookAlikesProvider = Provider.autoDispose
    .family<List<SimilarAyah>, int>(
      (ref, ayahId) =>
          ref.watch(similarAyahsProvider).value?.of(ayahId) ?? const [],
    );
