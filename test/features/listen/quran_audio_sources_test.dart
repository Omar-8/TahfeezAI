import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:tahfeez_ai/features/listen/domain/quran_audio_sources.dart';

void main() {
  test('the surah ayah counts match the bundled dataset', () {
    final dataset = jsonDecode(
      File('assets/quran/quran_dataset.json').readAsStringSync(),
    ) as Map;
    final surahs = (dataset['surahs'] as List).cast<Map>()
      ..sort((a, b) => (a['surahNo'] as int).compareTo(b['surahNo'] as int));
    expect(surahAyahCounts, [for (final s in surahs) s['ayahCount']]);
  });

  test('ayahs are numbered through the whole Quran, 1 to 6236', () {
    expect(globalAyahNumber(1001), 1);
    expect(globalAyahNumber(2001), 8);
    expect(globalAyahNumber(2255), 262);
    expect(globalAyahNumber(114006), 6236);
    expect(
      ayahAudioUrl(2255, reciterFor('ar.alafasy')),
      'https://cdn.islamic.network/quran/audio/128/ar.alafasy/262.mp3',
    );
    expect(reciterFor('unknown').edition, reciters.first.edition);
  });

  test('word audio follows Quran.com\'s positions, which join two words in '
      'four ayahs', () {
    expect(
      wordAudioUrl(1001, 0),
      'https://audio.qurancdn.com/wbw/001_001_001.mp3',
    );
    // 2:181 — "بَعْدَ مَا" (canonical words 2 and 3) is Quran.com's word 3.
    expect(
      [for (var i = 0; i < 6; i++) quranComWordPosition(2181, i)],
      [1, 2, 3, 3, 4, 5],
    );
    // 37:130 — "إِلْ يَاسِينَ" is Quran.com's word 3.
    expect(
      [for (var i = 0; i < 4; i++) quranComWordPosition(37130, i)],
      [1, 2, 3, 3],
    );
    expect(quranComWordPosition(112001, 3), 4);
  });
}
