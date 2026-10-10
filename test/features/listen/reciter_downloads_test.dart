import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tahfeez_ai/core/core_providers.dart';
import 'package:tahfeez_ai/core/networking/network_client.dart';
import 'package:tahfeez_ai/features/listen/application/reciter_downloads.dart';
import 'package:tahfeez_ai/features/listen/domain/quran_audio_sources.dart';

/// "Downloads" by writing a tiny file; [failFrom] on, every request fails.
class _FakeNetwork implements NetworkClient {
  int requests = 0;
  int? failFrom;

  @override
  Future<Response> download(
    String urlPath,
    String savePath, {
    void Function(int received, int total)? onReceiveProgress,
    CancelToken? cancelToken,
  }) async {
    requests++;
    if (failFrom != null && requests >= failFrom!) {
      throw DioException(requestOptions: RequestOptions(path: urlPath));
    }
    await File(savePath).writeAsBytes(const [1]);
    return Response(requestOptions: RequestOptions(path: urlPath));
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  late Directory root;
  late _FakeNetwork network;
  late ProviderContainer container;
  final alafasy = reciterFor('ar.alafasy');

  setUp(() {
    root = Directory.systemTemp.createTempSync('reciter_downloads');
    network = _FakeNetwork();
    container = ProviderContainer(
      overrides: [
        reciterAudioDirectoryProvider.overrideWith((ref) async => root),
        networkClientProvider.overrideWithValue(network),
      ],
    );
  });
  tearDown(() {
    container.dispose();
    root.deleteSync(recursive: true);
  });

  ReciterDownloads downloads() =>
      container.read(reciterDownloadsProvider.notifier);
  ReciterDownload? state() =>
      container.read(reciterDownloadsProvider)['ar.alafasy'];

  test('every ayah downloaded, then played from the phone; deleted', () async {
    await downloads().ready();
    expect(downloads().localFile(1001, alafasy), isNull);

    await downloads().download('ar.alafasy');
    expect(state()!.complete, isTrue);
    expect(network.requests, 6236);
    expect(downloads().localFile(114006, alafasy), endsWith('6236.mp3'));

    await downloads().delete('ar.alafasy');
    expect(state(), isNull);
    expect(downloads().localFile(1001, alafasy), isNull);
    expect(Directory('${root.path}/ar.alafasy').existsSync(), isFalse);
  }, timeout: const Timeout(Duration(minutes: 2)));

  test('a failed download stops, keeps what it has, and resumes', () async {
    await downloads().ready();
    network.failFrom = 101;
    await downloads().download('ar.alafasy');
    expect(state()!.failed, isTrue);
    expect(state()!.complete, isFalse);
    final kept = state()!.files;
    expect(kept, greaterThanOrEqualTo(90));

    network.failFrom = null;
    network.requests = 0;
    await downloads().download('ar.alafasy');
    expect(state()!.complete, isTrue);
    expect(network.requests, 6236 - kept, reason: 'only what was missing');
  }, timeout: const Timeout(Duration(minutes: 2)));
}
