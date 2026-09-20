import 'package:dio/dio.dart';

/// Thin abstraction over the HTTP client Tahfeez uses to fetch optional
/// resources (translation/tafsir/recitation/font manifests and downloads,
/// and — later — optional AI services).
///
/// Domain/data code depends on this interface, not on `package:dio`
/// directly, so networking can be mocked in tests and so retry/caching/auth
/// policy can change in one place. Per `docs/PROJECT_BRIEF.md`, the network
/// is only ever used for *optional* resources and enhancements — nothing
/// behind this interface may be on the critical path for opening the app or
/// reading already-installed content.
abstract class NetworkClient {
  Future<Response<T>> get<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
    CancelToken? cancelToken,
  });

  /// Streams a file download, reporting `(received, total)` bytes via
  /// [onReceiveProgress]. `total` is `-1` when the server does not report
  /// `Content-Length`.
  Future<Response> download(
    String urlPath,
    String savePath, {
    void Function(int received, int total)? onReceiveProgress,
    CancelToken? cancelToken,
  });

  /// Fetches [path]'s raw response body as bytes, held in memory — for
  /// small-to-medium binary resources (e.g. a single font file) where
  /// there is no platform filesystem to [download] to (Web has none), so
  /// the caller (not this client) decides what to do with the bytes.
  Future<Response<List<int>>> getBytes(String path, {CancelToken? cancelToken});
}

class DioNetworkClient implements NetworkClient {
  DioNetworkClient({Dio? dio}) : _dio = dio ?? Dio();

  final Dio _dio;

  @override
  Future<Response<T>> get<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
    CancelToken? cancelToken,
  }) {
    return _dio.get<T>(
      path,
      queryParameters: queryParameters,
      cancelToken: cancelToken,
    );
  }

  @override
  Future<Response> download(
    String urlPath,
    String savePath, {
    void Function(int received, int total)? onReceiveProgress,
    CancelToken? cancelToken,
  }) {
    return _dio.download(
      urlPath,
      savePath,
      onReceiveProgress: onReceiveProgress,
      cancelToken: cancelToken,
    );
  }

  @override
  Future<Response<List<int>>> getBytes(
    String path, {
    CancelToken? cancelToken,
  }) {
    return _dio.get<List<int>>(
      path,
      options: Options(responseType: ResponseType.bytes),
      cancelToken: cancelToken,
    );
  }
}
