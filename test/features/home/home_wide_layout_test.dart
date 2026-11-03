import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tahfeez_ai/core/core_providers.dart';
import 'package:tahfeez_ai/core/theme/components/components.dart';
import 'package:tahfeez_ai/features/home/presentation/home_sky.dart';
import 'package:tahfeez_ai/features/home/presentation/sections/home_daily_ayah_section.dart';
import 'package:tahfeez_ai/features/home/presentation/sections/home_featured_reading_section.dart';
import 'package:tahfeez_ai/features/home/presentation/sections/home_memorization_section.dart';

import '../../test_helpers/real_app.dart';
import '../../test_helpers/web_platform.dart';

/// Home on a large tablet: the sky across the whole width and the sections
/// in two columns; on a phone and a smaller tablet, one column as before.
void main() {
  setUpAll(RealApp.prepare);
  tearDownAll(RealApp.close);

  final twoColumns = find.byKey(const ValueKey('home-two-columns'));

  for (final (name, size, locale) in [
    ('13" iPad', const Size(1032, 1376), 'en'),
    ('13" iPad, Arabic', const Size(1032, 1376), 'ar'),
  ]) {
    testWidgets('$name: two columns, the sky full width', (tester) async {
      await RealApp.launch(tester, size: size, locale: locale);
      RealApp.fits(tester, 'Home on $name');
      expect(twoColumns, findsOneWidget);
      final ayah = tester.getRect(find.byType(HomeDailyAyahSection));
      final memorization = tester.getRect(find.byType(HomeMemorizationSection));
      expect(
        (ayah.top - memorization.top).abs(),
        lessThan(1),
        reason: 'side by side',
      );
      // Arabic: the first column on the right.
      expect(
        locale == 'ar'
            ? ayah.left > memorization.left
            : ayah.left < memorization.left,
        isTrue,
      );
      // In the middle of the height.
      final cards = tester.getRect(twoColumns);
      expect(cards.center.dy, closeTo(size.height / 2, 150));
      final sky = tester.getRect(find.byType(HomeSky));
      final rail = tester.getRect(find.byType(TahfeezPrimaryNavigationRail));
      expect(sky.width, closeTo(size.width - rail.width - 1, 2));
      await RealApp.quit(tester);
    });
  }

  for (final (name, size) in [
    ('phone', const Size(390, 844)),
    ('11" iPad', const Size(834, 1194)),
  ]) {
    testWidgets('$name: one column, at most the reading width', (tester) async {
      await RealApp.launch(tester, size: size);
      RealApp.fits(tester, 'Home on $name');
      expect(twoColumns, findsNothing);
      expect(
        tester.getSize(find.byType(HomeDailyAyahSection)).width,
        lessThanOrEqualTo(720),
      );
      await RealApp.quit(tester);
    });
  }

  Finder featuredCards() => find.descendant(
    of: find.byType(HomeFeaturedReadingSection),
    matching: find.byType(TahfeezQuranSectionCard),
  );
  bool rail(WidgetTester tester) => find
      .descendant(
        of: find.byType(HomeFeaturedReadingSection),
        matching: find.byType(ListView),
      )
      .evaluate()
      .isNotEmpty;

  testWidgets('a desktop browser window: every featured surah in view, two '
      'to a row — no rail running off the edge', (tester) async {
    await RealApp.launch(
      tester,
      size: const Size(1440, 900),
      overrides: [
        platformCapabilitiesProvider.overrideWithValue(const WebPlatform()),
      ],
    );
    RealApp.fits(tester, 'Home in a browser window');
    expect(featuredCards(), findsAtLeastNWidgets(2));
    expect(rail(tester), isFalse);
    final section = tester.getRect(find.byType(HomeFeaturedReadingSection));
    for (final card in featuredCards().evaluate()) {
      final rect = tester.getRect(find.byWidget(card.widget));
      expect(rect.right, lessThanOrEqualTo(section.right + 0.5));
      expect(rect.left, greaterThanOrEqualTo(section.left - 0.5));
    }
    await RealApp.quit(tester);
  });

  testWidgets('a 13" iPad (not a browser): the rail, as before', (
    tester,
  ) async {
    await RealApp.launch(tester, size: const Size(1032, 1376));
    expect(rail(tester), isTrue);
    await RealApp.quit(tester);
  });
}
