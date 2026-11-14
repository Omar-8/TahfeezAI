import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/quran_topics.dart';

/// The bundled topics (`tool/quran_data/build_topics.py`).
const kQuranTopicsAsset = 'assets/quran/topics.json';

QuranTopics _parse(String raw) =>
    QuranTopics.fromJson(jsonDecode(raw) as Map<String, Object?>);

/// The Quran's topics — read once, the first time they are shown (off the
/// UI thread where there is one).
final quranTopicsProvider = FutureProvider<QuranTopics>((ref) async {
  final raw = await rootBundle.loadString(kQuranTopicsAsset);
  return compute(_parse, raw);
});
