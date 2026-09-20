// Exercises WebQpcPageFontManager against the REAL generated font manifest
// and REAL font bytes (read from disk and handed back by a fake
// NetworkClient, standing in for the HTTP fetch) through Flutter's actual
// font-loading engine -- proving the same concurrency-safety/lazy-loading
// contract FontLoaderQpcPageFontManager already has, plus the Web-specific
// "not configured" failure and manifest-driven URL shape.
import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tahfeez_ai/core/logging/app_logger.dart';
import 'package:tahfeez_ai/core/networking/network_client.dart';
import 'package:tahfeez_ai/features/mushaf/data/web_qpc_page_font_manager.dart';
import 'package:tahfeez_ai/features/mushaf/domain/qpc_page_font_manager.dart';
import 'package:tahfeez_ai/quran/data/page_font_manifest_codec.dart';

class _NoopLogger implements AppLogger {
  final debugs = <String>[];
  final warnings = <String>[];
  final errors = <String>[];

  @override
  void debug(String message, {String? tag}) => debugs.add(message);

  @override
  void info(String message, {String? tag}) {}

  @override
  void warning(
    String message, {
    String? tag,
    Object? error,
    StackTrace? stackTrace,
  }) => warnings.add(message);

  @override
  void error(
    String message, {
    String? tag,
    Object? error,
    StackTrace? stackTrace,
  }) => errors.add(message);
}

/// Serves real bytes from disk (never fabricated font data -- FontLoader
/// must genuinely register a real font for these tests to prove anything),
/// keyed by the exact URL requested, with configurable per-URL failure and
/// call-count tracking to verify dedup.
class _FakeNetworkClient implements NetworkClient {
  final requestedUrls = <String>[];
  final Set<String> failUrlsOnce = {};

  @override
  Future<Response<List<int>>> getBytes(
    String path, {
    CancelToken? cancelToken,
  }) async {
    requestedUrls.add(path);
    if (failUrlsOnce.remove(path)) {
      throw DioException(
        requestOptions: RequestOptions(path: path),
        error: 'simulated network failure',
      );
    }
    // The URL's last path segment is the real vendored font's own
    // filename (see WebQpcPageFontManager's URL shape) -- read that exact
    // file's real bytes from the vendored package on disk.
    final fileName = path.split('/').last;
    final bytes = File('assets/quran/fonts/qpc_v2/$fileName').readAsBytesSync();
    return Response<List<int>>(
      data: bytes,
      requestOptions: RequestOptions(path: path),
    );
  }

