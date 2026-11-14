import 'package:tahfeez_ai/features/listen/presentation/reciter_avatar.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:tahfeez_ai/core/theme/components/tahfeez_collapsible_section.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tahfeez_ai/app/app.dart';
import 'package:tahfeez_ai/core/localization/locale_controller.dart';
import 'package:tahfeez_ai/core/core_providers.dart';
import 'package:tahfeez_ai/core/platform/platform_capabilities.dart';
import 'package:tahfeez_ai/core/storage/storage_providers.dart';
import 'package:tahfeez_ai/core/theme/app_surface_tone.dart';
import 'package:tahfeez_ai/core/theme/app_typography.dart';
import 'package:tahfeez_ai/core/theme/theme_controller.dart';
import 'package:tahfeez_ai/features/settings/domain/credits.dart';
import 'package:tahfeez_ai/features/settings/presentation/about_screen.dart';
import 'package:tahfeez_ai/features/onboarding/presentation/first_run_setup.dart';

import '../../test_helpers/widget_test_overrides.dart';

/// The settings list (the search field holds a scrollable too).
final _list = find
    .descendant(of: find.byType(ListView), matching: find.byType(Scrollable))
    .first;

/// A collapsed group of Settings opened (its header scrolled to, tapped).
Future<void> _openGroup(WidgetTester tester, String key) async {
  final header = find.byKey(ValueKey(key));
  await tester.scrollUntilVisible(header, 200, scrollable: _list);
  // (In the middle: not under the bottom bar.)
  await Scrollable.ensureVisible(tester.element(header), alignment: 0.5);
  await tester.pumpAndSettle();
  await tester.tap(
    find.descendant(of: header, matching: find.byType(InkWell)).first,
  );
  await tester.pumpAndSettle();
}

