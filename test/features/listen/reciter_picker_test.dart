import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tahfeez_ai/core/core_providers.dart';
import 'package:tahfeez_ai/core/localization/generated/app_localizations.dart';
import 'package:tahfeez_ai/core/networking/network_client.dart';
import 'package:tahfeez_ai/features/listen/application/reciter_controller.dart';
import 'package:tahfeez_ai/features/listen/application/reciter_downloads.dart';
import 'package:tahfeez_ai/features/listen/presentation/listen_sheet.dart';
import 'package:tahfeez_ai/features/quran/application/quran_index_providers.dart';
import 'package:tahfeez_ai/quran/domain/models/surah_models.dart';

/// "Downloads" by writing a tiny file, recording each address.
class _FakeNetwork implements NetworkClient {
  final urls = <String>[];

  @override
  Future<Response> download(
    String urlPath,
    String savePath, {
    void Function(int received, int total)? onReceiveProgress,
    CancelToken? cancelToken,
  }) async {
    urls.add(urlPath);
    await File(savePath).writeAsBytes(const [1]);
    return Response(requestOptions: RequestOptions(path: urlPath));
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  testWidgets('typing finds a reciter by English or Arabic name', (
    tester,
  ) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Builder(
            builder: (context) => TextButton(
              onPressed: () => showReciterSheet(context),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    final search = find.byKey(const ValueKey('reciter-search'));

    await tester.enterText(search, 'husary');
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('reciter-ar.husary')), findsOneWidget);
    expect(find.byKey(const ValueKey('reciter-ar.alafasy')), findsNothing);

    // Arabic, without the vowel marks the name is written with.
    await tester.enterText(search, 'المنشاوي');
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('reciter-ar.minshawi')), findsOneWidget);
    expect(find.byKey(const ValueKey('reciter-ar.husary')), findsNothing);

    await tester.enterText(search, 'zzz');
    await tester.pumpAndSettle();
    expect(find.text('No reciter by that name'), findsOneWidget);

    await tester.enterText(search, 'alafasy');
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('reciter-ar.alafasy')));
    await tester.pumpAndSettle();
    expect(container.read(reciterProvider), 'ar.alafasy');
  });

  testWidgets('a reciter downloads by juz or, in its own tab, by surah', (
    tester,
  ) async {
    final root = Directory.systemTemp.createTempSync('reciter_picker');
    addTearDown(() => root.deleteSync(recursive: true));
    final network = _FakeNetwork();
    final container = ProviderContainer(
      overrides: [
        reciterAudioDirectoryProvider.overrideWith((ref) async => root),
        networkClientProvider.overrideWithValue(network),
        indexedSurahsProvider.overrideWith(
          (ref) async => [
            for (var n = 1; n <= 114; n++)
              IndexedSurah(
                surah: Surah(
                  surahNo: n,
                  ayahCount: 1,
                  revelationOrder: n,
                  rukusCount: 1,
                  revelationType: RevelationType.meccan,
                ),
                arabicName: null,
                localizedName: n == 112 ? 'Al-Ikhlas' : 'Surah $n',
              ),
          ],
        ),
      ],
    );
    addTearDown(container.dispose);
    await tester.runAsync(
      () => container.read(reciterDownloadsProvider.notifier).ready(),
    );
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Builder(
            builder: (context) => TextButton(
              onPressed: () => showReciterSheet(context),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('reciter-search')),
      'banna',
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('reciter-download-ar.banna')));
    await tester.pumpAndSettle();

    // The whole Quran on top; the juz first.
    expect(find.byKey(const ValueKey('download-whole')), findsOneWidget);
    expect(find.byKey(const ValueKey('download-juz-1')), findsOneWidget);
    expect(find.byKey(const ValueKey('download-surah-1')), findsNothing);

    await tester.tap(find.byKey(const ValueKey('download-tab-surah')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('download-juz-1')), findsNothing);
    expect(find.text('1. Surah 1'), findsOneWidget);
    final ikhlas = find.byKey(const ValueKey('download-surah-112'));
    await tester.scrollUntilVisible(
      ikhlas,
      300,
      scrollable: find
          .descendant(
            of: find.byType(TabBarView),
            matching: find.byType(Scrollable),
          )
          .last,
    );
    expect(
      find.descendant(of: ikhlas, matching: find.text('112. Al-Ikhlas')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: ikhlas, matching: find.textContaining('MB')),
      findsOneWidget,
    );

    await tester.ensureVisible(ikhlas);
    await tester.pumpAndSettle();
    await tester.tap(ikhlas);
    // The download writes real files: real time, a little at a time.
    bool done() {
      final d = container.read(reciterDownloadsProvider)['ar.banna'];
      return d != null && !d.downloading && d.files >= 4;
    }

    for (var i = 0; i < 60 && !done(); i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)),
      );
      await tester.pump();
    }
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 200)),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('download-whole')), findsNothing);
    expect(network.urls, [
      for (var a = 1; a <= 4; a++)
        'https://everyayah.com/data/mahmoud_ali_al_banna_32kbps/11200$a.mp3',
    ]);
    expect(
      container
          .read(reciterDownloadsProvider.notifier)
          .surahComplete('ar.banna', 112),
      isTrue,
    );
  });

  for (final (name, size, scale, columns) in [
    ('phone', const Size(360, 780), 1.0, 1),
    ('phone, text at 2x', const Size(360, 780), 2.0, 1),
    ('phone on its side', const Size(780, 360), 1.0, 2),
    ('tablet', const Size(1000, 1300), 1.0, 3),
  ]) {
    testWidgets('the surahs to download: $columns column(s), $name', (
      tester,
    ) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final container = ProviderContainer(
        overrides: [
          indexedSurahsProvider.overrideWith(
            (ref) async => [
              for (var n = 1; n <= 114; n++)
                IndexedSurah(
                  surah: Surah(
                    surahNo: n,
                    ayahCount: 1,
                    revelationOrder: n,
                    rukusCount: 1,
                    revelationType: RevelationType.meccan,
                  ),
                  arabicName: null,
                  // A long name: wraps rather than overflows.
                  localizedName: n == 2 ? 'Al-Baqara (The Cow), long' : 'S $n',
                ),
            ],
          ),
        ],
      );
      addTearDown(container.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Builder(
              builder: (context) => MediaQuery.withClampedTextScaling(
                minScaleFactor: scale,
                maxScaleFactor: scale,
                child: TextButton(
                  onPressed: () => showReciterSheet(context),
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('reciter-search')),
        'banna',
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('reciter-download-ar.banna')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('download-tab-surah')));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: 'no overflow');

      final first = tester.getRect(
        find.byKey(const ValueKey('download-surah-1')),
      );
      final second = tester.getRect(
        find.byKey(const ValueKey('download-surah-2')),
      );
      if (columns == 1) {
        expect(second.top, greaterThanOrEqualTo(first.bottom));
      } else {
        // Side by side, the row as tall as its taller entry.
        expect(second.top, first.top);
        expect(second.height, first.height);
        final next = tester.getRect(
          find.byKey(ValueKey('download-surah-${columns + 1}')),
        );
        expect(next.top, greaterThanOrEqualTo(first.bottom));
      }
    });
  }
}
