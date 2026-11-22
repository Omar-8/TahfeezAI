import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:tahfeez_ai/features/listen/data/reciter_timings.dart';
import 'package:tahfeez_ai/features/listen/domain/quran_audio_sources.dart';

/// The bundled ayah timings of the reciters recorded by whole surahs
/// (`tool/acoustic_verification/align_surah_audio.py`): every surah each
/// recites, every ayah, in order.
void main() {
  for (final reciter in reciters.where((r) => r.bySurah)) {
    test('${reciter.nameEn}: each surah he recites timed, ayah by ayah, in '
        'order; none he lacks', () {
      final timings = parseSurahTimings(
        jsonDecode(
          File(reciterTimingsAsset(reciter.edition)).readAsStringSync(),
        ),
      );
      for (var surah = 1; surah <= 114; surah++) {
        final spans = timings.surahs[surah];
        if (!reciter.recites(surah)) {
          expect(spans, isNull, reason: '$surah is not his');
          continue;
        }
        expect(spans, hasLength(surahAyahCounts[surah - 1]), reason: '$surah');
        var last = -1;
        for (final (k, s) in spans!.indexed) {
          final at = '$surah:${k + 1}';
          expect(s.startMs, greaterThanOrEqualTo(last), reason: at);
          expect(s.endMs, greaterThan(s.startMs + 300), reason: at);
          // (Al-Baqarah 282, the longest ayah, under 3 minutes.)
          expect(s.endMs - s.startMs, lessThan(180000), reason: at);
          last = s.endMs;
        }
      }
      expect(timings.noBasmala, isNot(contains(1)));
      expect(timings.noBasmala.every(reciter.recites), isTrue);
    });
  }
}
