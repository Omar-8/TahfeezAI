import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../test_helpers/real_app.dart';

/// Home's shortcuts as one group (owner, 2026-11-23): all four in view
/// without scrolling — on a narrow phone, in long languages, at large
/// text — each a full tap target.
void main() {
  setUpAll(RealApp.prepare);
  tearDownAll(RealApp.close);

  const keys = ['home-qibla', 'home-athkar', 'home-duas', 'home-habits'];

  for (final (name, size, locale, scale) in [
    ('phone', const Size(390, 844), 'en', 1.0),
    ('narrow phone', const Size(320, 640), 'en', 1.0),
    ('phone, German', const Size(390, 844), 'de', 1.0),
    ('phone, Arabic', const Size(390, 844), 'ar', 1.0),
    ('phone, text ×1.5', const Size(390, 844), 'en', 1.5),
    ('tablet', const Size(1032, 1376), 'en', 1.0),
  ]) {
    testWidgets('$name: all four in the group, none off it', (tester) async {
      await RealApp.launch(
        tester,
        size: size,
        locale: locale,
        textScale: scale,
      );
      RealApp.fits(tester, 'Home on $name');
      expect(
        find
            .byType(SingleChildScrollView)
            .evaluate()
            .where((e) => (e.widget.key == const ValueKey('home-shortcuts'))),
        isEmpty,
      );
      final group = tester.getRect(
        find.byKey(const ValueKey('home-shortcuts')),
      );
      expect(group.right, lessThanOrEqualTo(size.width));
      for (final k in keys) {
        final r = tester.getRect(find.byKey(ValueKey(k)));
        expect(r.left, greaterThanOrEqualTo(group.left - 0.5), reason: k);
        expect(r.right, lessThanOrEqualTo(group.right + 0.5), reason: k);
        expect(r.height, greaterThanOrEqualTo(48), reason: k);
      }
      // One size for all four names (owner, 2026-11-23): the same height
      // on screen, however long one of them is.
      final heights = {
        for (final k in keys)
          tester
              .getSize(
                find.descendant(
                  of: find.byKey(ValueKey(k)),
                  matching: find.byType(Text),
                ),
              )
              .height
              .toStringAsFixed(1),
      };
      expect(heights, hasLength(1), reason: '$heights');
      await RealApp.quit(tester);
    });
  }
}
