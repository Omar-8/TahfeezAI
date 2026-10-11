import 'package:flutter_riverpod/flutter_riverpod.dart';
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

/// Known aspect ratios of loaded Quran Engine pages, keyed by page number.
///
/// The engine page corpus renders every page as one fixed-size bitmap, so a
/// page's real [QuranEngineMushafPage.aspectRatio] is all the web Mushaf
/// pager needs to size its page frame tightly around the printed page
/// instead of around the whole viewport box (see `MushafPager._bordered`).
///
/// This is a publish/read channel only: `QuranEngineMushafPageContent`
/// publishes a page's ratio here once it has loaded it, and `MushafPager`
/// reads it back. Page loading and disposal stay owned solely by the content
/// widget — a second load path here (loading the page just to read its ratio,
/// then disposing it) could race the content's own load and dispose the very
/// page it is rendering.
class MushafPageAspectRatios extends Notifier<Map<int, double>> {
  @override
  Map<int, double> build() => const {};

  void report(int pageNumber, double aspectRatio) {
    if (state[pageNumber] == aspectRatio) return;
    state = {...state, pageNumber: aspectRatio};
  }
}

final mushafPageAspectRatiosProvider =
    NotifierProvider<MushafPageAspectRatios, Map<int, double>>(
      MushafPageAspectRatios.new,
    );

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
  if (capabilities.isAndroid || capabilities.isIOS) {
    // The native engine through dart:ffi: on Android its shared library,
    // on iOS linked into the app (qvp_flutter's iOS framework).
    backend = QuranEngineAndroidBackend();
  } else if (capabilities.isWeb) {
    backend = QuranEngineWebBackend(
      pageBaseUrl: _quranEnginePageBaseUrlEnv.isEmpty
          ? null
          : _quranEnginePageBaseUrlEnv,
      networkClient: ref.watch(networkClientProvider),
      logger: ref.watch(mushafQuranEngineLoggerProvider),
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
