import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// An ayah's place in its surah's recording, in milliseconds.
typedef AyahSpan = ({int startMs, int endMs});

/// Where each ayah lies in the whole-surah recordings of a reciter
/// recorded by surah ([Reciter.bySurah]) —
/// `tool/acoustic_verification/align_surah_audio.py`.
class SurahTimings {
  const SurahTimings(this.surahs, {this.noBasmala = const {}});

  /// Surah → its ayahs' spans, in order (a surah's first starting at the
  /// reciter's own Bismillah, where its file has one).
  final Map<int, List<AyahSpan>> surahs;

  /// The surahs whose file opens without a Bismillah (one is played
  /// before, as for the reciters whose ayahs have none).
  final Set<int> noBasmala;

  /// Ayah [ayahId]'s span; `null` where not timed (a surah not recorded).
  AyahSpan? of(int ayahId) {
    final spans = surahs[ayahId ~/ 1000];
    final k = ayahId % 1000 - 1;
    return spans != null && k >= 0 && k < spans.length ? spans[k] : null;
  }
}

/// [json] (`{"1": [[start, end], …], …, "noBasmala": [3, …]}`) as
/// [SurahTimings]; anything malformed left out.
SurahTimings parseSurahTimings(Object? json) {
  final out = <int, List<AyahSpan>>{};
  if (json is! Map) return const SurahTimings({});
  for (final MapEntry(:key, :value) in json.entries) {
    final surah = int.tryParse('$key');
    if (surah == null || value is! List) continue;
    out[surah] = [
      for (final v in value)
        if (v is List && v.length == 2 && v[0] is num && v[1] is num)
          (startMs: (v[0] as num).round(), endMs: (v[1] as num).round()),
    ];
  }
  final none = json['noBasmala'];
  return SurahTimings(
    out,
    noBasmala: {
      if (none is List)
        for (final s in none)
          if (s is num) s.toInt(),
    },
  );
}

String reciterTimingsAsset(String edition) =>
    'assets/quran/reciter_timings/$edition.json';

/// [edition]'s ayah timings (bundled), read once.
final reciterTimingsProvider = FutureProvider.family<SurahTimings, String>((
  ref,
  edition,
) async {
  final raw = await rootBundle.loadString(reciterTimingsAsset(edition));
  return parseSurahTimings(jsonDecode(raw));
});
