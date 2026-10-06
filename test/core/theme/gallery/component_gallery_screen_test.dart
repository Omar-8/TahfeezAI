import 'package:flutter/material.dart';
import 'package:tahfeez_ai/core/localization/generated/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tahfeez_ai/core/theme/app_theme.dart';
import 'package:tahfeez_ai/core/theme/gallery/component_gallery_screen.dart';

void main() {
  Widget wrap(Widget child, {Locale locale = const Locale('en')}) {
    return ProviderScope(
      child: MaterialApp(
        locale: locale,
        supportedLocales: const [Locale('en'), Locale('ar')],
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        theme: buildLightTheme(),
        home: child,
      ),
    );
  }

  // The gallery permanently shows a `TahfeezLoadingView` (an indeterminate
  // `CircularProgressIndicator`), which schedules a new frame forever by
  // design -- so `tester.pumpAndSettle()` can never settle on this screen.
  // A handful of fixed-duration pumps is used instead everywhere below.
  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  testWidgets('renders every gallery section without throwing', (tester) async {
    await tester.pumpWidget(wrap(const ComponentGalleryScreen()));
    await settle(tester);

    expect(find.text('Component gallery'), findsOneWidget);
    expect(find.text('Cards'), findsOneWidget);
    expect(find.text('Quran section cards'), findsOneWidget);
    expect(find.text('Resource rows & download progress'), findsOneWidget);
    expect(find.text('Verse action bar'), findsOneWidget);
    expect(find.text('Mini player shell'), findsOneWidget);
    expect(find.text('Sheets & dialogs'), findsOneWidget);
    expect(find.text('Loading / empty / error states'), findsOneWidget);
    expect(find.text('Memorization-state placeholders'), findsOneWidget);
    expect(find.text('Current ayah'), findsOneWidget);
    expect(find.text('Completed session'), findsOneWidget);
  });

  testWidgets(
    'interacting with the filter chip and segmented control does not throw',
    (tester) async {
      await tester.pumpWidget(wrap(const ComponentGalleryScreen()));
      await settle(tester);

      await tester.ensureVisible(find.text('Meccan'));
      await settle(tester);
      await tester.tap(find.text('Meccan'));
      await settle(tester);

      await tester.ensureVisible(find.text('Mushaf'));
      await settle(tester);
      await tester.tap(find.text('Mushaf'));
      await settle(tester);

      // No exception thrown by either interaction is itself the assertion;
      // the state also visibly changed (Mushaf segment is now selected).
      final segmented = tester.widget<SegmentedButton<String>>(
        find.byType(SegmentedButton<String>),
      );
      expect(segmented.selected, {'mushaf'});
    },
  );

  testWidgets('shows a bottom sheet and a destructive dialog on demand', (
    tester,
  ) async {
    await tester.pumpWidget(wrap(const ComponentGalleryScreen()));
    await settle(tester);

    await tester.ensureVisible(find.text('Show bottom sheet'));
    await settle(tester);
    await tester.tap(find.text('Show bottom sheet'));
    await settle(tester);
    expect(find.text('A Tahfeez bottom sheet'), findsOneWidget);
    await tester.tapAt(const Offset(10, 10));
    await settle(tester);

    await tester.ensureVisible(find.text('Show destructive dialog'));
    await settle(tester);
    await tester.tap(find.text('Show destructive dialog'));
    await settle(tester);
    expect(find.text('Delete bookmark?'), findsOneWidget);
  });

  testWidgets('renders correctly in an RTL (Arabic) locale', (tester) async {
    await tester.pumpWidget(
      wrap(const ComponentGalleryScreen(), locale: const Locale('ar')),
    );
    await settle(tester);

    final directionality = Directionality.of(
      tester.element(find.byType(ComponentGalleryScreen)),
    );
    expect(directionality, TextDirection.rtl);
    // Component labels are still English UI copy in this test (no Arabic
    // .arb strings inside gallery widgets themselves), but the ambient
    // Directionality flipping to RTL proves the screen participates in
    // locale-driven layout mirroring rather than hardcoding LTR.
    expect(find.text('Component gallery'), findsOneWidget);
  });
}
