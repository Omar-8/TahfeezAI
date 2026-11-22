import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tahfeez_ai/app/app.dart';
import 'package:tahfeez_ai/core/audio/audio_controller.dart';
import 'package:tahfeez_ai/core/localization/locale_controller.dart';
import 'package:tahfeez_ai/core/routing/app_router.dart';
import 'package:tahfeez_ai/core/routing/quran_location_routing.dart';
import 'package:tahfeez_ai/core/theme/components/components.dart';
import 'package:tahfeez_ai/core/theme/tahfeez_content_widths.dart';
import 'package:tahfeez_ai/features/home/presentation/home_screen.dart';
import 'package:tahfeez_ai/features/memorize/presentation/memorize_screen.dart';
import 'package:tahfeez_ai/features/mushaf/presentation/mushaf_reader_screen.dart';
import 'package:tahfeez_ai/features/quran/presentation/quran_index_screen.dart';
import 'package:tahfeez_ai/features/search/presentation/search_screen.dart';
import 'package:tahfeez_ai/quran/domain/models/quran_location.dart';

import '../../test_helpers/app_menu.dart';
import '../../test_helpers/widget_test_overrides.dart';

void main() {
  Widget app({AudioController? audioController}) => ProviderScope(
    overrides: tahfeezWidgetTestOverrides(audioController: audioController),
    child: const TahfeezApp(),
  );

  void setPhoneSize(WidgetTester tester) {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  void setDesktopSize(WidgetTester tester) {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  testWidgets('shows all three navigation destinations on phone', (
    tester,
  ) async {
    setPhoneSize(tester);
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();

    expect(find.byType(TahfeezPrimaryNavigationBar), findsOneWidget);
    expect(find.byType(TahfeezPrimaryNavigationRail), findsNothing);
    final bar = find.byType(TahfeezPrimaryNavigationBar);
    for (final label in ['Home', "Qur'an", 'Memorize']) {
      expect(
        find.descendant(of: bar, matching: find.text(label)),
        findsOneWidget,
      );
    }
    // Settings: in the side menu now (owner, 2026-11-20).
    expect(
      find.descendant(of: bar, matching: find.text('Settings')),
      findsNothing,
    );
  });

  testWidgets('the side menu: from each tab, Settings and the Qibla over it, '
      'back to the tab', (tester) async {
    setPhoneSize(tester);
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    for (final tab in ['Home', "Qur'an", 'Memorize']) {
      await tester.tap(
        find.descendant(
          of: find.byType(TahfeezPrimaryNavigationBar),
          matching: find.text(tab),
        ),
      );
      await tester.pumpAndSettle();
      await openFromMenu(tester, 'settings');
      expect(find.byKey(const ValueKey('settings-search')), findsOneWidget);
      // Over the tab: no tab bar, and back returns to it.
      expect(find.byType(TahfeezPrimaryNavigationBar), findsNothing);
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.byType(TahfeezPrimaryNavigationBar), findsOneWidget);
    }
    // Bookmarks: over the Quran tab, back to it.
    await openFromMenu(tester, 'bookmarks');
    expect(find.text('Bookmarks'), findsWidgets);
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.byType(QuranIndexScreen), findsOneWidget);
    await openFromMenu(tester, 'qibla');
    expect(find.text('Qibla'), findsWidgets);
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.byType(TahfeezPrimaryNavigationBar), findsOneWidget);
  });

  testWidgets('the menu button in the same place on all three tabs '
      '(owner, 2026-11-20: it moved between Home and the others)', (
    tester,
  ) async {
    // Phones (a wide window: each page its own content width), in English
    // and in Arabic (its taller title), at two text sizes.
    for (final (size, locale, scale) in const [
      (Size(390, 844), 'en', 1.0),
      (Size(360, 780), 'en', 1.3),
      (Size(390, 844), 'ar', 1.0),
      (Size(390, 844), 'ar', 1.3),
    ]) {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1.0;
      // A phone's status bar above (the app drawn under it).
      tester.view.padding = const FakeViewPadding(top: 40);
      tester.view.viewPadding = const FakeViewPadding(top: 40);
      tester.platformDispatcher.textScaleFactorTestValue = scale;
      addTearDown(tester.view.reset);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpWidget(app());
      await tester.pumpAndSettle();
      final container = ProviderScope.containerOf(
        tester.element(find.byType(TahfeezApp)),
      );
      await container
          .read(localeControllerProvider.notifier)
          .setLocale(Locale(locale));
      await tester.pumpAndSettle();
      final tabs = find.descendant(
        of: find.byType(TahfeezPrimaryNavigationBar),
        matching: find.byType(InkWell),
      );
      final rects = <int, Rect>{};
      for (final tab in [0, 1, 2]) {
        await tester.tap(tabs.at(tab));
        await tester.pumpAndSettle();
        rects[tab] = tester.getRect(
          find.byKey(const ValueKey('app-menu')).hitTestable(),
        );
      }
      for (final tab in [1, 2]) {
        for (final (what, a, b) in [
          ('left', rects[0]!.left, rects[tab]!.left),
          ('top', rects[0]!.top, rects[tab]!.top),
          ('width', rects[0]!.width, rects[tab]!.width),
        ]) {
          expect(
            b,
            closeTo(a, 0.5),
            reason: 'tab $tab $what, $locale ×$scale at $size: $rects',
          );
        }
      }
      await container
          .read(localeControllerProvider.notifier)
          .setLocale(const Locale('en'));
      await tester.pumpAndSettle();
    }
  });

  testWidgets('the bar its height as before; the Quran mark larger, rising '
      'above it (owner, 2026-11-20: the bar had grown)', (tester) async {
    setPhoneSize(tester);
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    final bar = tester.getRect(find.byType(TahfeezPrimaryNavigationBar));
    expect(bar.height, 72);
    final labels = [
      for (final label in ['Home', "Qur'an", 'Memorize'])
        tester.getRect(
          find.descendant(
            of: find.byType(TahfeezPrimaryNavigationBar),
            matching: find.text(label),
          ),
        ),
    ];
    // The labels on one line, at their full size (the items not shrunk).
    expect(labels.map((r) => r.center.dy).toSet(), hasLength(1));
    final style = tester
        .widget<Text>(
          find.descendant(
            of: find.byType(TahfeezPrimaryNavigationBar),
            matching: find.text('Home'),
          ),
        )
        .style;
    expect(labels.first.height, closeTo(style!.fontSize! * style.height!, 1));
    // The mark: 44 across, over its tab, floating above the bar's top
    // (in an arch cut out of the bar), clear of its label.
    final mark = tester.getRect(find.byType(QuranMark));
    expect(mark.width, 44);
    expect(mark.top, lessThan(bar.top));
    expect(mark.bottom, lessThan(labels[1].top));
    expect(mark.center.dx, closeTo(labels[1].center.dx, 0.5));
    // Tapping it opens its tab.
    await tester.tapAt(mark.center + const Offset(0, 4));
    await tester.pumpAndSettle();
    expect(find.byType(QuranIndexScreen), findsOneWidget);
    // The others: icons of the usual size.
    for (final icon in tester.widgetList<Icon>(
      find.descendant(
        of: find.byType(TahfeezPrimaryNavigationBar),
        matching: find.byType(Icon),
      ),
    )) {
      expect(icon.size, 24);
    }
  });

  testWidgets("Home's Qibla shortcut opens the Qibla finder", (tester) async {
    setPhoneSize(tester);
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    // No live blur: blurring what scrolls beneath it flickered (owner,
    // 2026-11-21).
    final glass = tester.widget<TahfeezGlassSurface>(
      find.descendant(
        of: find.byKey(const ValueKey('home-qibla')),
        matching: find.byType(TahfeezGlassSurface),
      ),
    );
    expect(glass.blur, isFalse);
    await tester.tap(find.byKey(const ValueKey('home-qibla')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('qibla-place')), findsOneWidget);
  });

  testWidgets('tapping a destination switches the shell body', (tester) async {
    setPhoneSize(tester);
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();

    // Home is the initial branch.
    expect(find.text('Daily Ayah'), findsOneWidget);

    await tester.tap(find.text("Qur'an"));
    await tester.pumpAndSettle();
    expect(find.byType(TabBar), findsOneWidget);
    expect(find.text('Surah'), findsOneWidget);

    await tester.tap(find.text('Memorize').last);
    await tester.pumpAndSettle();
    expect(find.byType(MemorizeScreen), findsOneWidget);

    await tester.tap(find.text('Home'));
    await tester.pumpAndSettle();
    expect(find.text('Daily Ayah'), findsOneWidget);
  });

  testWidgets('uses a navigation rail (not a bottom bar) on a wide viewport', (
    tester,
  ) async {
    setDesktopSize(tester);
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();

    expect(find.byType(TahfeezPrimaryNavigationRail), findsOneWidget);
    expect(find.byType(TahfeezPrimaryNavigationBar), findsNothing);
  });

  testWidgets('renders the shell correctly in an RTL (Arabic) locale', (
    tester,
  ) async {
    setPhoneSize(tester);
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();

    final container = ProviderScope.containerOf(
      tester.element(find.byType(TahfeezApp)),
    );
    await container
        .read(localeControllerProvider.notifier)
        .setLocale(const Locale('ar'));
    await tester.pumpAndSettle();

    expect(
      Directionality.of(
        tester.element(find.byType(TahfeezPrimaryNavigationBar)),
      ),
      TextDirection.rtl,
    );
    expect(find.text('الرئيسية'), findsOneWidget);
    expect(find.text('القرآن'), findsOneWidget);
    // ☰ at the start (right) of Home's header, the Qibla's at its end.
    expect(
      tester.getCenter(find.byKey(const ValueKey('app-menu')).first).dx,
      greaterThan(
        tester.getCenter(find.byKey(const ValueKey('home-qibla'))).dx,
      ),
    );
    await tester.tap(find.byKey(const ValueKey('app-menu')).first);
    await tester.pumpAndSettle();
    expect(find.text('الإعدادات'), findsOneWidget);
    // The menu slides in from the right.
    expect(
      tester.getRect(find.byKey(const ValueKey('app-menu-drawer'))).right,
      390,
    );
    await tester.tapAt(const Offset(20, 400));
    await tester.pumpAndSettle();

    // The Quran page, in Arabic too: its title, tabs and empty state.
    await tester.tap(find.text('القرآن'));
    await tester.pumpAndSettle();
    expect(find.text('القرآن'), findsNWidgets(2)); // the tab and the title
    for (final tab in ['السور', 'الأجزاء', 'الأحزاب', 'المواضيع']) {
      expect(find.text(tab), findsOneWidget);
    }
    expect(find.text('Surah'), findsNothing);
  });

  testWidgets('the tabs and the reader span the width (their sky), their '
      'content in a centred column; other screens in the shell column', (
    tester,
  ) async {
    setDesktopSize(tester);
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();

    final container = ProviderScope.containerOf(
      tester.element(find.byType(TahfeezApp)),
    );
    final router = container.read(appRouterProvider);

    for (final (route, screen) in [
      ('/home', HomeScreen),
      ('/quran', QuranIndexScreen),
      ('/memorize', MemorizeScreen),
      ('/quran/page/1/1', MushafReaderScreen),
    ]) {
      router.go(route);
      await tester.pumpAndSettle();
      expect(
        tester.getSize(find.byType(screen)).width,
        greaterThan(TahfeezContentWidth.maxReading),
        reason: route,
      );
    }
    // The Quran tab's list in the reading column, centred.
    router.go('/quran');
    await tester.pumpAndSettle();
    final list = tester.getRect(find.byType(TabBarView));
    expect(list.width, TahfeezContentWidth.maxReading);
    final area = tester.getRect(find.byType(QuranIndexScreen));
    expect(list.center.dx, closeTo(area.center.dx, 1));

    router.go('/quran/search');
    await tester.pumpAndSettle();
    expect(
      tester.getSize(find.byType(SearchScreen)).width,
      TahfeezContentWidth.maxReading,
    );
  });

  testWidgets('a Quran location opens in the tab that asked for it, and back '
      'returns there', (tester) async {
    setPhoneSize(tester);
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    final container = ProviderScope.containerOf(
      tester.element(find.byType(TahfeezApp)),
    );
    final router = container.read(appRouterProvider);
    String location() => router.state.uri.path;

    goToQuranLocation(
      tester.element(find.byType(HomeScreen)),
      const QuranLocation.page(1, 5),
    );
    await tester.pumpAndSettle();
    expect(location(), '/home/page/1/5', reason: 'still the Home tab');
    expect(find.byType(MushafReaderScreen), findsOneWidget);

    // From a Mushaf screen, another location replaces it.
    goToQuranLocation(
      tester.element(find.byType(MushafReaderScreen)),
      const QuranLocation.page(1, 6),
    );
    await tester.pumpAndSettle();
    expect(location(), '/home/page/1/6');

    router.pop();
    await tester.pumpAndSettle();
    expect(location(), '/home', reason: 'back to the opener');
    expect(find.byType(HomeScreen), findsOneWidget);
  });
}
