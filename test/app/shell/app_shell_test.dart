import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tahfeez_ai/app/app.dart';
import 'package:tahfeez_ai/core/audio/audio_controller.dart';
import 'package:tahfeez_ai/core/localization/locale_controller.dart';
import 'package:tahfeez_ai/core/routing/app_router.dart';
import 'package:tahfeez_ai/core/theme/components/components.dart';
import 'package:tahfeez_ai/core/theme/tahfeez_content_widths.dart';
import 'package:tahfeez_ai/core/ui/full_bleed_content.dart';
import 'package:tahfeez_ai/features/home/presentation/home_screen.dart';
import 'package:tahfeez_ai/features/mushaf/presentation/mushaf_reader_screen.dart';
import 'package:tahfeez_ai/features/quran/presentation/quran_index_screen.dart';

import '../../test_helpers/fake_audio_controller.dart';
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
    expect(find.text('Home'), findsOneWidget);
    expect(find.text('Quran'), findsOneWidget);
    expect(find.text('Search'), findsOneWidget);
  });

  testWidgets('tapping a destination switches the shell body', (tester) async {
    setPhoneSize(tester);
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();

    // Home is the initial branch.
    expect(
      find.text('Your calm place to read and memorize the Quran.'),
      findsOneWidget,
    );

    await tester.tap(find.text('Quran'));
    await tester.pumpAndSettle();
    expect(find.byType(TabBar), findsOneWidget);
    expect(find.text('Surah'), findsOneWidget);

    await tester.tap(find.text('Search'));
    await tester.pumpAndSettle();
    expect(
      find.text(
        'This will appear automatically once a Quran dataset is added to the app.',
      ),
      findsOneWidget,
    );

    await tester.tap(find.text('Home'));
    await tester.pumpAndSettle();
    expect(
      find.text('Your calm place to read and memorize the Quran.'),
      findsOneWidget,
    );
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
    expect(find.text('بحث'), findsOneWidget);
  });

  testWidgets('reserves mini-player space only while a track is active', (
    tester,
  ) async {
    setPhoneSize(tester);
    final controller = FakeAudioController();
    await tester.pumpWidget(app(audioController: controller));
    await tester.pumpAndSettle();

    expect(find.byType(TahfeezMiniPlayerShell), findsNothing);

    await controller.playUrl('https://example.invalid/track.mp3');
    await tester.pumpAndSettle();
    expect(find.byType(TahfeezMiniPlayerShell), findsOneWidget);

    await controller.stop();
    await tester.pumpAndSettle();
    expect(find.byType(TahfeezMiniPlayerShell), findsNothing);
  });

  testWidgets('the Mushaf spread is the only screen that can escape the cap', (
    tester,
  ) async {
    setDesktopSize(tester);
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();

    final container = ProviderScope.containerOf(
      tester.element(find.byType(TahfeezApp)),
    );
    final router = container.read(appRouterProvider);

    // The normal shell stays capped.
    expect(
      tester.getSize(find.byType(HomeScreen)).width,
      TahfeezContentWidth.maxReading,
    );

    router.go('/quran/page/1/1');
    await tester.pumpAndSettle();
    expect(find.byType(MushafReaderScreen), findsOneWidget);

    // The spread request widens the active Mushaf page while it is mounted.
    container.read(fullBleedContentProvider.notifier).request();
    await tester.pumpAndSettle();
    expect(
      tester.getSize(find.byType(MushafReaderScreen)).width,
      greaterThan(TahfeezContentWidth.maxReading),
    );

    router.go('/quran');
    await tester.pumpAndSettle();
    expect(find.byType(QuranIndexScreen), findsOneWidget);
    expect(
      tester.getSize(find.byType(QuranIndexScreen)).width,
      TahfeezContentWidth.maxReading,
    );
  });
}
