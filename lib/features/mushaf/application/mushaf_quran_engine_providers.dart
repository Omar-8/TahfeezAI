import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/core_providers.dart';
import '../../../core/logging/app_logger.dart';
import '../../../core/logging/logging_package_logger.dart';
import '../data/quran_engine/quran_engine_android_backend_stub.dart'
    if (dart.library.io) '../data/quran_engine/quran_engine_android_backend.dart';
import '../data/quran_engine/quran_engine_web_backend_stub.dart'
    if (dart.library.js_interop) '../data/quran_engine/quran_engine_web_backend.dart';
import '../domain/quran_engine/quran_engine_mushaf_backend.dart';

part 'mushaf_quran_engine_providers.g.dart';

/// The Web Quran Engine page-delivery endpoint's base URL, resolved once
/// at compile time via `--dart-define=QURAN_ENGINE_PAGE_BASE_URL=…` —
/// never a hard-coded default, unset by default. Quran Engine's own page
/// corpus carries the same unresolved KFGQPC redistribution status as
/// Tahfeez's existing QPC V2 fonts (`docs/QURAN_ENGINE_MIGRATION.md`) —
/// this must stay unset in every production build until upstream
/// permission to redistribute is confirmed. Mirrors
/// `qpc_page_font_providers.dart`'s `QPC_FONT_BASE_URL` exactly.
const _quranEnginePageBaseUrlEnv = String.fromEnvironment(
  'QURAN_ENGINE_PAGE_BASE_URL',
);

@Riverpod(keepAlive: true)
AppLogger mushafQuranEngineLogger(Ref ref) => LoggingPackageLogger();

/// The single platform-branch point for the Quran Engine Mushaf backend —
/// every other file (`MushafPageView`, `QuranEngineMushafPageContent`)
/// depends only on [QuranEngineMushafBackend], never on a concrete
/// platform implementation directly. Mirrors the exact pattern
/// `qpcPageFontManagerProvider` already established for the QPC V2
/// renderer's own native/Web split
/// (`lib/features/mushaf/application/qpc_page_font_providers.dart`).
///
/// `keepAlive: true` because [QuranEngineMushafBackend.initialize] is a
/// real one-time cost (opening the native library on Android; WASM
/// instantiation on Web) that should be paid once per session, not once
/// per Mushaf page visit.
@Riverpod(keepAlive: true)
Future<QuranEngineMushafBackend> mushafQuranEngineBackend(Ref ref) async {
  final capabilities = ref.watch(platformCapabilitiesProvider);

  final QuranEngineMushafBackend backend;
  if (capabilities.isAndroid) {
    backend = QuranEngineAndroidBackend();
  } else if (capabilities.isWeb) {
    backend = QuranEngineWebBackend(
      pageBaseUrl: _quranEnginePageBaseUrlEnv.isEmpty
          ? null
          : _quranEnginePageBaseUrlEnv,
      networkClient: ref.watch(networkClientProvider),
      logger: ref.watch(mushafQuranEngineLoggerProvider),
    );
  } else if (capabilities.isIOS) {
    // Per the migration's explicit instruction not to fabricate iOS
    // runtime success: no iOS integration has been implemented or
    // verified (no macOS/Xcode environment is available in this
    // sandbox). iOS is explicitly deferred/out of scope for this
    // migration milestone — see docs/QURAN_ENGINE_MIGRATION.md's iOS
    // status ("NOT IMPLEMENTED YET — FUTURE PLATFORM WORK").
    throw UnsupportedError(
      'The Quran Engine Mushaf backend has no iOS implementation yet — see '
      'docs/QURAN_ENGINE_MIGRATION.md.',
    );
  } else {
    throw UnsupportedError(
      'The Quran Engine Mushaf backend has no implementation for this '
      'platform.',
    );
  }

  await backend.initialize();
  return backend;
}
