import 'package:drift/native.dart';
import 'package:tahfeez_ai/core/localization/generated/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tahfeez_ai/core/theme/app_spacing.dart';
import 'package:tahfeez_ai/quran/application/canonical_ayah_word_text.dart';
import 'package:tahfeez_ai/wbw/application/wbw_preferences_controller.dart';
import 'package:tahfeez_ai/wbw/data/wbw_database.dart';
import 'package:tahfeez_ai/wbw/presentation/word_detail_sheet.dart';
import 'package:tahfeez_ai/wbw/wbw_providers.dart';

import 'package:tahfeez_ai/core/storage/browser_storage.dart';
import 'package:tahfeez_ai/core/storage/storage_providers.dart';
import 'package:tahfeez_ai/features/mushaf/application/mushaf_word_overlay.dart';
import 'package:tahfeez_ai/features/recitation/application/hifz_controller.dart';

import '../wbw_test_fixtures.dart';

void main() {
  Widget wrap(WbwDatabase db, {String? selectedPackId}) {
    return ProviderScope(
      overrides: [
        wbwDatabaseProvider.overrideWith((ref) => db),
        canonicalAyahWordTextProvider(
          ayahId: 1001,
          wordIndex: 0,
        ).overrideWith((ref) => 'lafz'),
        if (selectedPackId != null)
          wbwSelectedPackControllerProvider.overrideWith(
            () => _FixedSelectedPack(selectedPackId),
          ),
      ],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => showWordDetailSheet(
                context,
                wordRef: (ayahId: 1001, wordIndex: 0),
              ),
              child: const Text('open sheet'),
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('always shows the Arabic word and its location', (tester) async {
    final db = WbwDatabase(NativeDatabase.memory());
    addTearDown(db.close);

    await tester.pumpWidget(wrap(db));
    await tester.tap(find.text('open sheet'));
    await tester.pumpAndSettle();

    expect(find.text('lafz'), findsOneWidget);
    expect(find.textContaining('Ayah 1:1'), findsOneWidget);
    // Closed by the ✕ in its header, every tappable 48 × 48.
    expect(find.byKey(const ValueKey('sheet-close')), findsOneWidget);
    final semantics = tester.ensureSemantics();
    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    semantics.dispose();
  });

  testWidgets('shows an install hint with no active word-by-word pack', (
    tester,
  ) async {
    final db = WbwDatabase(NativeDatabase.memory());
    addTearDown(db.close);

    await tester.pumpWidget(wrap(db));
    await tester.tap(find.text('open sheet'));
    await tester.pumpAndSettle();

    expect(
      find.textContaining('Install a word-by-word language pack'),
      findsOneWidget,
    );
  });

  testWidgets(
    'shows translation and transliteration once a pack is installed and active',
    (tester) async {
      final db = WbwDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      final container = ProviderContainer(
        overrides: [wbwDatabaseProvider.overrideWith((ref) => db)],
      );
      addTearDown(container.dispose);
      await container
          .read(wbwRepositoryProvider)
          .installPack(buildTestWbwPack(), buildTestWbwWords());

      await tester.pumpWidget(wrap(db, selectedPackId: testWbwPackId));
      await tester.tap(find.text('open sheet'));
      await tester.pumpAndSettle();

      expect(find.text('word'), findsOneWidget);
      expect(
        find.text('lafz'),
        findsWidgets,
      ); // both the tapped word + transliteration
    },
  );

  for (final scale in [1.0, 2.0]) {
    testWidgets('a word\'s meaning loading: a placeholder as tall as the '
        'meaning (text ×$scale) — not the screen\'s loading view, which grew '
        'the sheet for a moment on each mistake (owner, 2026-11-14)', (
      tester,
    ) async {
      late double skeleton, meaning;
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: MediaQueryData(textScaler: TextScaler.linear(scale)),
            child: Builder(
              builder: (context) {
                final theme = Theme.of(context);
                return Scaffold(
                  body: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const WordMeaningSkeleton(key: ValueKey('s')),
                      Column(
                        key: const ValueKey('m'),
                        crossAxisAlignment: CrossAxisAlignment.start,
                        spacing: TahfeezSpacing.xs,
                        children: [
                          Text('lafz', style: theme.textTheme.bodyMedium),
                          Text('word', style: theme.textTheme.bodyLarge),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
      );
      skeleton = tester.getSize(find.byKey(const ValueKey('s'))).height;
      meaning = tester.getSize(find.byKey(const ValueKey('m'))).height;
      expect(skeleton, moreOrLessEquals(meaning, epsilon: 3));
    });
  }

  testWidgets('from one mistake to the next: the sheet as tall as the new '
      'word all along — not the taller of the two for a moment (flicker; '
      'owner, 2026-11-14)', (tester) async {
    final db = WbwDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          wbwDatabaseProvider.overrideWith((ref) => db),
          browserStorageProvider.overrideWithValue(_NoStorage()),
          for (var i = 0; i < 3; i++)
            canonicalAyahWordTextProvider(
              ayahId: 1001,
              wordIndex: i,
            ).overrideWith(
              // The first word's card much taller than the second's.
              (ref) => i == 0 ? List.filled(40, 'word0').join(' ') : 'word$i',
            ),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: Consumer(
              builder: (context, ref, _) => TextButton(
                onPressed: () {
                  ref
                      .read(mushafWordOverlayProvider.notifier)
                      .set(
                        const MushafWordOverlay(
                          first: (ayahId: 1001, wordIndex: 0),
                          last: (ayahId: 1001, wordIndex: 2),
                          hideUnrevealed: false,
                          marks: {
                            (ayahId: 1001, wordIndex: 0): MushafWordMark.wrong,
                            (ayahId: 1001, wordIndex: 1): MushafWordMark.wrong,
                            (ayahId: 1001, wordIndex: 2): MushafWordMark.wrong,
                          },
                        ),
                      );
                  showWordDetailSheet(
                    context,
                    wordRef: (ayahId: 1001, wordIndex: 0),
                  );
                },
                child: const Text('open sheet'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open sheet'));
    await tester.pumpAndSettle();
    final swipe = find.byKey(const ValueKey('word-mistake-swipe'));
    await tester.tap(find.byKey(const ValueKey('word-next-mistake')));
    final heights = <double>[];
    for (var f = 0; f < 30; f++) {
      await tester.pump(const Duration(milliseconds: 16));
      heights.add(tester.getSize(swipe).height);
    }
    await tester.pumpAndSettle();
    final settled = tester.getSize(swipe).height;
    expect(heights, everyElement(moreOrLessEquals(settled, epsilon: 0.5)));
    expect(tester.takeException(), isNull);

    // The mistake hints over the page turned off from the sheet (owner,
    // 2026-11-17), and on again.
    final container = ProviderScope.containerOf(
      tester.element(find.text('open sheet')),
    );
    bool hints() => container.read(hifzSettingsProvider).mistakeHints;
    final toggle = find.byKey(const ValueKey('word-mistake-hints-switch'));
    expect(hints(), isTrue);
    await tester.ensureVisible(toggle);
    await tester.tap(toggle);
    await tester.pumpAndSettle();
    expect(hints(), isFalse);
    await tester.tap(toggle);
    await tester.pumpAndSettle();
    expect(hints(), isTrue);
  });

  testWidgets('a recitation\'s mistakes: swiped through as the Mushaf\'s '
      'pages turn — right, the next; left, the previous', (tester) async {
    final db = WbwDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          wbwDatabaseProvider.overrideWith((ref) => db),
          browserStorageProvider.overrideWithValue(_NoStorage()),
          for (var i = 0; i < 3; i++)
            canonicalAyahWordTextProvider(
              ayahId: 1001,
              wordIndex: i,
            ).overrideWith((ref) => 'word$i'),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: Consumer(
              builder: (context, ref, _) => TextButton(
                onPressed: () {
                  ref
                      .read(mushafWordOverlayProvider.notifier)
                      .set(
                        const MushafWordOverlay(
                          first: (ayahId: 1001, wordIndex: 0),
                          last: (ayahId: 1001, wordIndex: 2),
                          hideUnrevealed: false,
                          marks: {
                            (ayahId: 1001, wordIndex: 0): MushafWordMark.wrong,
                            (ayahId: 1001, wordIndex: 1): MushafWordMark.wrong,
                            (ayahId: 1001, wordIndex: 2): MushafWordMark.wrong,
                          },
                        ),
                      );
                  showWordDetailSheet(
                    context,
                    wordRef: (ayahId: 1001, wordIndex: 0),
                  );
                },
                child: const Text('open sheet'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open sheet'));
    await tester.pumpAndSettle();
    final count = find.byKey(const ValueKey('word-mistake-count'));
    String shown() => tester.widget<Text>(count).data!;
    expect(shown(), '1 / 3');
    final swipe = find.byKey(const ValueKey('word-mistake-swipe'));

    await tester.fling(swipe, const Offset(300, 0), 1000);
    await tester.pumpAndSettle();
    expect(shown(), '2 / 3');
    expect(find.text('word1'), findsOneWidget);
    await tester.fling(swipe, const Offset(300, 0), 1000);
    await tester.pumpAndSettle();
    expect(shown(), '3 / 3');
    // Past the last: nothing.
    await tester.fling(swipe, const Offset(300, 0), 1000);
    await tester.pumpAndSettle();
    expect(shown(), '3 / 3');
    await tester.fling(swipe, const Offset(-300, 0), 1000);
    await tester.pumpAndSettle();
    expect(shown(), '2 / 3');
  });
}

class _NoStorage implements BrowserStorage {
  @override
  Future<void> clearExcept(Set<String> keep) async {}
  @override
  Future<Map<String, Object?>> readAll() async => const {};
  @override
  Future<void> writeAll(Map<String, Object?> values) async {}
  @override
  Future<String?> getString(String key) async => null;
  @override
  Future<void> setString(String key, String value) async {}
  @override
  Future<bool?> getBool(String key) async => null;
  @override
  Future<void> setBool(String key, bool value) async {}
  @override
  Future<void> remove(String key) async {}
}

class _FixedSelectedPack extends WbwSelectedPackController {
  _FixedSelectedPack(this._fixed);

  final String _fixed;

  @override
  String? build() => _fixed;
}
