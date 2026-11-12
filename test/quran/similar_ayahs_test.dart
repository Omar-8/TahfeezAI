import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:tahfeez_ai/quran/domain/quran_ayah_numbers.dart';
import 'package:tahfeez_ai/quran/domain/similar_ayahs.dart';

/// The bundled similar ayahs (tool/quran_data/build_similar_ayahs.py): built
/// from the app's own text, every id and word position in it real, and the
/// well-known look-alikes found.
void main() {
  final file = jsonDecode(
    File('assets/quran/similar_ayahs.json').readAsStringSync(),
  ) as Map<String, Object?>;
  final dataset = jsonDecode(
    File('assets/quran/quran_dataset.json').readAsStringSync(),
  ) as Map<String, Object?>;
  final wordCounts = <int, int>{};
  for (final w in dataset['ayahWords'] as List<Object?>) {
    final id = (w as Map)['ayahId'] as int;
    wordCounts[id] = (wordCounts[id] ?? 0) + 1;
  }
  final similar = SimilarAyahs.fromJson(file);

  test('built from the app\'s own Quran text', () {
    expect(file['source'], (dataset['metadata'] as Map)['datasetVersion']);
  });

  test('every ayah real, every word position within its ayah', () {
    for (final raw in file['pairs'] as List<Object?>) {
      final p = raw as List<Object?>;
      final a = p[0] as int, b = p[1] as int;
      expect(a, lessThan(b));
      for (final id in [a, b]) {
        final surah = id ~/ 1000, verse = id % 1000;
        expect(surah, inInclusiveRange(1, 114));
        expect(verse, inInclusiveRange(1, surahAyahCounts[surah - 1]));
      }
      for (final (id, s) in [(a, p[3] as String), (b, p[4] as String)]) {
        for (final i in s.split(',').where((x) => x.isNotEmpty)) {
          expect(int.parse(i), lessThan(wordCounts[id]!), reason: '$id $i');
        }
      }
      expect(p[2] as int, inInclusiveRange(1, 100));
    }
  });

  test('each pair seen from both ayahs, the most alike first', () {
    final b = similar.of(2123).firstWhere((s) => s.ayahId == 2048);
    final a = similar.of(2048).firstWhere((s) => s.ayahId == 2123);
    expect(a.score, b.score);
    expect(a.differ, b.otherDiffer);
    for (final id in [2048, 55013, 2058]) {
      final scores = [for (final s in similar.of(id)) s.score];
      expect(scores, [...scores]..sort((x, y) => y.compareTo(x)));
    }
  });

  test('the well-known look-alikes', () {
    bool alike(int x, int y) => similar.of(x).any((s) => s.ayahId == y);
    expect(alike(2048, 2123), isTrue); // the Day no soul avails another
    expect(alike(2058, 7161), isTrue); // enter the town, say hittah
    expect(alike(2035, 7019), isTrue); // dwell in the Garden
    expect(alike(113001, 114001), isTrue); // Say: I seek refuge…
    // 2:48 and 2:123 differ in a few words (intercession / compensation).
    final s = similar.of(2048).firstWhere((s) => s.ayahId == 2123);
    expect(s.differ, isNotEmpty);
    expect(s.differ.length, lessThan(wordCounts[2123]! ~/ 2));
  });

  test('a repeated ayah: its repeats, word for word', () {
    // «فبأي آلاء ربكما تكذبان»: 31 times in Ar-Rahman.
    final repeats = similar.of(55013).where((s) => s.identical).toList();
    expect(repeats, hasLength(30));
    expect(repeats.every((s) => s.ayahId ~/ 1000 == 55), isTrue);
  });

  test('an ayah without look-alikes: none', () {
    expect(similar.of(1001 + 999), isEmpty);
    expect(similar.ayahCount, greaterThan(1000));
  });
}
