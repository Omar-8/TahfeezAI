import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/core_providers.dart';
import '../data/quran_engine/quran_engine_android_backend_stub.dart'
    if (dart.library.io) '../data/quran_engine/quran_engine_android_backend.dart';
import '../domain/quran_engine/quran_engine_mushaf_backend.dart';

part 'mushaf_quran_engine_providers.g.dart';

/// The single platform-branch point for the Quran Engine Mushaf backend —
/// every other file (`MushafPageView`, a future Web backend) depends only
/// on [QuranEngineMushafBackend], never on a concrete platform
/// implementation directly. Mirrors the exact pattern
/// `qpcPageFontManagerProvider` already established for the QPC V2
/// renderer's own native/Web split
/// (`lib/features/mushaf/application/qpc_page_font_providers.dart`).
///
/// `keepAlive: true` because [QuranEngineMushafBackend.initialize] is a
/// real one-time cost (opening the native library on Android) that should
/// be paid once per session, not once per Mushaf page visit.
@Riverpod(keepAlive: true)
Future<QuranEngineMushafBackend> mushafQuranEngineBackend(Ref ref) async {
  final capabilities = ref.watch(platformCapabilitiesProvider);

  final QuranEngineMushafBackend backend;
  if (capabilities.isAndroid) {
    backend = QuranEngineAndroidBackend();
  } else if (capabilities.isWeb) {
    // The Web Quran Engine bridge was proven working on
    // `poc/quran-engine` (`docs/poc/QURAN_ENGINE_POC.md`) but has not yet
    // been promoted to this production abstraction — see
    // `docs/QURAN_ENGINE_MIGRATION.md`'s status table. Reported honestly
    // as unavailable rather than silently falling back to a different
    // backend.
    throw UnsupportedError(
      'The Quran Engine Mushaf backend is not yet promoted for Web — see '
      'docs/QURAN_ENGINE_MIGRATION.md.',
    );
  } else if (capabilities.isIOS) {
    // Per the migration's explicit instruction not to fabricate iOS
    // runtime success: no iOS integration has been implemented or
    // verified (no macOS/Xcode environment is available in this
    // sandbox). See docs/QURAN_ENGINE_MIGRATION.md's iOS status.
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
