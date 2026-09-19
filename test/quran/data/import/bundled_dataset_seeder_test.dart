// Exercises BundledDatasetSeeder against the REAL bundled assets
// (assets/quran/) and real (in-memory) Drift databases — proving the whole
// "verify hash -> import" boot-time seeding path actually populates a
// working app, not just that the JSON files themselves look right.
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tahfeez_ai/core/logging/app_logger.dart';
import 'package:tahfeez_ai/quran/data/import/bundled_dataset_seeder.dart';
import 'package:tahfeez_ai/quran/data/quran_database.dart';
import 'package:tahfeez_ai/quran/data/repositories/drift_quran_repository.dart';
import 'package:tahfeez_ai/quran/data/repositories/drift_tafsir_repository.dart';
import 'package:tahfeez_ai/quran/data/repositories/drift_translation_repository.dart';
import 'package:tahfeez_ai/quran/data/tafsir_database.dart';
import 'package:tahfeez_ai/quran/data/translation_database.dart';

class _RecordingLogger implements AppLogger {
  final errors = <String>[];
  final infos = <String>[];

  @override
  void debug(String message, {String? tag}) {}

  @override
  void info(String message, {String? tag}) => infos.add(message);

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
  }) => errors.add(message);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late QuranDatabase quranDb;
  late TranslationDatabase translationDb;
  late TafsirDatabase tafsirDb;
  late DriftQuranRepository quranRepository;
  late DriftTranslationRepository translationRepository;
  late DriftTafsirRepository tafsirRepository;
  late _RecordingLogger logger;

  setUp(() {
    quranDb = QuranDatabase(NativeDatabase.memory());
    translationDb = TranslationDatabase(NativeDatabase.memory());
    tafsirDb = TafsirDatabase(NativeDatabase.memory());
    quranRepository = DriftQuranRepository(quranDb);
    translationRepository = DriftTranslationRepository(translationDb);
    tafsirRepository = DriftTafsirRepository(tafsirDb);
    logger = _RecordingLogger();
  });

  tearDown(() async {
    await quranDb.close();
    await translationDb.close();
    await tafsirDb.close();
  });

  test('seedIfNeeded populates the canonical Quran, translations, and tafsir '
      'from the real bundled assets with no errors logged', () async {
    final seeder = BundledDatasetSeeder(
      quranRepository: quranRepository,
      quranDatabase: quranDb,
      translationRepository: translationRepository,
      tafsirRepository: tafsirRepository,
      logger: logger,
    );

    await seeder.seedIfNeeded();

    expect(logger.errors, isEmpty, reason: logger.errors.join('\n'));

    final surahs = await quranRepository.getAllSurahs();
    expect(surahs, hasLength(114));

    final metadata = await quranRepository.getDatasetMetadata();
    expect(metadata, isNotNull);

    final en = await translationRepository.getInstalledTranslation('en-rowwad');
    expect(en, isNotNull);
    final de = await translationRepository.getInstalledTranslation('de-rowwad');
    expect(de, isNotNull);

    final tafsir = await tafsirRepository.getInstalledTafsir('ar-muyassar');
    expect(tafsir, isNotNull);
  });

  test('seeding twice does not error and does not duplicate data', () async {
    final seeder = BundledDatasetSeeder(
      quranRepository: quranRepository,
      quranDatabase: quranDb,
      translationRepository: translationRepository,
      tafsirRepository: tafsirRepository,
      logger: logger,
    );

    await seeder.seedIfNeeded();
    await seeder.seedIfNeeded();

    expect(logger.errors, isEmpty, reason: logger.errors.join('\n'));
    final surahs = await quranRepository.getAllSurahs();
    expect(surahs, hasLength(114));
  });
}
