import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:tahfeez_ai/wbw/application/arabic_word_gloss.dart';

void main() {
  test('a note found on its word, a two-word headword on both', () {
    const note =
        'بِسْمِ اللهِ: أَيْ: أَبْتَدِئُ قِرَاءَتِي مُسْتَعِينًا بِاسْمِ اللهِ.\n'
        'الرَّحْمنِ: الَّذِي وَسِعَتْ رَحْمَتُهُ جَمِيعَ الْخَلْقِ.';
    final words = ['بِسْمِ', 'ٱللَّهِ', 'ٱلرَّحْمَٰنِ', 'ٱلرَّحِيمِ'];
    expect(SirajGlosses.forWord(note, words, 0), startsWith('أَيْ'));
    expect(SirajGlosses.forWord(note, words, 1), startsWith('أَيْ'));
    expect(SirajGlosses.forWord(note, words, 2), startsWith('الَّذِي'));
    expect(SirajGlosses.forWord(note, words, 3), isNull);
  });

  test("the Mushaf's spelling and a prefixed و", () {
    expect(
      SirajGlosses.forWord('الصَّلَاةَ: الدعاء.', [
        'وَيُقِيمُونَ',
        'ٱلصَّلَوٰةَ',
      ], 1),
      'الدعاء.',
    );
    expect(
      SirajGlosses.forWord('يُقِيمُونَ: يؤدون.', [
        'وَيُقِيمُونَ',
        'ٱلصَّلَوٰةَ',
      ], 0),
      'يؤدون.',
    );
  });

  test('most of al-Sirāj\'s headwords are found in their ayahs', () {
    final quran = jsonDecode(
      File('assets/quran/quran_dataset.json').readAsStringSync(),
    ) as Map<String, Object?>;
    final words = <int, List<String>>{};
    for (final w
        in (quran['ayahWords']! as List).cast<Map<String, Object?>>()) {
      (words[w['ayahId']! as int] ??= []).add(w['text']! as String);
    }
    final siraj = jsonDecode(
      File('assets/quran/tafsir/ar_seraj.json').readAsStringSync(),
    ) as Map<String, Object?>;
    var lines = 0, found = 0;
    final missed = <String>[];
    for (final v in (siraj['verses']! as List).cast<Map<String, Object?>>()) {
      final ayah =
          words[(v['chapterNo']! as int) * 1000 + (v['verseNo']! as int)]!;
      for (final line in (v['text']! as String).split('\n')) {
        if (!line.contains(':')) continue;
        lines++;
        final hit = [
          for (var i = 0; i < ayah.length; i++)
            if (SirajGlosses.forWord(line, ayah, i) != null) i,
        ];
        if (hit.isNotEmpty) {
          found++;
        } else if (missed.length < 15) {
          missed.add(
            '${v['chapterNo']}:${v['verseNo']} ${line.split(':').first}',
          );
        }
      }
    }
    // ignore: avoid_print
    print('al-Sirāj: $found of $lines notes placed; missed e.g. $missed');
    expect(found / lines, greaterThan(0.85));
  });
}
