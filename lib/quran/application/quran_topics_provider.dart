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

/// A topic, with the group it is in.
typedef TopicRef = ({TopicGroup group, TopicConcept concept});

/// Ayah id → the topics it is in (its group's order, then the group's),
/// once the topics are loaded; empty before.
final topicsByAyahProvider = Provider<Map<int, List<TopicRef>>>((ref) {
  final topics = ref.watch(quranTopicsProvider).value;
  if (topics == null) return const {};
  final byAyah = <int, List<TopicRef>>{};
  for (final group in topics.groups) {
    for (final concept in group.concepts) {
      for (final ayah in concept.ayahs) {
        (byAyah[ayah] ??= []).add((group: group, concept: concept));
      }
    }
  }
  return byAyah;
});
