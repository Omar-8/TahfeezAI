import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tahfeez_ai/core/localization/generated/app_localizations.dart';
import 'package:tahfeez_ai/core/theme/components/components.dart';
import 'package:tahfeez_ai/features/quran/presentation/tabs/topics_index_tab.dart';
import 'package:tahfeez_ai/quran/application/quran_topics_provider.dart';
import 'package:tahfeez_ai/quran/domain/quran_topics.dart';

import '../../../test_helpers/widget_test_overrides.dart';

/// Content-shaped loading placeholders (owner, 2026-11-14): a list's rows,
/// a grid's cards, a card's lines — laid out whatever the width and text
/// size, still with the phone's animations off, and shown by the screens
/// while their content loads.
void main() {
  final skeletons = <String, Widget>{
    'list': const TahfeezListSkeleton(),
    'grid': const TahfeezGridSkeleton(),
    'card': const SingleChildScrollView(
      child: TahfeezCard(child: TahfeezCardSkeleton(lines: 3, tall: 72)),
    ),
    'cards': const TahfeezCardsSkeleton(),
  };

  for (final MapEntry(key: name, value: skeleton) in skeletons.entries) {
    for (final (width, scale) in [(400.0, 1.0), (320.0, 2.0)]) {
      testWidgets('$name: laid out at $width px, text ×$scale', (tester) async {
        tester.view.physicalSize = Size(width, 700);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        await tester.pumpWidget(
          MaterialApp(
            home: MediaQuery(
              data: MediaQueryData(
                size: Size(width, 700),
                textScaler: TextScaler.linear(scale),
              ),
              child: Scaffold(body: skeleton),
            ),
          ),
        );
        await tester.pump(const Duration(milliseconds: 300));
        expect(tester.takeException(), isNull);
        expect(find.byType(TahfeezSkeleton), findsWidgets);
      });
    }

    testWidgets('$name: still, the phone\'s animations off', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(disableAnimations: true),
            child: Scaffold(body: skeleton),
          ),
        ),
      );
      // Would time out while it pulsed.
      await tester.pumpAndSettle();
    });
  }

  testWidgets('the Topics tab loading: its grid of cards', (tester) async {
    final never = Completer<QuranTopics>();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...tahfeezWidgetTestOverrides(),
          quranTopicsProvider.overrideWith((ref) => never.future),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(body: TopicsIndexTab(onSelect: (_) {})),
        ),
      ),
    );
    await tester.pump();
    expect(find.byType(TahfeezGridSkeleton), findsOne);
    expect(find.byType(TahfeezLoadingView), findsNothing);
    // (Loaded: the groups.)
    never.complete(
      QuranTopics.fromJson(
        jsonDecode(File('assets/quran/topics.json').readAsStringSync())
            as Map<String, Object?>,
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(TahfeezGridSkeleton), findsNothing);
    expect(find.byKey(const ValueKey('topic-group-card-prophets')), findsOne);
  });
}