  @override
  Future<Response<T>> get<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
    CancelToken? cancelToken,
  }) => throw UnimplementedError();

  @override
  Future<Response> download(
    String urlPath,
    String savePath, {
    void Function(int received, int total)? onReceiveProgress,
    CancelToken? cancelToken,
  }) => throw UnimplementedError();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final manifestFile = File('assets/quran/manifests/qpc_v2_fonts.json');
  final fontsDir = Directory('assets/quran/fonts/qpc_v2');
  if (!manifestFile.existsSync() || !fontsDir.existsSync()) {
    // Honest skip: this environment has not run
    // `dart run tool/quran_data/build_qpc_fonts.dart` -- the same
    // prerequisite every other real-QPC-data test already has.
    return;
  }

  final manifest = pageFontManifestFromJson(
    jsonDecode(manifestFile.readAsStringSync()) as Map<String, dynamic>,
  );

  late _NoopLogger logger;
  late _FakeNetworkClient network;

  WebQpcPageFontManager manager({String? baseUrl}) => WebQpcPageFontManager(
    manifest: manifest,
    logger: logger,
    networkClient: network,
    baseUrl: baseUrl,
  );

  setUp(() {
    logger = _NoopLogger();
    network = _FakeNetworkClient();
  });

  test(
    'with no baseUrl configured, ensureLoaded fails with '
    'QpcWebFontDeliveryNotConfiguredException -- never a silent fallback',
    () async {
      final m = manager();
      await expectLater(
        m.ensureLoaded(1, 1),
        throwsA(isA<QpcWebFontDeliveryNotConfiguredException>()),
      );
      expect(network.requestedUrls, isEmpty);
    },
  );

  test('an empty-string baseUrl is also treated as not configured', () async {
    final m = manager(baseUrl: '   ');
    await expectLater(
      m.ensureLoaded(1, 1),
      throwsA(isA<QpcWebFontDeliveryNotConfiguredException>()),
    );
  });

  test('with a configured baseUrl, ensureLoaded fetches and registers the '
      'real font, using a manifest-driven, content-addressable URL', () async {
    final m = manager(baseUrl: 'https://example.invalid/fonts');
    expect(m.isLoaded(1, 1), isFalse);

    final handle = await m.ensureLoaded(1, 1);

    expect(handle.fontFamily, 'QCF2001');
    expect(m.isLoaded(1, 1), isTrue);
    expect(network.requestedUrls, hasLength(1));
    expect(
      network.requestedUrls.single,
      'https://example.invalid/fonts/qpc-v2/${manifest.fontPackageHash}/p1.ttf',
    );
  });

  test('a trailing slash on baseUrl does not produce a double slash', () async {
    final m = manager(baseUrl: 'https://example.invalid/fonts/');
    await m.ensureLoaded(1, 1);
    expect(
      network.requestedUrls.single,
      'https://example.invalid/fonts/qpc-v2/${manifest.fontPackageHash}/p1.ttf',
    );
  });

  test('concurrent requests for the same page share one fetch', () async {
    final m = manager(baseUrl: 'https://example.invalid/fonts');
    final futures = List.generate(5, (_) => m.ensureLoaded(1, 302));
    final handles = await Future.wait(futures);

    expect(handles.every((h) => h.fontFamily == 'QCF2302'), isTrue);
    expect(m.isLoaded(1, 302), isTrue);
    expect(
      network.requestedUrls.where((u) => u.endsWith('p302.ttf')),
      hasLength(1),
      reason: 'must not issue duplicate network requests for the same page',
    );
  });

  test('a failed fetch removes the in-flight entry so a later call can retry', () async {
    final m = manager(baseUrl: 'https://example.invalid/fonts');
    final url =
        'https://example.invalid/fonts/qpc-v2/${manifest.fontPackageHash}/p5.ttf';
    network.failUrlsOnce.add(url);

    await expectLater(
      m.ensureLoaded(1, 5),
      throwsA(isA<QpcPageFontLoadException>()),
    );
    expect(m.isLoaded(1, 5), isFalse);
    expect(logger.errors, isNotEmpty);

    // Retry (network failure was one-shot) -- must succeed, proving the
    // in-flight bookkeeping was cleared on failure.
    final handle = await m.ensureLoaded(1, 5);
    expect(handle.fontFamily, 'QCF2005');
    expect(m.isLoaded(1, 5), isTrue);
  });

  test('an unknown page/mushaf throws QpcPageFontLoadException without '
      'making a network request', () async {
    final m = manager(baseUrl: 'https://example.invalid/fonts');
    await expectLater(
      m.ensureLoaded(999, 1),
      throwsA(isA<QpcPageFontLoadException>()),
    );
    expect(network.requestedUrls, isEmpty);
  });

  test('fontFamilyFor resolves from the manifest before loading', () {
    final m = manager(baseUrl: 'https://example.invalid/fonts');
    expect(m.fontFamilyFor(1, 604), 'QCF2604');
    expect(m.isLoaded(1, 604), isFalse);
  });

  test(
    'preloadAround does nothing (no network calls) when not configured',
    () async {
      final m = manager();
      await m.preloadAround(1, 302, radius: 1);
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(network.requestedUrls, isEmpty);
    },
  );

  test(
    'preloadAround loads neighboring pages without blocking the caller',
    () async {
      final m = manager(baseUrl: 'https://example.invalid/fonts');
      await m.ensureLoaded(1, 302);
      await m.preloadAround(1, 302, radius: 1);

      await Future<void>.delayed(const Duration(milliseconds: 200));

      expect(m.isLoaded(1, 301), isTrue);
      expect(m.isLoaded(1, 303), isTrue);
      expect(logger.errors, isEmpty);
    },
  );
}
