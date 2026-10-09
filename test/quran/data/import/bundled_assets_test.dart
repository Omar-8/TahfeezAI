import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';

/// The bundled Quran resources as shipped: every asset the manifest lists
/// exists with its recorded hash and is declared in pubspec.yaml, and every
/// translation and tafsir covers every ayah.
void main() {
  final manifest = jsonDecode(
    File('assets/quran/resource_manifest.json').readAsStringSync(),
  ) as Map<String, dynamic>;
  final hashes = (manifest['packagedAssetHashes'] as Map)
      .cast<String, String>();
  final pubspec = File('pubspec.yaml').readAsStringSync();

  test('each packaged asset: present, as hashed, and declared', () {
    for (final MapEntry(key: name, value: hash) in hashes.entries) {
      final file = File('assets/quran/$name');
      expect(file.existsSync(), isTrue, reason: name);
      expect(
        sha256.convert(file.readAsBytesSync()).toString(),
        hash,
        reason: name,
      );
      expect(pubspec, contains('- assets/quran/$name'), reason: name);
    }
  });

  test('each translation and tafsir: all 6,236 ayahs, none empty', () {
    for (final name in hashes.keys.where(
      (n) => n.startsWith('translations/') || n.startsWith('tafsir/'),
    )) {
      final json =
          jsonDecode(File('assets/quran/$name').readAsStringSync()) as Map;
      final verses = (json['verses'] as List).cast<Map>();
      expect(verses, hasLength(6236), reason: name);
      expect(
        verses.where((v) => '${v['text']}'.trim().isEmpty),
        isEmpty,
        reason: name,
      );
      expect(
        {for (final v in verses) '${v['chapterNo']}:${v['verseNo']}'},
        hasLength(6236),
        reason: '$name: no ayah twice',
      );
    }
  });

  test('word meanings: every canonical word, exactly once, with a meaning', () {
    final dataset = jsonDecode(
      File('assets/quran/quran_dataset.json').readAsStringSync(),
    ) as Map;
    final canonical = {
      for (final w in (dataset['ayahWords'] as List).cast<Map>())
        '${w['ayahId']}:${w['wordIndex']}',
    };
    final pack = jsonDecode(
      File('assets/quran/wbw/en_qurancom.json').readAsStringSync(),
    ) as Map;
    final words = (pack['words'] as List).cast<List>();
    final keys = {for (final w in words) '${w[0]}:${w[1]}'};
    expect(words, hasLength(canonical.length));
    // Differences, not set equality: a deep compare of ~77k items is slow.
    expect(keys.difference(canonical), isEmpty);
    expect(canonical.difference(keys), isEmpty);
    expect(
      words.where((w) => '${w[2] ?? ''}'.trim().isEmpty),
      isEmpty,
      reason: 'every word has a meaning',
    );
  });
}
