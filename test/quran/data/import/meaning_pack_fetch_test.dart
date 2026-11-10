// A pack's download through the app's network client: no network is
// "offline" (tried again when online); the server's refusal is an error.
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tahfeez_ai/core/networking/network_client.dart';
import 'package:tahfeez_ai/quran/data/import/meaning_pack_fetch.dart';
import 'package:tahfeez_ai/quran/data/import/meaning_pack_store.dart';

class _Client implements NetworkClient {
  _Client(this.fails);

  final DioException? fails;

  @override
  Future<Response> download(
    String urlPath,
    String savePath, {
    void Function(int received, int total)? onReceiveProgress,
    CancelToken? cancelToken,
  }) async {
    // (Half written, then failing.)
    File(savePath).writeAsStringSync('partial');
    if (fails case final e?) throw e;
    return Response(requestOptions: RequestOptions(path: urlPath));
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  final url = Uri.parse('https://example.org/pack.xz');
  late String path;

  setUp(() {
    final dir = Directory.systemTemp.createTempSync('fetch');
    addTearDown(() => dir.deleteSync(recursive: true));
    path = '${dir.path}/pack.xz.part';
  });

  DioException failure(DioExceptionType type, {int? status, Object? error}) =>
      DioException(
        requestOptions: RequestOptions(path: url.toString()),
        type: type,
        error: error,
        response: status == null
            ? null
            : Response(
                requestOptions: RequestOptions(path: url.toString()),
                statusCode: status,
              ),
      );

  test('downloaded', () async {
    await meaningPackFetch(_Client(null))(url, path);
    expect(File(path).existsSync(), isTrue);
  });

  for (final type in [
    DioExceptionType.connectionError,
    DioExceptionType.connectionTimeout,
    DioExceptionType.receiveTimeout,
  ]) {
    test('${type.name}: offline, nothing left behind', () async {
      await expectLater(
        meaningPackFetch(_Client(failure(type)))(url, path),
        throwsA(isA<MeaningPackOffline>()),
      );
      expect(File(path).existsSync(), isFalse);
    });
  }

  test('no route to the server (a socket error): offline', () async {
    await expectLater(
      meaningPackFetch(
        _Client(
          failure(
            DioExceptionType.unknown,
            error: const SocketException('Network is unreachable'),
          ),
        ),
      )(url, path),
      throwsA(isA<MeaningPackOffline>()),
    );
  });

  test(
    'the server says no (404: not published): an error, not offline',
    () async {
      await expectLater(
        meaningPackFetch(
          _Client(failure(DioExceptionType.badResponse, status: 404)),
        )(url, path),
        throwsA(
          isA<StateError>().having(
            (e) => e.message,
            'message',
            contains('404'),
          ),
        ),
      );
      expect(File(path).existsSync(), isFalse);
    },
  );
}
