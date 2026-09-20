// Exercises QuranDisplayRepository/qpcHafsDisplayManifestProvider against
// the REAL bundled asset (assets/quran/quran_display/
// qpc_hafs_display_words.json) -- proving the manifest this milestone
// generated actually loads and resolves correctly, not just that the tool
// script that wrote it looked right.
//
// Deliberately does not hard-code expected Arabic word strings as Dart
// string literals: hand-copying Quran text with heavy diacritics across a
// terminal/editor boundary risks a byte-level Unicode
// normalization/ordering mismatch invisible to the eye (this file's first
// draft hit exactly that on Bismillah/Al-Ikhlas literals). Instead, this
// independently re-reads and re-decodes the same JSON asset and compares
// against *that*, so a real regression in the provider layer still fails
// loudly without this test also being a second, fragile transcription of
// Quran text.
import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tahfeez_ai/features/reader/application/quran_display_providers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late ProviderContainer container;
  late Map<String, dynamic> rawManifestJson;

  setUp(() async {
    container = ProviderContainer();
    rawManifestJson = jsonDecode(
      await rootBundle.loadString(
        'assets/quran/quran_display/qpc_hafs_display_words.json',
      ),
    );
  });

  tearDown(() => container.dispose());

  test('loads the real manifest with the expected validation counts', () async {
    final manifest = await container.read(
      qpcHafsDisplayManifestProvider.future,
    );
    expect(manifest, isNotNull);
    expect(manifest!.importedAyahCount, 6235);
    expect(manifest.excludedAyahIds, [37130]);
    expect(manifest.wordsByAyahId.length, 6235);
  });

  test(
    'QuranDisplayRepository.displayWordsForAyah matches the raw asset '
    'exactly, for the Bismillah, a mid-Surah ayah, and Al-Ikhlas 112:1',
    () async {
      await container.read(qpcHafsDisplayManifestProvider.future);
      final repository = container.read(quranDisplayRepositoryProvider);
      final rawWords = rawManifestJson['words'] as Map<String, dynamic>;

      for (final ayahId in [1001, 2255, 112001, 114006]) {
        final fromRepository = repository.displayWordsForAyah(ayahId);
        final fromRawAsset = (rawWords[ayahId.toString()] as List)
            .cast<String>();
        expect(fromRepository, isNotNull, reason: 'ayah $ayahId');
        expect(fromRepository, fromRawAsset, reason: 'ayah $ayahId');
        expect(fromRepository, isNotEmpty, reason: 'ayah $ayahId');
      }
    },
  );

  test('returns null for the one build-time-excluded ayah (37:130) -- never a '
      'guessed reconstruction', () async {
    await container.read(qpcHafsDisplayManifestProvider.future);
    final repository = container.read(quranDisplayRepositoryProvider);

    expect(repository.displayWordsForAyah(37130), isNull);
    expect(
      (rawManifestJson['words'] as Map<String, dynamic>).containsKey('37130'),
      isFalse,
    );
  });

  test('returns null for an ayah id with no entry at all', () async {
    await container.read(qpcHafsDisplayManifestProvider.future);
    final repository = container.read(quranDisplayRepositoryProvider);

    expect(repository.displayWordsForAyah(999999), isNull);
  });

  test('QuranDisplayRepository built with a null manifest (release-mode/'
      'missing-asset shape) resolves every ayah to null', () {
    const repository = QuranDisplayRepository(null);
    expect(repository.displayWordsForAyah(1001), isNull);
  });
}
