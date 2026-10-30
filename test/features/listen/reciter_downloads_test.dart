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

/// Saves a tiny file and records each address asked for.
class _RecordingNetwork extends _FakeNetwork {
  _RecordingNetwork(this.urls);

  final List<String> urls;

  @override
  Future<Response> download(
    String urlPath,
    String savePath, {
    void Function(int received, int total)? onReceiveProgress,
    CancelToken? cancelToken,
  }) {
    urls.add(urlPath);
    return super.download(urlPath, savePath, cancelToken: cancelToken);
  }
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

  test('one juz: only its ayahs; the rest still streams', () async {
    await downloads().ready();
    await downloads().download('ar.alafasy', juz: 30);
    final juz30 = 6236 - juzFirstAyah[29] + 1;
    expect(network.requests, juz30);
    expect(downloads().juzComplete('ar.alafasy', 30), isTrue);
    expect(downloads().juzComplete('ar.alafasy', 29), isFalse);
    expect(state()!.complete, isFalse);
    expect(state()!.files, juz30);
    expect(downloads().localFile(114006, alafasy), isNotNull);
    expect(downloads().localFile(1001, alafasy), isNull);
  });

  test('one surah: only its ayahs, from its reciter\'s source; a juz it '
      'is part of not complete', () async {
    await downloads().ready();
    await downloads().download('ar.alafasy', surah: 112);
    expect(network.requests, 4);
    expect(downloads().surahComplete('ar.alafasy', 112), isTrue);
    expect(downloads().surahComplete('ar.alafasy', 113), isFalse);
    expect(downloads().juzComplete('ar.alafasy', 30), isFalse);
    expect(state()!.surah, 112);
    expect(downloads().localFile(112001, alafasy), isNotNull);
    expect(downloads().localFile(111005, alafasy), isNull);
    // Its juz then fetches only what is missing.
    network.requests = 0;
    await downloads().download('ar.alafasy', juz: 30);
    expect(network.requests, 6236 - juzFirstAyah[29] + 1 - 4);
  });

  test('a surah of an everyayah.com reciter: its files from there', () async {
    final urls = <String>[];
    container.dispose();
    container = ProviderContainer(
      overrides: [
        reciterAudioDirectoryProvider.overrideWith((ref) async => root),
        networkClientProvider.overrideWithValue(_RecordingNetwork(urls)),
      ],
    );
    await downloads().ready();
    await downloads().download('ar.banna', surah: 1);
    expect(urls, hasLength(7));
    expect(
      urls.first,
      'https://everyayah.com/data/mahmoud_ali_al_banna_32kbps/001001.mp3',
    );
    expect(downloads().surahComplete('ar.banna', 1), isTrue);
  });

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
