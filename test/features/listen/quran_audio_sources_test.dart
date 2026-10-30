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
      'https://cdn.islamic.network/quran/audio/64/ar.alafasy/262.mp3',
    );
    expect(reciterFor('unknown').edition, reciters.first.edition);
  });

  test('Al-Tablawi plays from everyayah.com, by surah and ayah', () {
    final tablawi = reciterFor('ar.tablawi');
    expect(tablawi.edition, 'ar.tablawi');
    expect(
      ayahAudioUrl(2255, tablawi),
      'https://everyayah.com/data/Mohammad_al_Tablaway_64kbps/002255.mp3',
    );
    expect(
      ayahAudioUrl(ayahIdAtGlobal(6236), tablawi),
      'https://everyayah.com/data/Mohammad_al_Tablaway_64kbps/114006.mp3',
    );
    expect(reciterDownloadSize(tablawi), '≈ 854 MB');
  });

  test('Al-Banna plays from everyayah.com (32 kbps, all it has there)', () {
    final banna = reciterFor('ar.banna');
    expect(banna.edition, 'ar.banna');
    expect(
      ayahAudioUrl(36001, banna),
      'https://everyayah.com/data/mahmoud_ali_al_banna_32kbps/036001.mp3',
    );
    expect(reciterDownloadSize(banna), '≈ 384 MB');
  });

  test('surahs: their ayahs and their share of a download', () {
    expect(surahShare, hasLength(114));
    expect(
      surahShare.fold<double>(0, (a, b) => a + b),
      moreOrLessEquals(1, epsilon: 0.001),
    );
    expect(surahAyahNumbers(1), [1, 2, 3, 4, 5, 6, 7]);
    expect(surahAyahNumbers(2).first, 8);
    expect(surahAyahNumbers(2).length, 286);
    expect(surahAyahNumbers(114).last, 6236);
    expect(
      [for (var s = 1; s <= 114; s++) ...surahAyahNumbers(s)],
      [for (var n = 1; n <= 6236; n++) n],
    );
    final alafasy = reciterFor('ar.alafasy');
    // Al-Baqara, about 8% of the Quran's letters; Al-Ikhlas, tenths of a MB.
    expect(surahDownloadSize(alafasy, 2), '≈ 70 MB');
    expect(surahDownloadSize(alafasy, 112), '≈ 0.1 MB');
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
