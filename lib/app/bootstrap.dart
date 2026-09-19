import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/logging/error_reporting.dart';
import '../core/logging/logging_package_logger.dart';
import '../core/storage/storage_providers.dart';
import '../quran/data/import/bundled_dataset_seeder.dart';
import '../quran/quran_providers.dart';
import '../quran/tafsir_providers.dart';
import '../quran/translation_providers.dart';
import 'app.dart';

/// Single, explicit startup sequence for Tahfeez AI.
///
/// Kept separate from `main()` so alternate entry points (tests, future
/// build flavors) can reuse it without duplicating setup order. Order
/// matters: bindings must be initialized before any plugin channel is
/// touched, global error reporting must be installed before [runApp] so it
/// can catch errors thrown during the very first frame, and the bundled
/// Quran dataset must be seeded — verified, then imported — before the UI
/// ever mounts, so the very first frame can already show real data with no
/// "downloading Quran" step and no network call. See
/// `docs/QURAN_DATA_PROVENANCE.md` and `BundledDatasetSeeder`.
Future<void> bootstrap() async {
  WidgetsFlutterBinding.ensureInitialized();

  final logger = LoggingPackageLogger();
  installGlobalErrorReporting(logger);

  final container = ProviderContainer();
  await BundledDatasetSeeder(
    quranRepository: container.read(quranRepositoryProvider),
    quranDatabase: container.read(quranDatabaseProvider),
    translationRepository: container.read(translationRepositoryProvider),
    tafsirRepository: container.read(tafsirRepositoryProvider),
    logger: logger,
    storage: container.read(browserStorageProvider),
  ).seedIfNeeded();

  runApp(
    UncontrolledProviderScope(container: container, child: const TahfeezApp()),
  );
}
