import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tahfeez_ai/core/localization/generated/app_localizations.dart';
import 'package:tahfeez_ai/core/localization/supported_locales.dart';
import 'package:tahfeez_ai/core/ui/back_to_exit.dart';
import 'package:tahfeez_ai/features/mushaf/presentation/ayah_view_parts.dart';
import 'package:tahfeez_ai/features/quran/presentation/ayah_topics_section.dart';
import 'package:tahfeez_ai/features/quran/presentation/tabs/topics_index_tab.dart';
import 'package:tahfeez_ai/quran/application/quran_topics_provider.dart';
import 'package:tahfeez_ai/quran/domain/models/ayah_models.dart';
import 'package:tahfeez_ai/quran/domain/models/quran_location.dart';
import 'package:tahfeez_ai/quran/domain/quran_topics.dart';
import 'package:tahfeez_ai/quran/domain/quran_ayah_numbers.dart'
    show surahAyahCounts;

import '../../../test_helpers/widget_test_overrides.dart';

/// The Quran tab's Topics: the Quranic Arabic Corpus's concepts in eleven
/// groups, each named in every interface language, each ayah a real one —
/// and the tab: groups, a group's topics, a topic's ayahs, an ayah opened.
void main() {
  final topics = QuranTopics.fromJson(
    jsonDecode(File('assets/quran/topics.json').readAsStringSync())
        as Map<String, Object?>,
  );

  test('twelve groups, 252 topics, each in one group; not Allah; one '
      'topic a prophet: Israel Ya\'qub, the Messiah Isa, Ahmad Muhammad', () {
    expect(topics.groups.map((g) => g.id), [
      'prophets', 'stories', 'unseen', 'hereafter', 'people', 'places', //
      'sky',
      'nature', 'body', 'times', 'scriptures', 'things',
    ]);
    expect(topics.concepts, hasLength(252));
    expect(topics.concepts['allah'], isNull);
    final placed = [for (final g in topics.groups) ...g.concepts];
    expect(placed, hasLength(252));
    expect(placed.map((c) => c.id).toSet(), hasLength(252));
    // The prophet Israel: Ya'qub, with the ayahs where إسرائيل is he; the
    // Children of Israel their own topic.
    expect(topics.concepts['israel'], isNull);
    expect(topics.concepts['yaqub']!.arabic, 'يعقوب');
    expect(topics.concepts['yaqub']!.ayahs, containsAll([3093, 19058]));
    expect(topics.concepts['yaqub']!.ayahs, hasLength(18));
    expect(topics.concepts['children-of-israel']!.ayahs, hasLength(40));
    expect(topics.concepts['messiah'], isNull);
    expect(topics.concepts['ahmad'], isNull);
    expect(topics.concepts['jesus']!.ayahs, containsAll([3045, 4157]));
    expect(topics.concepts['muhammad']!.ayahs, contains(61006));
  });

  test('every topic named in every interface language; its ayahs real', () {
    for (final c in topics.concepts.values) {
      for (final locale in kTahfeezSupportedLocales) {
        expect(
          c.names[locale.languageCode]?.trim(),
          isNotEmpty,
          reason: '${c.id} ${locale.languageCode}',
        );
      }
      expect(c.ayahs, isNotEmpty, reason: c.id);
      for (final a in c.ayahs) {
        final surah = a ~/ 1000, verse = a % 1000;
        expect(surah, inInclusiveRange(1, 114), reason: '${c.id} $a');
        expect(
          verse,
          inInclusiveRange(1, surahAyahCounts[surah - 1]),
          reason: '${c.id} $a',
        );
      }
    }
  });

  test('as the corpus tags them: Yusuf, the hoopoe, Hell', () {
    expect(topics.concepts['yusuf']!.ayahs, contains(12004));
    // A story told in one passage: the whole passage (TahfeezAI's ranges).
    expect(topics.concepts['hoopoe']!.ayahs, [
      for (var a = 20; a <= 28; a++) 27000 + a,
    ]);
    expect(topics.concepts['companions-of-the-cave']!.ayahs, [
      for (var a = 9; a <= 26; a++) 18000 + a,
    ]);
    expect(topics.concepts['dhul-qarnayn']!.ayahs, [
      for (var a = 83; a <= 98; a++) 18000 + a,
    ]);
    expect(
      topics.concepts['sheba']!.ayahs,
      containsAll([27022, 27044, 34015, 34021]),
    );
    expect(topics.concepts['hell']!.ayahs, hasLength(79));
    expect(topics.concepts['hell']!.arabic, 'جهنم');
    expect(topics.concepts['lamp']!.arabic, 'المصباح');
    // A group's topics: the most mentioned first — the prophets in the
    // order they were sent, Adam to Muhammad ﷺ.
    final prophets = topics.groups.first.concepts.map((c) => c.id).toList();
    expect(prophets, [
      'adam', 'idris', 'nuh', 'hud', 'salih', 'ibrahim', 'lut', 'ishmael', //
      'isaac', 'yaqub', 'yusuf', 'ayyub', 'shuayb', 'musa', 'harun', 'david',
      'solomon', 'elijah', 'elisha', 'yunus', 'uzair', 'zechariah', 'yahya',
      'jesus',
      'muhammad',
    ]);
    expect(topics.groups[4].concepts.first.id, 'pharaoh');
  });

  test('stories told in one passage (TahfeezAI\'s): each its whole '
      'passage, in the order they took place, named in every language', () {
    final stories = topics.groups[1];
    expect(stories.id, 'stories');
    expect(stories.concepts.map((c) => c.id), [
      'story-adam', 'story-nuh', 'story-ibrahim', 'story-yusuf', //
      'story-musa-birth', 'story-believer', 'story-khidr', 'story-sabbath',
      'story-yunus', 'story-maryam', 'story-town', 'story-two-gardens',
      'story-garden',
    ]);
    expect(topics.concepts['story-khidr']!.ayahs, [
      for (var a = 60; a <= 82; a++) 18000 + a,
    ]);
    expect(topics.concepts['story-khidr']!.arabic, 'موسى والخضر');
    expect(ayahRuns(topics.concepts['story-town']!.ayahs), [
      (first: 36013, last: 36029),
    ]);
  });

  group('the tab', () {
    QuranLocation? opened;

    Future<void> pump(
      WidgetTester tester, {
      String locale = 'en',
      double width = 400,
      double textScale = 1,
    }) async {
      opened = null;
      tester.view.physicalSize = Size(width, 820);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            ...tahfeezWidgetTestOverrides(),
            quranTopicsProvider.overrideWith((ref) async => topics),
            ayahCanonicalWordsProvider.overrideWith(
              (ref, id) async => [
                AyahWord(
                  ayahId: id,
                  scriptId: 1,
                  wordIndex: 0,
                  text: 'وَقَالَ',
                ),
              ],
            ),
          ],
          child: MaterialApp(
            locale: Locale(locale),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: TextScaler.linear(textScale)),
              child: child!,
            ),
            home: Scaffold(body: TopicsIndexTab(onSelect: (l) => opened = l)),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('groups → a group\'s topics → a topic\'s ayahs → an ayah '
        'opened; back a step at a time', (tester) async {
      await pump(tester);
      expect(find.text('Prophets'), findsOne);
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('topic-group-card-prophets')),
          matching: find.text('25 topics'),
        ),
        findsOne,
      );
      await tester.tap(find.byKey(const ValueKey('topic-group-card-prophets')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('topic-concept-nuh')), findsOne);
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('topic-concept-yusuf')),
        200,
      );
      await tester.ensureVisible(
        find.byKey(const ValueKey('topic-concept-yusuf')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('topic-concept-yusuf')));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<RichText>(
              find.descendant(
                of: find.byKey(const ValueKey('topic-title')),
                matching: find.byType(RichText),
              ),
            )
            .text
            .toPlainText(),
        // (The sign read as its words.)
        'Yusuf عليه السلام · 26 ayahs',
      );
      await tester.tap(find.byKey(const ValueKey('topic-ayah-12004')));
      expect(opened, QuranLocation.ayah(12, 4));

      await tester.tap(find.byKey(const ValueKey('topic-back')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('topic-concept-nuh')), findsOne);
      await tester.tap(find.byKey(const ValueKey('topic-back')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('topic-group-card-sky')), findsOne);
    });

    testWidgets('a passage (ayahs one after another): one card, its first '
        'and last ayah, "from … to" — opened, the whole run', (tester) async {
      await pump(tester);
      await tester.tap(find.byKey(const ValueKey('topic-group-card-people')));
      await tester.pumpAndSettle();
      final cave = find.byKey(
        const ValueKey('topic-concept-companions-of-the-cave'),
      );
      await tester.scrollUntilVisible(cave, 300);
      await tester.ensureVisible(cave);
      await tester.pumpAndSettle();
      await tester.tap(cave);
      await tester.pumpAndSettle();
      final card = find.byKey(const ValueKey('topic-passage-18009-18026'));
      expect(card, findsOne);
      expect(find.byKey(const ValueKey('topic-ayah-18010')), findsNothing);
      expect(
        find.descendant(of: card, matching: find.textContaining('9–26')),
        findsOne,
      );
      await tester.tap(card);
      expect(opened, const QuranLocation.ayahRange(18, 9, 26));
    });

    testWidgets('search: topics found by name — the app\'s language, '
        'English, Arabic (its letters\' forms aside) — each with its group; '
        'one opened, back to its group', (tester) async {
      await pump(tester);
      final field = find.byKey(const ValueKey('topics-search'));
      expect(field, findsOne);
      await tester.enterText(field, 'yus');
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('topic-concept-yusuf')), findsOne);
      expect(find.text('Prophets · 26 ayahs'), findsOne);
      expect(find.byKey(const ValueKey('topic-group-card-sky')), findsNothing);
      // In Arabic, its hamza not typed.
      await tester.enterText(field, 'ابراهيم');
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('topic-concept-ibrahim')), findsOne);
      // Nothing found.
      await tester.enterText(field, 'zzzz');
      await tester.pumpAndSettle();
      expect(find.text('No results for "zzzz".'), findsOne);
      // Opened, then back: its group.
      await tester.enterText(field, 'hoopoe');
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('topic-concept-hoopoe')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('topic-ayah-27020')), findsNothing);
      expect(find.byKey(const ValueKey('topic-passage-27020-27028')), findsOne);
      await tester.tap(find.byKey(const ValueKey('topic-back')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('topic-concept-hoopoe')), findsOne);
    });

    testWidgets('search in Japanese: by its Japanese name', (tester) async {
      await pump(tester, locale: 'ja');
      await tester.enterText(
        find.byKey(const ValueKey('topics-search')),
        'ヤツガシラ',
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('topic-concept-hoopoe')), findsOne);
    });

    testWidgets('in Japanese: the group and the topic named in it, the '
        'Quranic name beside', (tester) async {
      await pump(tester, locale: 'ja');
      await tester.tap(find.byKey(const ValueKey('topic-group-card-nature')));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('topic-concept-hoopoe')),
        300,
      );
      expect(find.text('ヤツガシラ'), findsOne);
      expect(find.text('هدهد'), findsOne);
    });

    String plain(WidgetTester tester, Finder f) => tester
        .widget<RichText>(
          find.descendant(of: f, matching: find.byType(RichText)),
        )
        .text
        .toPlainText(includeSemanticsLabels: false);

    for (final (locale, ltr) in [('en', true), ('ur', false)]) {
      testWidgets('$locale: the Quranic name at the card\'s end, its sign '
          'beside it, in every language — the same letters too (Urdu '
          '«نوح»); the name in the app\'s language alone at the start', (
        tester,
      ) async {
        await pump(tester, locale: locale);
        await tester.tap(
          find.byKey(const ValueKey('topic-group-card-prophets')),
        );
        await tester.pumpAndSettle();
        final row = find.byKey(const ValueKey('topic-concept-nuh'));
        final arabic = find.byKey(const ValueKey('topic-arabic-nuh'));
        final own = find.byKey(const ValueKey('topic-name-nuh'));
        expect(find.descendant(of: row, matching: arabic), findsOne);
        // Right to left: «نوح», then (to its left) the sign.
        expect(plain(tester, arabic), 'نوح \u2067\uFD4A\u2069');
        expect(plain(tester, own), isNot(contains('\uFD4A')));
        expect(
          tester.widget<Text>(arabic).textAlign,
          ltr ? TextAlign.right : TextAlign.left,
        );
        // The Arabic at the card's end, the other at its start.
        final card = tester.getRect(row);
        final ownRect = tester.getRect(own);
        if (ltr) {
          expect(tester.getRect(arabic).right, greaterThan(card.right - 40));
          expect(ownRect.left, lessThan(card.left + 40));
        } else {
          expect(tester.getRect(arabic).left, lessThan(card.left + 40));
          expect(ownRect.right, greaterThan(card.right - 40));
        }
      });
    }

    testWidgets('Arabic: the Quranic name not twice — the sign after the '
        'name', (tester) async {
      await pump(tester, locale: 'ar');
      await tester.tap(find.byKey(const ValueKey('topic-group-card-prophets')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('topic-arabic-nuh')), findsNothing);
      expect(
        plain(tester, find.byKey(const ValueKey('topic-name-nuh'))),
        'نوح \u2067\uFD4A\u2069',
      );
    });

    for (final locale in ['en', 'de', 'ru', 'ar', 'ur', 'ja']) {
      testWidgets('$locale: every group, and the longest-named topics, at '
          '320 px with text twice its size', (tester) async {
        await pump(tester, locale: locale, width: 320, textScale: 2);
        expect(tester.takeException(), isNull);
        for (final group in ['people', 'hereafter']) {
          final card = find.byKey(ValueKey('topic-group-card-$group'));
          // (The groups' scroll, not the search field's.)
          await tester.scrollUntilVisible(
            card,
            300,
            scrollable: find.byType(Scrollable).last,
          );
          await tester.ensureVisible(card);
          await tester.pumpAndSettle();
          await tester.tap(find.byKey(ValueKey('topic-group-card-$group')));
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull, reason: group);
          await tester.tap(find.byKey(const ValueKey('topic-back')));
          await tester.pumpAndSettle();
        }
      });
    }
  });

  test('ayahs grouped into runs: one after another in a surah, one run '
      '(not across surahs)', () {
    expect(ayahRuns([2067, 2068, 2069, 2071, 12043, 12044, 13001]), [
      (first: 2067, last: 2069),
      (first: 2071, last: 2071),
      (first: 12043, last: 12044),
      (first: 13001, last: 13001),
    ]);
    expect(ayahRuns(const []), isEmpty);
  });

  test('after the prophets\' names: «عليه الصلاة والسلام» after Ibrahim\'s, '
      'Musa\'s, Isa\'s and Nuh\'s; «صلى الله عليه وسلم» after the Prophet '
      'Muhammad\'s; «عليه السلام» after the others; none elsewhere', () {
    for (final id in ['ibrahim', 'musa', 'jesus', 'nuh']) {
      expect(prophetHonorific('prophets', id), alayhiSalatu, reason: id);
    }
    expect(prophetHonorific('prophets', 'muhammad'), salla);
    // ('Uzair among them — owner, 2026-11-14.)
    for (final id in ['yusuf', 'adam', 'harun', 'yunus', 'idris', 'uzair']) {
      expect(prophetHonorific('prophets', id), alayhiSalam, reason: id);
    }
    // Maryam: «عليها السلام», its sign ﵍.
    expect(prophetHonorific('people', 'maryam'), alayhaSalam);
    expect(alayhaSalam.shown, '\uFD4D');
    expect(alayhaSalam.words, 'عليها السلام');
    expect(prophetHonorific('people', 'pharaoh'), isNull);
    expect(prophetHonorific('unseen', 'jibreel'), isNull);
    // Written as their signs: ﷺ, \uFD4A, ﵇.
    expect(salla.shown, '\uFDFA');
    expect(alayhiSalatu.shown, '\uFD4A');
    expect(alayhiSalam.shown, '\uFD47');
    // (Read aloud as its words.)
    expect(alayhiSalatu.words, 'عليه الصلاة والسلام');
    expect(salla.words, 'صلى الله عليه وسلم');
    expect(alayhiSalam.words, 'عليه السلام');
  });

  testWidgets('an ayah\'s sheet: the topics it is in — a story\'s chip '
      'opens it, its passage whole', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...tahfeezWidgetTestOverrides(),
          quranTopicsProvider.overrideWith((ref) async => topics),
          ayahCanonicalWordsProvider.overrideWith(
            (ref, id) async => [
              AyahWord(ayahId: id, scriptId: 1, wordIndex: 0, text: 'وَإِذْ'),
            ],
          ),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const Scaffold(
            body: SingleChildScrollView(
              child: AyahTopicsSection(ayahId: 18060),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('ayah-topics')), findsOne);
    expect(find.byKey(const ValueKey('ayah-topic-story-khidr')), findsOne);
    await tester.tap(find.byKey(const ValueKey('ayah-topic-story-khidr')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('topic-passage-18060-18082')), findsOne);
  });

  testWidgets('an ayah in no topic: nothing', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...tahfeezWidgetTestOverrides(),
          quranTopicsProvider.overrideWith((ref) async => topics),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const Scaffold(body: AyahTopicsSection(ayahId: 1001)),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('ayah-topics')), findsNothing);
  });

  testWidgets('back inside Topics goes up a step — never the Quran screen\'s '
      '"back again to leave"; at the groups, that as before', (tester) async {
    resetBackToExit();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...tahfeezWidgetTestOverrides(),
          quranTopicsProvider.overrideWith((ref) async => topics),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: BackToExit(child: TopicsIndexTab(onSelect: (_) {})),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('topic-group-card-prophets')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('topic-concept-nuh')));
    await tester.pumpAndSettle();
    final leave = AppLocalizations.of(
      tester.element(find.byType(TopicsIndexTab)),
    ).homeBackToExit;

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('topic-concept-nuh')), findsOne);
    expect(find.text(leave), findsNothing);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('topic-group-card-sky')), findsOne);
    expect(find.text(leave), findsNothing);

    await tester.binding.handlePopRoute();
    await tester.pump();
    expect(find.text(leave), findsOne, reason: 'at the groups: as before');
    await tester.pump(const Duration(seconds: 3));
  });
}
