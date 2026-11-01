// The bundled tajweed colours against the bundled Quran: built for exactly
// these words, every span inside its word, and each rule on its letters.
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tahfeez_ai/core/logging/app_logger.dart';
import 'package:tahfeez_ai/core/storage/browser_storage.dart';
import 'package:tahfeez_ai/quran/application/quran_script_code.dart';
import 'package:tahfeez_ai/quran/application/tajweed_colours.dart';
import 'package:tahfeez_ai/quran/data/import/bundled_dataset_seeder.dart';
import 'package:tahfeez_ai/quran/data/quran_database.dart';
import 'package:tahfeez_ai/quran/data/repositories/drift_quran_repository.dart';
import 'package:tahfeez_ai/quran/data/repositories/drift_tafsir_repository.dart';
import 'package:tahfeez_ai/quran/data/repositories/drift_translation_repository.dart';
import 'package:tahfeez_ai/quran/data/tafsir_database.dart';
import 'package:tahfeez_ai/quran/data/translation_database.dart';
import 'package:tahfeez_ai/quran/domain/models/tajweed_models.dart';

class _Quiet implements AppLogger {
  @override
  void debug(String message, {String? tag}) {}
  @override
  void info(String message, {String? tag}) {}
  @override
  void warning(
    String message, {
    String? tag,
    Object? error,
    StackTrace? stackTrace,
  }) {}
  @override
  void error(
    String message, {
    String? tag,
    Object? error,
    StackTrace? stackTrace,
  }) => fail(message);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('the tajweed colours fit the bundled Quran words exactly', () async {
    final quranDb = QuranDatabase(NativeDatabase.memory());
    final translationDb = TranslationDatabase(NativeDatabase.memory());
    final tafsirDb = TafsirDatabase(NativeDatabase.memory());
    addTearDown(quranDb.close);
    addTearDown(translationDb.close);
    addTearDown(tafsirDb.close);
    final quran = DriftQuranRepository(quranDb);
    const storage = SharedPreferencesBrowserStorage();
    await storage.remove('quran.dataset.seeded_version');
    await BundledDatasetSeeder(
      quranRepository: quran,
      quranDatabase: quranDb,
      translationRepository: DriftTranslationRepository(translationDb),
      tafsirRepository: DriftTafsirRepository(tafsirDb),
      logger: _Quiet(),
      storage: storage,
    ).seedIfNeeded();

    final words = <int, List<String>>{};
    for (final w
        in await quran.getAllWordsForScript(defaultQuranScriptCode)
          ..sort(
            (a, b) => a.ayahId != b.ayahId
                ? a.ayahId.compareTo(b.ayahId)
                : a.wordIndex.compareTo(b.wordIndex),
          )) {
      (words[w.ayahId] ??= []).add(w.text);
    }
    expect(words, hasLength(6236));

    final index = TajweedIndex.fromJson(
      jsonDecode(File(kTajweedAsset).readAsStringSync())
          as Map<String, Object?>,
    );
    // Built for these words (tool/quran_data/build_tajweed.py's hash).
    final canonical = [
      for (final id in words.keys) '$id|${words[id]!.join(' ')}',
    ].join('\n');
    expect(sha256.convert(utf8.encode(canonical)).toString(), index.textSha256);

    var spans = 0;
    final onLetters = <TajweedGroup, Set<String>>{
      TajweedGroup.qalqala: {...'قطبجد'.split('')},
      TajweedGroup.iqlab: {'ب', 'ۢ', 'ۭ'},
    };
    for (final id in index.ayahIds) {
      final ayah = words[id];
      expect(ayah, isNotNull, reason: '$id');
      for (var w = 0; w < ayah!.length; w++) {
        for (final s in index.spansOf(id, w)) {
          spans++;
          expect(
            s.start >= 0 && s.end <= ayah[w].length && s.start < s.end,
            isTrue,
            reason: '$id:$w $s «${ayah[w]}»',
          );
          final letters = onLetters[s.group];
          if (letters != null && s.group == TajweedGroup.qalqala) {
            expect(
              ayah[w].substring(s.start, s.end).split('').any(letters.contains),
              isTrue,
              reason: '$id:$w $s «${ayah[w]}»',
            );
          }
        }
      }
    }
    expect(spans, greaterThan(60000));
  });
}
