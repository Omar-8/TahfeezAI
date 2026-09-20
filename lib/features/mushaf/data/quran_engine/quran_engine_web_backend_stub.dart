import '../../../../core/logging/app_logger.dart';
import '../../../../core/networking/network_client.dart';
import '../../domain/quran_engine/quran_engine_mushaf_backend.dart';

/// Compiled in for every non-Web platform via the conditional import in
/// `../../application/mushaf_quran_engine_providers.dart`
/// (`if (dart.library.js_interop) '../data/quran_engine/quran_engine_web_backend.dart'`)
/// so that file's `dart:js_interop`/`package:web` imports (via
/// `quran_engine_web_bridge.dart`) — unavailable outside Web compilation —
/// are never part of the Android compilation graph at all.
///
/// Never actually constructed: `mushafQuranEngineBackendProvider` only
/// reaches the `QuranEngineWebBackend(...)` call site when
/// `PlatformCapabilities.isWeb` is true, which is false wherever this stub
/// is the one compiled in.
class QuranEngineWebBackend implements QuranEngineMushafBackend {
  QuranEngineWebBackend({
    required String? pageBaseUrl,
    required NetworkClient networkClient,
    required AppLogger logger,
  });

  @override
  Future<String> initialize() => throw UnsupportedError(
    'QuranEngineWebBackend is a Web-only stub on this platform.',
  );

  @override
  Future<QuranEngineMushafPage> loadPage(int pageNumber) =>
      throw UnsupportedError(
        'QuranEngineWebBackend is a Web-only stub on this platform.',
      );

  @override
  void disposePage(QuranEngineMushafPage page) => throw UnsupportedError(
    'QuranEngineWebBackend is a Web-only stub on this platform.',
  );

  @override
  Future<void> preloadAround(int pageNumber, {int radius = 1}) =>
      throw UnsupportedError(
        'QuranEngineWebBackend is a Web-only stub on this platform.',
      );
}
