import '../features/settings/presentation/about_screen.dart';

import 'dart:async';

import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform, kIsWeb;
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'package:path_provider/path_provider.dart';

import '../core/logging/error_reporting.dart';
import '../core/logging/logging_package_logger.dart';
import '../core/storage/storage_providers.dart';
import '../wbw/wbw_providers.dart';
import '../quran/data/import/bundled_database_installer.dart';
import '../quran/data/import/bundled_dataset_seeder.dart';
import '../quran/data/import/meaning_pack_store.dart';
import '../quran/application/meaning_packs.dart';
import '../quran/application/quran_setup.dart';
import '../quran/quran_providers.dart';
import '../quran/tafsir_providers.dart';
import '../quran/translation_providers.dart';
import 'bootstrap_gate.dart';
import 'startup_timing.dart';

/// Single, explicit startup sequence for TahfeezAI.
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
  startupMark('bootstrap');
  // The credited sources' notices on Flutter's licence page.
  registerCreditLicences();
  WidgetsFlutterBinding.ensureInitialized();
  // The first frame is the app's own splash (bootstrap_gate.dart): the
  // system splash's icon, in place, with the app's name below it.
  // Recitation audio as a media session (background playback, the
  // notification and lock-screen controls); before any player exists — the
  // app (where players are made) waits for it behind the splash. Not
  // awaited here: it takes ~0.4 s, alongside the Qur'an's setup.
  final audioSession = kIsWeb
      ? Future<void>.value()
      : JustAudioBackground.init(
          androidNotificationChannelId: 'ai.tahfeez.tahfeez_ai.audio',
          androidNotificationChannelName: 'Recitation audio',
          androidNotificationOngoing: true,
        ).then((_) => startupMark('audio session'));
  // Portrait only, phones and tablets (the Android manifest says so too).
  // These two system calls are not awaited: the first answer waits for the
  // platform to finish starting the screen (~0.35 s on a phone), and the
  // splash needn't. They are sent in order, before the first frame's.
  unawaited(
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]),
  );
  // Without this, `AnnotatedRegion<SystemUiOverlayStyle>`'s
  // `systemNavigationBarColor` has no effect on some Android versions/skins
  // until edge-to-edge is explicitly enabled — declaring the style alone
  // is not sufficient everywhere; confirmed by direct testing on a real
  // Android 11 (API 30) emulator, where the system navigation bar stayed
  // its own default dark color regardless of the app's requested color
  // until this call was added.
  unawaited(SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge));

  startupMark('system UI');
  final logger = LoggingPackageLogger();
  installGlobalErrorReporting(logger);

  final container = ProviderContainer();
  // Its failure kept (quranSetupProvider): the screens needing the Quran
  // show it, with a way to try again.
  final seeder = BundledDatasetSeeder(
    quranRepository: container.read(quranRepositoryProvider),
    quranDatabase: container.read(quranDatabaseProvider),
    translationRepository: container.read(translationRepositoryProvider),
    tafsirRepository: container.read(tafsirRepositoryProvider),
    wbwRepository: container.read(wbwRepositoryProvider),
    logger: logger,
    storage: container.read(browserStorageProvider),
  );
  // On Android and iOS the ready-made databases are unpacked into place;
  // the web imports the datasets.
  Future<String?> setUp() async {
    if (kIsWeb ||
        (defaultTargetPlatform != TargetPlatform.android &&
            defaultTargetPlatform != TargetPlatform.iOS)) {
      return seeder.seedIfNeeded();
    }
    final installer = BundledDatabaseInstaller(
      storage: container.read(browserStorageProvider),
      directory: await getApplicationDocumentsDirectory(),
      logger: logger,
    );
    final failure = await installer.installIfNeeded();
    startupMark('databases');
    if (failure != null) return failure;
    // The app's language's translations, tafsir and word meanings (English
    // and Arabic's are built in), then whichever are chosen as they change.
    await container
        .read(meaningPacksProvider.notifier)
        .attach(
          MeaningPackStore(
            databases: {
              MeaningPackKind.translation: container.read(
                translationDatabaseProvider,
              ),
              MeaningPackKind.tafsir: container.read(tafsirDatabaseProvider),
              MeaningPackKind.wbw: container.read(wbwDatabaseProvider),
            },
            temp: await getTemporaryDirectory(),
            loadString: rootBundle.loadString,
            unpack: BundledDatabaseInstaller.nativeUnpack,
          ),
        );
    startupMark('meaning packs');
    return null;
  }

  final seeding = container.read(quranSetupProvider.notifier).run(setUp);
  runApp(
    UncontrolledProviderScope(
      container: container,
      child: TahfeezBootstrapGate(seeding: seeding, audioSession: audioSession),
    ),
  );
}
