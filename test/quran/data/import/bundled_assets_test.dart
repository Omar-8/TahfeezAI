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

  // Ayahs a tafsir explains together with the one before, so has no row
  // of their own (tool/quran_data/build_production_data.dart).
  const merged = {
    'tafsir/es_mukhtasar.json': {'59:24'},
  };

  test('each translation and tafsir: all 6,236 ayahs, none empty', () {
    for (final name in hashes.keys.where(
      (n) => n.startsWith('translations/') || n.startsWith('tafsir/'),
    )) {
      final json =
          jsonDecode(File('assets/quran/$name').readAsStringSync()) as Map;
      final verses = (json['verses'] as List).cast<Map>();
      final absent = merged[name] ?? const <String>{};
      if (name == 'tafsir/ur_ahsanulbayan.json') {
        // A translation's notes: only the ayahs they comment on.
        expect(verses.length, inInclusiveRange(4000, 6236), reason: name);
      } else {
        expect(verses, hasLength(6236 - absent.length), reason: name);
      }
      expect(
        verses.where((v) => '${v['text']}'.trim().isEmpty),
        isEmpty,
        reason: name,
      );
      final keys = {
        for (final v in verses) '${v['chapterNo']}:${v['verseNo']}',
      };
      expect(keys, hasLength(verses.length), reason: '$name: no ayah twice');
      expect(keys.intersection(absent), isEmpty, reason: name);
    }
  });

  test('word meanings: every canonical word, exactly once, in each pack', () {
    final dataset = jsonDecode(
      File('assets/quran/quran_dataset.json').readAsStringSync(),
    ) as Map;
    final canonical = {
      for (final w in (dataset['ayahWords'] as List).cast<Map>())
        '${w['ayahId']}:${w['wordIndex']}',
    };
    final names = hashes.keys.where((n) => n.startsWith('wbw/')).toList();
    expect(names, hasLength(7));
    for (final name in names) {
      final pack =
          jsonDecode(File('assets/quran/$name').readAsStringSync()) as Map;
      final words = (pack['words'] as List).cast<List>();
      final keys = {for (final w in words) '${w[0]}:${w[1]}'};
      expect(words, hasLength(canonical.length), reason: name);
      // Differences, not set equality: a deep compare of ~77k items is slow.
      expect(keys.difference(canonical), isEmpty, reason: name);
      expect(canonical.difference(keys), isEmpty, reason: name);
      final without = words.where((w) => '${w[2] ?? ''}'.trim().isEmpty);
      // English has every meaning (and the transliteration); another
      // language may lack a few, which the English fills in the app
      // (Turkish the most: about 9 %).
      if (name == 'wbw/en_qurancom.json') {
        expect(without, isEmpty, reason: 'every word has a meaning');
        expect(
          words.where((w) => '${w[3] ?? ''}'.trim().isEmpty),
          isEmpty,
          reason: 'every word has its transliteration',
        );
      } else {
        expect(without.length, lessThan(words.length ~/ 10), reason: name);
      }
    }
  });
}
