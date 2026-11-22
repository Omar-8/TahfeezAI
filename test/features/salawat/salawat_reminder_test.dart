import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tahfeez_ai/core/storage/storage_providers.dart';
import 'package:tahfeez_ai/features/salawat/salawat_reminder.dart';

import '../../test_helpers/app_menu.dart';
import '../../test_helpers/real_app.dart';

/// As the app opens, the ṣalawāt reminder (owner, 2026-11-20): on unless
/// turned off, in the reminder itself or in Settings; never over the first
/// run's setup.
void main() {
  setUpAll(RealApp.prepare);
  tearDownAll(RealApp.close);

  final reminder = find.byKey(const ValueKey('salawat-reminder'));

  /// The app opened, its first run's welcome [welcomed] or not.
  Future<ProviderContainer> open(
    WidgetTester tester, {
    bool welcomed = true,
  }) async {
    // The welcome's mark set (or cleared) as the last run left it.
    final setup = await RealApp.launch(tester);
    final storage = setup.read(browserStorageProvider);
    await tester.runAsync(() async {
      if (welcomed) {
        await storage.setBool('firstRun.welcome', true);
      } else {
        await storage.remove('firstRun.welcome');
      }
    });
    await RealApp.quit(tester);
    SalawatOnStart.shownThisLaunch = false;
    final container = await RealApp.launch(tester, firstRun: true);
    await RealApp.settle(tester);
    await tester.pump(SalawatOnStart.delay);
    await tester.pumpAndSettle();
    return container;
  }

  testWidgets('shown as the app opens; "Don\'t show this again" turns it '
      'off, and Settings back on', (tester) async {
    await open(tester);
    expect(reminder, findsOneWidget);
    expect(
      find.text('اللَّهُمَّ صَلِّ وَسَلِّمْ عَلَى نَبِيِّنَا مُحَمَّدٍ'),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const ValueKey('salawat-never')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('salawat-close')));
    await RealApp.settle(tester);
    expect(reminder, findsNothing);
    await RealApp.quit(tester);

    // Off: not on the next opening.
    await open(tester);
    expect(reminder, findsNothing);

    // Settings: off, and turned on again.
    await openFromMenu(tester, 'settings');
    final group = find.byKey(
      const ValueKey('settings-group-Ṣalawāt on the Prophet ﷺ'),
    );
    await tester.scrollUntilVisible(group, 200, scrollable: _list);
    await tester.tap(group);
    await tester.pumpAndSettle();
    final toggle = find.byKey(const ValueKey('settings-salawat'));
    expect(tester.widget<SwitchListTile>(toggle).value, isFalse);
    await tester.tap(toggle);
    await RealApp.settle(tester);
    expect(tester.widget<SwitchListTile>(toggle).value, isTrue);
    await RealApp.quit(tester);

    await open(tester);
    expect(reminder, findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('salawat-close')));
    await RealApp.settle(tester);
    await RealApp.quit(tester);
  });

  testWidgets('not on the first run: its setup comes first', (tester) async {
    await open(tester, welcomed: false);
    expect(reminder, findsNothing);
    await RealApp.quit(tester);
  });
}

final _list = find.byType(Scrollable).first;
