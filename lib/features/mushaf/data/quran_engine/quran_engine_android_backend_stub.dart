import '../../domain/quran_engine/quran_engine_mushaf_backend.dart';

/// Compiled in for Web via the conditional import in
/// `../../application/mushaf_quran_engine_providers.dart`
/// (`if (dart.library.io) '../data/quran_engine/quran_engine_android_backend.dart'`)
/// so that file's `qvp_flutter` (a `dart:ffi` plugin) dependency —
/// unavailable under Web compilation — is never part of the Web
/// compilation graph at all. See `quran_engine_web_backend_stub.dart`'s
/// equivalent protection in the other direction.
///
/// Never actually constructed: `mushafQuranEngineBackendProvider` only
/// reaches the `QuranEngineAndroidBackend()` call site when
/// `PlatformCapabilities.isAndroid` is true, which is false wherever this
/// stub is the one compiled in.
class QuranEngineAndroidBackend implements QuranEngineMushafBackend {
  QuranEngineAndroidBackend();

  @override
  Future<String> initialize() => throw UnsupportedError(
    'QuranEngineAndroidBackend is an Android-only stub on this platform.',
  );

  @override
  Future<QuranEngineMushafPage> loadPage(int pageNumber) =>
      throw UnsupportedError(
        'QuranEngineAndroidBackend is an Android-only stub on this platform.',
      );

  @override
  void disposePage(QuranEngineMushafPage page) => throw UnsupportedError(
    'QuranEngineAndroidBackend is an Android-only stub on this platform.',
  );

  @override
  Future<void> preloadAround(int pageNumber, {int radius = 1}) =>
      throw UnsupportedError(
        'QuranEngineAndroidBackend is an Android-only stub on this platform.',
      );
}
