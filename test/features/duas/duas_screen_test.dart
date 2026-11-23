import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tahfeez_ai/core/storage/storage_providers.dart';
import 'package:tahfeez_ai/core/theme/components/components.dart';

import 'dart:convert';
import 'dart:io';

import 'package:tahfeez_ai/features/duas/application/duas_providers.dart';
import 'package:tahfeez_ai/features/duas/application/saved_supplications.dart';
import 'package:tahfeez_ai/features/duas/domain/duas.dart';
import 'package:tahfeez_ai/features/duas/presentation/duas_screen.dart';

import '../../test_helpers/app_menu.dart';
import '../../test_helpers/real_app.dart';

/// Duas (owner, 2026-11-23): from the side menu and Home; the Quran's duas
/// (from the installed dataset) and Hisn al-Muslim's chapters in sections;
/// searched; a dua or an athkar chapter bookmarked — first among its tiles,
/// over the sections, and on the Bookmarks page.
void main() {
  setUpAll(RealApp.prepare);
  tearDownAll(RealApp.close);

  Finder key(String k) => find.byKey(ValueKey(k));
  // Tall: a section's cards and tiles all built.
  const tall = Size(600, 2400);

  Future<void> clear(ProviderContainer c) async {
    await c.read(browserStorageProvider).remove(SavedSupplications.storageKey);
  }

  /// Launched with nothing bookmarked (none left by an earlier run).
  Future<ProviderContainer> launch(
    WidgetTester tester, {
    String route = '/home',
    Size size = const Size(390, 844),
  }) async {
    final c = await RealApp.launch(tester, route: route, size: size);
    if (c.read(savedSupplicationsProvider).isNotEmpty) {
      for (final k in [...c.read(savedSupplicationsProvider)]) {
        c.read(savedSupplicationsProvider.notifier).toggle(k);
      }
      await RealApp.settle(tester);
    }
    return c;
  }

  Future<void> tap(WidgetTester tester, Finder f) async {
    await tester.ensureVisible(f);
    await tester.pumpAndSettle();
    await tester.tap(f);
    await RealApp.settle(tester);
  }

  test('every Quran dua is a real ayah range; no section empty', () {
    for (final g in DuaGroup.values) {
      expect(
        g.quran.length + g.chapters.length,
        greaterThan(0),
        reason: g.name,
      );
      for (final d in g.quran) {
        expect(d.surah, inInclusiveRange(1, 114));
        expect(d.to, greaterThanOrEqualTo(d.from));
      }
    }
    // A key's dua found again.
    expect(DuaGroup.quranOf('quran:20:25-28'), const QuranDua(20, 25, 28));
    expect(SavedSupplications.chapterOf('athkar:41'), 41);
  });

  test('the hadith duas: each in a section, in Arabic and English; '
      'numbered as sunnah.com', () {
    final json = jsonDecode(
      utf8.decode(gzip.decode(File(kHadithDuasAsset).readAsBytesSync())),
    ) as Map<String, Object?>;
    final all = [
      for (final h in json['hadiths']! as List<Object?>)
        HadithDua.fromJson(h! as Map<String, Object?>),
    ];
    expect(all, hasLength(19));
    final names = {for (final g in DuaGroup.values) g.name};
    for (final h in all) {
      expect(names, contains(h.group));
      expect(h.arabic, isNotEmpty);
      expect(h.translations['en'], isNotEmpty);
      expect(h.book, anyOf('bukhari', 'muslim'));
    }
    final istighfar = all.firstWhere((h) => h.number == '6306');
    expect(istighfar.group, 'forgiveness');
    expect(istighfar.arabic, contains('اللَّهُمَّ أَنْتَ رَبِّي'));
    final guidance = all.firstWhere((h) => h.number == '2721.01');
    expect(guidance.shownNumber, '2721a');
    expect(guidance.arabic, contains('أَسْأَلُكَ الْهُدَى'));
    // No Russian for Muslim's: the English; none at all in Arabic.
    expect(guidance.translationIn('ru'), guidance.translations['en']);
    expect(guidance.translationIn('ar'), isNull);
    expect(istighfar.translationIn('ur'), istighfar.translations['ur']);
  });

  testWidgets('a section\'s hadith duas, under the Quran\'s, then Hisn '
      'al-Muslim\'s chapters; bookmarked', (tester) async {
    final c = await launch(tester, route: '/duas/forgiveness', size: tall);
    final card = key('dua-tile-hadith:bukhari:6306');
    expect(card, findsOneWidget);
    expect(
      find.descendant(of: card, matching: find.text('Sayyid al-Istighfar')),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: card,
        matching: find.text('Sahih al-Bukhari \u20666306\u2069'),
      ),
      findsOneWidget,
    );
    expect(find.text('From the Sunnah'), findsOneWidget);
    expect(
      tester.getTopLeft(key('dua-quran:7:23-23')).dy,
      lessThan(tester.getTopLeft(card).dy),
    );
    await tap(tester, key('saved-hadith:bukhari:6306'));
    expect(c.read(savedSupplicationsProvider), ['hadith:bukhari:6306']);
    // Its tile opens it whole: the hadith in Arabic, and the English.
    await tap(tester, card);
    expect(find.text('Sayyid al-Istighfar'), findsOneWidget);
    expect(key('dua-text-hadith:bukhari:6306'), findsOneWidget);
    expect(find.textContaining('Narrated Shaddad bin Aus'), findsOneWidget);
    await tester.pageBack();
    await RealApp.settle(tester);
    // Then Hisn al-Muslim's chapters.
    await tester.scrollUntilVisible(
      key('athkar-category-129'),
      300,
      scrollable: find.byType(Scrollable).last,
    );
    expect(find.text('From Hisn al-Muslim'), findsOneWidget);
    expect(c.read(savedSupplicationsProvider), ['hadith:bukhari:6306']);
    await RealApp.quit(tester);
    final c2 = await RealApp.launch(tester, route: '/quran/bookmarks');
    expect(key('bookmark-hadith:bukhari:6306'), findsOneWidget);
    await clear(c2);
    await clear(c);
    await RealApp.quit(tester);
  });

  testWidgets('the side menu and Home open Duas: its sections; a section\'s '
      'duas from the Quran in the dataset\'s text, then its chapters', (
    tester,
  ) async {
    final c = await launch(tester);
    expect(key('home-duas'), findsOneWidget);
    await tap(tester, key('home-duas'));
    expect(find.byType(DuasScreen), findsOneWidget);
    for (final g in DuaGroup.values) {
      await tester.ensureVisible(key('duas-group-${g.name}'));
      expect(key('duas-group-${g.name}'), findsOneWidget);
    }
    await tap(tester, key('duas-group-children'));
    expect(find.byType(DuaGroupScreen), findsOneWidget);
    expect(find.text('From the Quran'), findsOneWidget);
    // Zakariyya's dua (3:38), from the Quran dataset, and its number.
    final text = tester.widget<Text>(key('dua-text-quran:3:38-38')).data!;
    expect(text, startsWith('هُنَالِكَ دَعَا'));
    expect(text, endsWith('﴿٣٨﴾'));
    await tester.scrollUntilVisible(
      key('athkar-category-48'),
      200,
      scrollable: find.byType(Scrollable).last,
    );
    expect(find.text('From Hisn al-Muslim'), findsOneWidget);
    expect(key('athkar-category-47'), findsOneWidget);
    await clear(c);
    await RealApp.quit(tester);

    final c2 = await RealApp.launch(tester);
    await openFromMenu(tester, 'duas');
    expect(find.byType(DuasScreen), findsOneWidget);
    await clear(c2);
    await RealApp.quit(tester);
  });

  testWidgets('search: in the Quran\'s duas (Arabic and translation) and the '
      'chapters\' words', (tester) async {
    final c = await launch(tester, route: '/duas', size: tall);
    await tester.enterText(key('duas-search'), 'ذرية');
    await RealApp.settle(tester);
    expect(key('dua-quran:3:38-38'), findsOneWidget);
    expect(key('dua-quran:21:83-83'), findsNothing);
    await tester.enterText(key('duas-search'), 'debt');
    await RealApp.settle(tester);
    expect(key('athkar-category-41'), findsOneWidget);
    await tester.enterText(key('duas-search'), 'zzzz');
    await RealApp.settle(tester);
    expect(find.byType(TahfeezEmptyView), findsOneWidget);
    await clear(c);
    await RealApp.quit(tester);
  });

  testWidgets('a dua bookmarked: first in its section, over Duas\' sections, '
      'on the Bookmarks page; removed there, undone', (tester) async {
    final c = await launch(tester, route: '/duas/provision', size: tall);
    final first = key('dua-quran:2:201-201');
    final last = key('dua-quran:23:29-29');
    expect(tester.getTopLeft(first).dy, lessThan(tester.getTopLeft(last).dy));
    await tap(tester, key('saved-quran:23:29-29'));
    expect(c.read(savedSupplicationsProvider), ['quran:23:29-29']);
    // Back to the top (the tap scrolled to it).
    await tester.drag(find.byType(Scrollable).last, const Offset(0, 4000));
    await tester.pumpAndSettle();
    expect(
      tester.getTopLeft(last).dy,
      lessThan(tester.getTopLeft(first).dy),
      reason: 'the bookmarked one first',
    );
    await RealApp.quit(tester);

    // Kept: over Duas' sections.
    final c2 = await RealApp.launch(tester, route: '/duas', size: tall);
    expect(find.text('Bookmarked'), findsOneWidget);
    expect(last, findsOneWidget);
    expect(
      tester.getTopLeft(last).dy,
      lessThan(tester.getTopLeft(key('duas-group-health')).dy),
    );
    await RealApp.quit(tester);

    // On the Bookmarks page, under its own heading; removed, then undone.
    final c3 = await RealApp.launch(
      tester,
      route: '/quran/bookmarks',
      size: tall,
    );
    expect(find.text('Athkar and duas'), findsOneWidget);
    expect(key('bookmark-quran:23:29-29'), findsOneWidget);
    await tester.tap(
      find.descendant(
        of: key('bookmark-quran:23:29-29'),
        matching: find.byIcon(Icons.delete_outline_rounded),
      ),
    );
    await tester.pumpAndSettle();
    expect(c3.read(savedSupplicationsProvider), isEmpty);
    await tester.tap(find.text('Undo'));
    await tester.pumpAndSettle();
    expect(c3.read(savedSupplicationsProvider), ['quran:23:29-29']);
    await clear(c3);
    await clear(c2);
    await clear(c);
    await RealApp.quit(tester);
  });

  testWidgets('an athkar chapter bookmarked from its tile: first in its '
      'section, over Athkar\'s sections, in Duas too', (tester) async {
    final c = await launch(
      tester,
      route: '/athkar/section/distress',
      size: tall,
    );
    // Settling a debt (41), after Worry and grief (34) until bookmarked.
    final debt = key('athkar-category-41');
    final worry = key('athkar-category-34');
    await tap(tester, key('saved-athkar:41'));
    expect(c.read(savedSupplicationsProvider), ['athkar:41']);
    expect(
      tester.getTopLeft(debt).dy <= tester.getTopLeft(worry).dy &&
          (tester.getTopLeft(debt).dy < tester.getTopLeft(worry).dy ||
              tester.getTopLeft(debt).dx != tester.getTopLeft(worry).dx),
      isTrue,
      reason: 'the bookmarked one first',
    );
    await RealApp.quit(tester);

    final c2 = await RealApp.launch(tester, route: '/athkar', size: tall);
    expect(key('athkar-bookmarked'), findsOneWidget);
    expect(debt, findsOneWidget);
    await RealApp.quit(tester);

    // In Duas (its Money section's chapter), over the sections.
    final c3 = await RealApp.launch(tester, route: '/duas', size: tall);
    expect(debt, findsOneWidget);
    expect(
      tester.getTopLeft(debt).dy,
      lessThan(tester.getTopLeft(key('duas-group-health')).dy),
    );
    await clear(c3);
    await clear(c2);
    await clear(c);
    await RealApp.quit(tester);
  });
}
