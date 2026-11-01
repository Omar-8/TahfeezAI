import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/core_providers.dart';
import '../../../core/networking/network_client.dart';
import '../domain/word_timings.dart';

/// Quran.com's word timings ([quranComRecitations], by ayah, and
/// [quranComSurahRecitations], by surah), fetched when a correction is
/// asked for and kept for this run of the app only — the Quran
/// Foundation's terms allow no long-term copy.
class WordTimingsRepository {
  WordTimingsRepository(this._network);

  final NetworkClient _network;
  final _ayahs = <(int, int), AyahWordTimings>{};

  /// Each surah's ayahs, timed in its recording (key: reciter, surah).
  final _surahs = <(int, int), Map<int, AyahWordTimings>>{};

  /// Ayah [ayahId]'s word timings by [edition]; `null` for a reciter with
  /// none. Throws when they can't be fetched (offline).
  Future<AyahWordTimings?> timings(String edition, int ayahId) async {
    final byAyah = quranComRecitations[edition];
    if (byAyah != null) {
      final key = (byAyah, ayahId);
      final cached = _ayahs[key];
      if (cached != null) return cached;
      final body = await _get(wordTimingsUrl(byAyah, ayahId), {
        'fields': 'segments',
      });
      final files = body is Map ? body['audio_files'] : null;
      final file = files is List && files.isNotEmpty ? files.first : null;
      return _ayahs[key] = AyahWordTimings(
        parseWordSegments(file is Map ? file['segments'] : null),
      );
    }
    final bySurah = quranComSurahRecitations[edition];
    if (bySurah == null) return null;
    final surah = ayahId ~/ 1000;
    final key = (bySurah, surah);
    var ayahs = _surahs[key];
    if (ayahs == null) {
      final body = await _get(surahTimingsUrl(bySurah), {
        'chapter': '$surah',
        'segments': 'true',
      });
      _surahs[key] = ayahs = _surahTimings(body);
    }
    return ayahs[ayahId] ?? const AyahWordTimings({});
  }

  Future<Object?> _get(String url, Map<String, dynamic> query) async {
    final response = await _network.get<Object?>(url, queryParameters: query);
    return switch (response.data) {
      final String s => jsonDecode(s),
      final other => other,
    };
  }

  /// A surah recording's ayahs, each with its place and words in it.
  static Map<int, AyahWordTimings> _surahTimings(Object? body) {
    final files = body is Map ? body['audio_files'] : null;
    final file = files is List && files.isNotEmpty ? files.first : null;
    if (file is! Map || file['audio_url'] is! String) return const {};
    final url = file['audio_url'] as String;
    final out = <int, AyahWordTimings>{};
    for (final v in file['verse_timings'] as List? ?? const []) {
      if (v is! Map || v['verse_key'] is! String) continue;
      final key = (v['verse_key'] as String).split(':');
      final surah = int.tryParse(key.first), ayah = int.tryParse(key.last);
      if (key.length != 2 || surah == null || ayah == null) continue;
      final ayahId = surah * 1000 + ayah;
      out[ayahId] = AyahWordTimings(
        parseWordSegments(v['segments']),
        surahUrl: url,
        fromMs: (v['timestamp_from'] as num?)?.round() ?? 0,
        toMs: (v['timestamp_to'] as num?)?.round(),
      );
    }
    return out;
  }
}

final wordTimingsRepositoryProvider = Provider<WordTimingsRepository>(
  (ref) => WordTimingsRepository(ref.watch(networkClientProvider)),
);
