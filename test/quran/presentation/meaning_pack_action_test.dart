// The translation, tafsir and word-meaning lists: each pack downloaded or
// deleted from its row; and, with no network, a short notice that English
// is shown until the packs can download.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tahfeez_ai/core/localization/generated/app_localizations.dart';
import 'package:tahfeez_ai/quran/application/meaning_packs.dart';
import 'package:tahfeez_ai/quran/data/import/meaning_pack_store.dart';
import 'package:tahfeez_ai/quran/presentation/meaning_pack_action.dart';
import 'package:tahfeez_ai/quran/presentation/meaning_packs_layer.dart';

/// Records what the rows ask for.
class _Packs extends MeaningPacksController {
  _Packs(this.initial);

  final MeaningPacksState initial;
  final asked = <String>[];

  @override
  MeaningPacksState build() => initial;

  @override
  Future<void> download(MeaningPackKind kind, String id) async =>
      asked.add('download $id');

  @override
  Future<void> delete(MeaningPackKind kind, String id) async =>
      asked.add('delete $id');

  @override
  Future<void> retry() async => asked.add('retry');

  void set(MeaningPacksState next) => state = next;
}

void main() {
  late _Packs packs;

  Future<void> pump(
    WidgetTester tester, {
    MeaningPacksState state = const MeaningPacksState(),
    Widget? child,
  }) async {
    packs = _Packs(state);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          meaningPacksProvider.overrideWith(() => packs),
          meaningPackInfoProvider(MeaningPackKind.translation).overrideWith(
            (ref) async => {
              'en-rowwad': (status: MeaningPackStatus.builtIn, bytes: null),
              'fr-noor': (status: MeaningPackStatus.installed, bytes: 345216),
              'de-rowwad': (
                status: MeaningPackStatus.notInstalled,
                bytes: 1147076,
              ),
              'ur-junagarhi': (
                status: MeaningPackStatus.downloading,
                bytes: 1147076,
              ),
            },
          ),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body:
                child ??
                Column(
                  children: [
                    for (final id in [
                      'en-rowwad',
                      'fr-noor',
                      'de-rowwad',
                      'ur-junagarhi',
                    ])
                      MeaningPackAction(
                        key: ValueKey(id),
                        kind: MeaningPackKind.translation,
                        id: id,
                      ),
                  ],
                ),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  Finder within(String id, Finder f) =>
      find.descendant(of: find.byKey(ValueKey(id)), matching: f);

  testWidgets('built in: nothing to do', (tester) async {
    await pump(tester);
    expect(within('en-rowwad', find.byType(IconButton)), findsNothing);
  });

  testWidgets('on the phone: deleted with a tap', (tester) async {
    await pump(tester);
    await tester.tap(
      within('fr-noor', find.byKey(const ValueKey('meaning-pack-delete'))),
    );
    expect(packs.asked, ['delete fr-noor']);
  });

  testWidgets('not on the phone: its size, and downloaded with a tap', (
    tester,
  ) async {
    await pump(tester);
    expect(within('de-rowwad', find.text('1.1 MB')), findsOneWidget);
    await tester.tap(
      within('de-rowwad', find.byKey(const ValueKey('meaning-pack-download'))),
    );
    expect(packs.asked, ['download de-rowwad']);
  });

  testWidgets('downloading: a spinner, no button', (tester) async {
    await pump(tester);
    expect(
      within(
        'ur-junagarhi',
        find.byKey(const ValueKey('meaning-pack-downloading')),
      ),
      findsOneWidget,
    );
    expect(within('ur-junagarhi', find.byType(IconButton)), findsNothing);
  });

  testWidgets('in use but waiting for the network: a tap tries again (not '
      'kept as a download of its own)', (tester) async {
    await pump(
      tester,
      state: const MeaningPacksState(
        missing: {'translation:de-rowwad'},
        waitingForNetwork: true,
      ),
    );
    await tester.tap(
      within('de-rowwad', find.byKey(const ValueKey('meaning-pack-download'))),
    );
    expect(packs.asked, ['retry']);
  });

  test('sizes: megabytes to a tenth, kilobytes whole', () {
    expect(meaningPackSize(345216), '345 KB');
    expect(meaningPackSize(1147076), '1.1 MB');
  });

  testWidgets('no network: said once, for a few seconds', (tester) async {
    await pump(
      tester,
      child: const MeaningPacksLayer(child: SizedBox.expand()),
    );
    final notice = find.byKey(const ValueKey('meaning-packs-offline'));
    expect(notice, findsNothing);

    packs.set(const MeaningPacksState(waitingForNetwork: true));
    await tester.pumpAndSettle();
    expect(notice, findsOneWidget);
    expect(find.textContaining('English is shown'), findsOneWidget);

    await tester.pump(MeaningPacksLayer.offlineNotice);
    await tester.pumpAndSettle();
    expect(notice, findsNothing);

    // Waiting again later: not said again.
    packs.set(const MeaningPacksState());
    await tester.pump();
    packs.set(const MeaningPacksState(waitingForNetwork: true));
    await tester.pumpAndSettle();
    expect(notice, findsNothing);
  });
}
