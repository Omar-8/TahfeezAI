import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tahfeez_ai/features/listen/presentation/follow_along_sheet.dart';
import 'package:tahfeez_ai/features/recitation/application/hifz_controller.dart';
import 'package:tahfeez_ai/features/recitation/presentation/recitation_loop_sheet.dart';

import '../test_helpers/real_app.dart';

/// Strict is one setting: Hifz settings', Loop's and Follow along's
/// switches all show it and all change it.
void main() {
  setUpAll(RealApp.prepare);
  tearDownAll(RealApp.close);

  testWidgets('Strict: one setting in Hifz settings, Loop and Follow along', (
    tester,
  ) async {
    final container = await RealApp.launch(tester, route: '/quran/surah/112');
    bool strict() => container.read(hifzSettingsProvider).strict;
    bool shown(String key) =>
        tester.widget<SwitchListTile>(find.byKey(ValueKey(key))).value;
    Future<void> open(void Function(BuildContext) sheet) async {
      sheet(tester.element(find.byType(Scaffold).last));
      await tester.pumpAndSettle();
    }

    // From inside the sheet (its switch [key]).
    Future<void> close(String key) async {
      Navigator.of(tester.element(find.byKey(ValueKey(key)))).pop();
      await tester.pumpAndSettle();
      expect(find.byKey(ValueKey(key)), findsNothing);
    }

    Future<void> flip(String key) async {
      await tester.ensureVisible(find.byKey(ValueKey(key)));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(ValueKey(key)));
      await tester.pumpAndSettle();
    }

    // Off until chosen.
    expect(strict(), isFalse);

    // Loop: shows it, and turns it on for all.
    await open((c) => showRecitationLoopSheet(c));
    expect(shown('loop-strict'), isFalse);
    await flip('loop-strict');
    expect(strict(), isTrue);
    await close('loop-strict');

    // Follow along: on too, and turns it back off for all.
    await open((c) => showFollowAlongSheet(c));
    expect(shown('follow-strict'), isTrue);
    await flip('follow-strict');
    expect(strict(), isFalse);
    await close('follow-strict');

    await open((c) => showRecitationLoopSheet(c));
    expect(shown('loop-strict'), isFalse);
    await close('loop-strict');

    // Hifz settings' own switch, the same setting.
    container
        .read(hifzSettingsProvider.notifier)
        .update(container.read(hifzSettingsProvider).copyWith(strict: true));
    await open((c) => showFollowAlongSheet(c));
    expect(shown('follow-strict'), isTrue);
    await close('follow-strict');

    await RealApp.quit(tester);
  });
}