/// The Language group opened, if it is closed (its title is in the
/// language chosen: found by its icon).
Future<void> _openLanguage(WidgetTester tester) async {
  if (find.byKey(const ValueKey('settings-language')).evaluate().isNotEmpty) {
    return;
  }
  final header = find.ancestor(
    of: find.byIcon(Icons.translate),
    matching: find.byType(TahfeezCollapsibleSection),
  );
  await tester.tap(
    find.descendant(of: header, matching: find.byType(InkWell)).first,
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('the Settings tab sets the theme and the language', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      ProviderScope(
        overrides: tahfeezWidgetTestOverrides(),
        child: const TahfeezApp(),
      ),
    );
    await tester.pumpAndSettle();
    final container = ProviderScope.containerOf(
      tester.element(find.byType(TahfeezApp)),
    );

    await tester.tap(find.text('Settings'));
    await tester.pumpAndSettle();
    expect(container.read(themeModeControllerProvider), ThemeMode.system);
    // Every group closed at first, the most used too (owner, 2026-11-08).
    expect(find.byKey(const ValueKey('settings-app-theme')), findsNothing);
    expect(find.byKey(const ValueKey('settings-language')), findsNothing);
    await _openGroup(tester, 'settings-group-App theme');

    Finder appTheme(String name) => find.descendant(
      of: find.byKey(const ValueKey('settings-app-theme')),
      matching: find.text(name),
    );
    await tester.tap(appTheme('Dark'));
    await tester.pumpAndSettle();
    expect(container.read(themeModeControllerProvider), ThemeMode.dark);
    expect(
      Theme.of(tester.element(find.text('Language'))).brightness,
      Brightness.dark,
    );

    // Black: the dark theme on black paper.
    await tester.tap(appTheme('Black'));
    await tester.pumpAndSettle();
    expect(container.read(appSurfaceToneProvider), AppSurfaceTone.black);
    expect(
      Theme.of(tester.element(find.text('Language'))).colorScheme.surface,
      const Color(0xFF000000),
    );

    // Warm: a light theme again.
    await tester.tap(appTheme('Warm'));
    await tester.pumpAndSettle();
    expect(container.read(themeModeControllerProvider), ThemeMode.light);
    expect(
      Theme.of(tester.element(find.text('Language'))).colorScheme.surface,
      const Color(0xFFFBF1DE),
    );

    // The Arabic UI font: the app's text falls back to it.
    expect(container.read(arabicFontControllerProvider), ArabicUiFont.kufi);
    await _openGroup(tester, 'settings-group-Arabic font');
    final tajawal = find.byKey(const ValueKey('settings-arabic-font-tajawal'));
    await tester.scrollUntilVisible(tajawal, 200, scrollable: _list);
    await tester.ensureVisible(tajawal);
    await tester.pumpAndSettle();
    await tester.tap(tajawal);
    await tester.pumpAndSettle();
    expect(container.read(arabicFontControllerProvider), ArabicUiFont.tajawal);
    expect(
      Theme.of(tester.element(tajawal)).textTheme.bodyLarge?.fontFamilyFallback,
      ['Tajawal'],
    );

    // The language list: each with its flag.
    await tester.drag(find.byType(ListView).first, const Offset(0, 2000));
    await tester.pumpAndSettle();
    await _openLanguage(tester);
    await tester.tap(find.byKey(const ValueKey('settings-language')));
    await tester.pumpAndSettle();
    for (final name in ['Deutsch', 'Français', 'Türkçe', 'اردو']) {
      expect(find.text(name), findsWidgets);
    }
    await tester.tap(find.text('العربية').last);
    await tester.pumpAndSettle();
    expect(container.read(localeControllerProvider), const Locale('ar'));
    expect(find.text('اللغة'), findsOneWidget); // "Language", now in Arabic

    await tester.drag(find.byType(ListView).first, const Offset(0, 2000));
    await tester.pumpAndSettle();
    await _openLanguage(tester);
    await tester.tap(find.byKey(const ValueKey('settings-language')));
    await tester.pumpAndSettle();
    // The last of the list too (once hidden under the bottom bar).
    final portuguese = find.byKey(const ValueKey('settings-language-pt'));
    await tester.dragUntilVisible(
      portuguese,
      find.byType(ListView).last,
      const Offset(0, -300),
    );
    await tester.pumpAndSettle();
    await tester.tap(portuguese);
    await tester.pumpAndSettle();
    expect(container.read(localeControllerProvider), const Locale('pt'));

    await tester.drag(find.byType(ListView).first, const Offset(0, 2000));
    await tester.pumpAndSettle();
    await _openLanguage(tester);
    await tester.tap(find.byKey(const ValueKey('settings-language')));
    await tester.pumpAndSettle();
    // Back to the system language.
    await tester.tap(find.byKey(const ValueKey('settings-language-')));
    await tester.pumpAndSettle();
    expect(container.read(localeControllerProvider), isNull);
  });

  testWidgets('searching shows only the sections that match', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      ProviderScope(
        overrides: tahfeezWidgetTestOverrides(),
        child: const TahfeezApp(),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Settings'));
    await tester.pumpAndSettle();
    final search = find.byKey(const ValueKey('settings-search'));

    // An option's name finds its section.
    await tester.enterText(search, 'reset');
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('settings-reset')), findsOneWidget);
    expect(find.byKey(const ValueKey('settings-app-theme')), findsNothing);

    await tester.enterText(search, 'reciter');
    await tester.pumpAndSettle();
    expect(find.text('Recitation audio'), findsOneWidget);
    expect(find.byKey(const ValueKey('settings-reset')), findsNothing);

    await tester.enterText(search, 'zzzz');
    await tester.pumpAndSettle();
    expect(find.text('No settings match'), findsOneWidget);

    // Everything again, every group closed: the language first, the app's
    // About last — not on screen until the list is scrolled to its end.
    await tester.enterText(search, '');
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('settings-group-Language')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('settings-language')), findsNothing);
    final about = find.byKey(const ValueKey('settings-about-app'));
    expect(about, findsNothing);
    // (Collapsed, below the most used.)
    await _openGroup(tester, 'settings-group-about');
    await tester.dragUntilVisible(
      about,
      find.byType(ListView).first,
      const Offset(0, -300),
    );
    expect(about, findsOneWidget);
  });

  testWidgets('closed groups say what is chosen in them; a search '
      'highlights the option found and brings it into view', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      ProviderScope(
        overrides: tahfeezWidgetTestOverrides(),
        child: const TahfeezApp(),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Settings'));
    await tester.pumpAndSettle();
    // Closed: the language and the theme chosen, under their titles.
    expect(
      tester
          .widget<Text>(find.byKey(const ValueKey('section-summary-Language')))
          .data,
      'System default',
    );
    expect(
      tester
          .widget<Text>(find.byKey(const ValueKey('section-summary-App theme')))
          .data,
      // (Whichever an earlier test left chosen.)
      isIn(['System', 'Light', 'Warm', 'Sepia', 'Dark', 'Black']),
    );
    // Opened, the summary goes (the choices themselves are shown).
    await _openGroup(tester, 'settings-group-App theme');
    expect(
      find.byKey(const ValueKey('section-summary-App theme')),
      findsNothing,
    );

    // A search: the option found highlighted, scrolled into view.
    await tester.enterText(
      find.byKey(const ValueKey('settings-search')),
      'export',
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pumpAndSettle();
    final match = find.byKey(const ValueKey('settings-search-match'));
    expect(match, findsWidgets);
    expect(
      find.descendant(of: match.first, matching: find.textContaining('Export')),
      findsOneWidget,
    );
    final rect = tester.getRect(match.first);
    expect(rect.top, greaterThanOrEqualTo(0));
    expect(rect.bottom, lessThan(844));
  });

  testWidgets('first, above Language: the welcome setup, opened again', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      ProviderScope(
        overrides: tahfeezWidgetTestOverrides(),
        child: const TahfeezApp(),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Settings'));
    await tester.pumpAndSettle();
    final card = find.byKey(const ValueKey('settings-setup-again'));
    expect(card, findsOne);
    expect(
      tester.getTopLeft(card).dy,
      lessThan(
        tester
            .getTopLeft(find.byKey(const ValueKey('settings-group-Language')))
            .dy,
      ),
    );
    await tester.tap(card);
    await tester.pumpAndSettle();
    expect(find.byType(FirstRunSetup), findsOne);
    await tester.tap(find.byKey(const ValueKey('setup-skip')));
    await tester.pumpAndSettle();
    expect(find.byType(FirstRunSetup), findsNothing);
  });

  testWidgets('the reciter: his picture beside his name, closed and open', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      ProviderScope(
        overrides: tahfeezWidgetTestOverrides(),
        child: const TahfeezApp(),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Settings'));
    await tester.pumpAndSettle();
    final group = find.byKey(const ValueKey('settings-group-Recitation audio'));
    await tester.scrollUntilVisible(group, 200, scrollable: _list);
    // Closed: the reciter's picture before his name.
    final summary = find.byKey(
      const ValueKey('section-summary-Recitation audio'),
    );
    final picture = find.descendant(
      of: group,
      matching: find.byType(ReciterAvatar),
    );
    expect(picture, findsOne);
    expect(
      tester.getCenter(picture).dx,
      lessThan(tester.getCenter(summary).dx),
    );
    // Open: the same beside the name under "Reciter".
    await _openGroup(tester, 'settings-group-Recitation audio');
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('settings-reciter')),
        matching: find.byType(ReciterNameWithAvatar),
      ),
      findsOne,
    );
  });

  testWidgets('About lists every source with its licence, and the licences', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    registerCreditLicences();
    await tester.pumpWidget(
      ProviderScope(
        overrides: tahfeezWidgetTestOverrides(),
        child: const TahfeezApp(),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Settings'));
    await tester.pumpAndSettle();
    await _openGroup(tester, 'settings-group-about');
    final about = find.byKey(const ValueKey('settings-about'));
    await tester.scrollUntilVisible(about, 200, scrollable: _list);
    await tester.ensureVisible(about);
    await tester.pumpAndSettle();
    await tester.tap(about);
    await tester.pumpAndSettle();
    // The privacy essentials, then the sources.
    expect(find.byKey(const ValueKey('about-privacy')), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text("The Qur'an text"),
      200,
      scrollable: _list,
    );
    expect(find.text("The Qur'an text"), findsOneWidget);
    // Every source is listed, scrolling down the page.
    for (final c in credits) {
      await tester.scrollUntilVisible(
        find.text(c.name),
        300,
        scrollable: _list,
      );
      expect(find.text(c.name), findsOneWidget);
    }
    expect(find.textContaining('Licence:'), findsWidgets);
    // Flutter's licence page carries the sources' notices.
    final notices = await LicenseRegistry.licenses
        .where((l) => l.packages.any((p) => p.startsWith('Tahfeez:')))
        .length;
    expect(notices, credits.length);
  });

  testWidgets('Reset all data asks first, then clears every setting but the '
      'installed Quran\'s marker', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      ProviderScope(
        overrides: tahfeezWidgetTestOverrides(),
        child: const TahfeezApp(),
      ),
    );
    await tester.pumpAndSettle();
    final container = ProviderScope.containerOf(
      tester.element(find.byType(TahfeezApp)),
    );
    final storage = container.read(browserStorageProvider);
    await storage.setString('core.theme_mode', 'dark');
    await storage.setString('quran.dataset.seeded_version', 'v1');

    await tester.tap(find.text('Settings'));
    await tester.pumpAndSettle();
    await _openGroup(tester, 'settings-group-Your data');
    final reset = find.byKey(const ValueKey('settings-reset'));
    await tester.scrollUntilVisible(reset, 200, scrollable: _list);
    await tester.ensureVisible(reset);
    await tester.pumpAndSettle();
    await tester.tap(reset);
    await tester.pumpAndSettle();
    expect(find.text('Reset all data?'), findsOneWidget);

    // Cancel keeps everything.
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(await storage.getString('core.theme_mode'), 'dark');

    await tester.tap(reset);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('settings-reset-confirm')));
    await tester.pumpAndSettle();
    expect(await storage.getString('core.theme_mode'), isNull);
    expect(await storage.getString('quran.dataset.seeded_version'), 'v1');
    expect(
      find.text('All data reset. Reload the app to start fresh.'),
      findsOneWidget,
    );
  });

  for (final ios in [true, false]) {
    testWidgets('rating names this phone\'s store '
        '(${ios ? 'iOS: the App Store' : 'Android: Google Play'})', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            ...tahfeezWidgetTestOverrides(),
            platformCapabilitiesProvider.overrideWithValue(_Platform(ios: ios)),
          ],
          child: const TahfeezApp(),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Settings'));
      await tester.pumpAndSettle();
      await _openGroup(tester, 'settings-group-about');
      final rate = find.text('Rate TahfeezAI');
      await tester.scrollUntilVisible(rate, 200, scrollable: _list);
      expect(
        find.text(ios ? 'On the App Store' : 'On Google Play'),
        findsOneWidget,
      );
      expect(
        find.text(ios ? 'On Google Play' : 'On the App Store'),
        findsNothing,
      );
    });
  }
}

class _Platform implements PlatformCapabilities {
  const _Platform({required this.ios});

  final bool ios;

  @override
  bool get isWeb => false;
  @override
  bool get isAndroid => !ios;
  @override
  bool get isIOS => ios;
  @override
  bool get supportsBackgroundAudioSession => true;
  @override
  bool get supportsHomeScreenWidgets => true;
  @override
  bool get supportsScheduledNotifications => true;
  @override
  bool get supportsNativeFileStorage => true;
}
