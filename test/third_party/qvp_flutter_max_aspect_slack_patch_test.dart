// Verifies Tahfeez's local patch to the vendored qvp_flutter package
// (third_party/qvp_flutter/PATCHES.md) behaves exactly as documented:
// QvpViewLayout.maxAspectSlack, left unset, must reproduce the exact
// upstream default (QvpDefaults.aspectSlack, 1.15) with no behavior
// change for any existing call site, and an explicit value must flow
// through to QvpLayoutSpec unchanged. This only exercises the pure-Dart
// value objects (QvpViewLayout.toSpec()) -- no native qvp_ffi call
// happens here, so it runs under a plain `flutter test`, no device or
// emulator needed.
import 'package:flutter_test/flutter_test.dart';
import 'package:qvp_flutter/qvp_flutter.dart';

void main() {
  group('QvpViewLayout.maxAspectSlack (Tahfeez patch)', () {
    test('left unset, toSpec() reproduces the exact upstream default '
        '(QvpDefaults.aspectSlack) -- unpatched behavior for every '
        'existing call site', () {
      const layout = QvpViewLayout();
      final spec = layout.toSpec(400, 800);
      expect(spec.maxAspectSlack, QvpDefaults.aspectSlack);
      expect(spec.maxAspectSlack, 1.15);
    });

    test('explicit 0 (Tahfeez\'s Mushaf-page override) flows through to '
        'QvpLayoutSpec unchanged -- "no bound", per QvpLayoutSpec.'
        'maxAspectSlack\'s own doc comment', () {
      const layout = QvpViewLayout(maxAspectSlack: 0);
      final spec = layout.toSpec(400, 800);
      expect(spec.maxAspectSlack, 0);
    });

    test('any other explicit value flows through unchanged too', () {
      const layout = QvpViewLayout(maxAspectSlack: 2.5);
      final spec = layout.toSpec(400, 800);
      expect(spec.maxAspectSlack, 2.5);
    });

    test('participates in equality/hashCode (copyWith round-trip)', () {
      const a = QvpViewLayout(maxAspectSlack: 0);
      final b = a.copyWith();
      final c = a.copyWith(maxAspectSlack: 1.15);
      expect(b, a);
      expect(b.hashCode, a.hashCode);
      expect(c, isNot(a));
    });

    test('every other QvpViewLayout field is untouched by this patch -- '
        'defaults match upstream exactly', () {
      const layout = QvpViewLayout();
      expect(layout.padTop, 24);
      expect(layout.padBottom, 24);
      expect(layout.padSide, 16);
      expect(layout.lineSpacing, 1);
      expect(layout.fillHeight, false);
      expect(layout.gridLines, 0);
      expect(layout.maxAspectSlack, isNull);
    });
  });
}
