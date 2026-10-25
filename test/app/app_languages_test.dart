import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tahfeez_ai/core/localization/generated/app_localizations.dart';

import '../test_helpers/real_app.dart';

/// Each UI language opens Home in its own text and direction — including the
/// ones Flutter's own (Material, Cupertino) strings lack (Hausa, Kurdish,
/// Somali), which fall back to English there.
void main() {
  setUpAll(RealApp.prepare);
  tearDownAll(RealApp.close);

  const rtl = {'ckb', 'ps'};
  for (final code in const ['ms', 'ha', 'ckb', 'ps', 'sw', 'kk', 'uz', 'so']) {
    testWidgets('$code: Home in its language and direction', (tester) async {
      await RealApp.launch(tester, locale: code);
      final context = tester.element(find.byType(Scaffold).first);
      expect(AppLocalizations.of(context).localeName, code);
      expect(
        Directionality.of(context),
        rtl.contains(code) ? TextDirection.rtl : TextDirection.ltr,
      );
      expect(find.text(AppLocalizations.of(context).navHome), findsWidgets);
      expect(tester.takeException(), isNull);
      await RealApp.quit(tester);
    });
  }
}
