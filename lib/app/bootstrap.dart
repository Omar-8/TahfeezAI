import '../features/settings/presentation/about_screen.dart';

import 'dart:async';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio_background/just_audio_background.dart';

import '../core/logging/error_reporting.dart';
import '../core/logging/logging_package_logger.dart';
import '../core/storage/storage_providers.dart';
import '../wbw/wbw_providers.dart';
import '../quran/data/import/bundled_dataset_seeder.dart';
import '../quran/quran_providers.dart';
import '../quran/tafsir_providers.dart';
import '../quran/translation_providers.dart';
import 'bootstrap_gate.dart';

/// Single, explicit startup sequence for Tahfeez AI.
///
/// Kept separate from `main()` so alternate entry points (tests, future
/// build flavors) can reuse it without duplicating setup order. Order
/// matters: bindings must be initialized before any plugin channel is
/// touched, and global error reporting must be installed before [runApp]
/// so it can catch errors thrown during the very first frame.
///
/// The bundled Quran dataset is still seeded — verified, then imported —
/// before any real screen can read from it, but [seedIfNeeded] is now only
/// *started* here, never awaited before [runApp]: a real, measured cold
/// seed costs ~1.3s (canonical Quran alone) to ~2.6s (dev/profile builds,
/// which also seed the Mushaf dataset), timed against the real bundled
/// assets — see `bootstrap_gate.dart`'s own doc comment. [runApp] fires
/// immediately; [TahfeezBootstrapGate] shows the splash (the icon and the
/// app's name) meanwhile — on Android it takes over from the system splash
/// with the icon in the same place. No provider ever
/// gets a chance to read from the database before seeding completes: the
/// real app widget tree ([TahfeezApp]) simply doesn't build until then.
Future<void> bootstrap() async {
  // The credited sources' notices on Flutter's licence page.
  registerCreditLicences();
  WidgetsFlutterBinding.ensureInitialized();
  // The first frame is the app's own splash (bootstrap_gate.dart): the
  // system splash's icon, in place, with the app's name below it.
  // Recitation audio as a media session (background playback, the
  // notification and lock-screen controls); before any player exists.
  if (!kIsWeb) {
    await JustAudioBackground.init(
      androidNotificationChannelId: 'ai.tahfeez.tahfeez_ai.audio',
      androidNotificationChannelName: 'Recitation audio',
      androidNotificationOngoing: true,
    );
  }
  // Portrait only, phones and tablets (the Android manifest says so too).
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  // Without this, `AnnotatedRegion<SystemUiOverlayStyle>`'s
  // `systemNavigationBarColor` has no effect on some Android versions/skins
  // until edge-to-edge is explicitly enabled — declaring the style alone
  // is not sufficient everywhere; confirmed by direct testing on a real
  // Android 11 (API 30) emulator, where the system navigation bar stayed
  // its own default dark color regardless of the app's requested color
  // until this call was added.
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);

  final logger = LoggingPackageLogger();
  installGlobalErrorReporting(logger);

  final container = ProviderContainer();
  final seeding = BundledDatasetSeeder(
    quranRepository: container.read(quranRepositoryProvider),
    quranDatabase: container.read(quranDatabaseProvider),
    translationRepository: container.read(translationRepositoryProvider),
    tafsirRepository: container.read(tafsirRepositoryProvider),
    wbwRepository: container.read(wbwRepositoryProvider),
    logger: logger,
    storage: container.read(browserStorageProvider),
  ).seedIfNeeded();
  runApp(
    UncontrolledProviderScope(
      container: container,
      child: TahfeezBootstrapGate(seeding: seeding),
    ),
  );
}
