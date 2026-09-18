import 'package:flutter_test/flutter_test.dart';
import 'package:tahfeez_ai/core/theme/app_breakpoints.dart';

void main() {
  group('AppBreakpoint.fromWidth', () {
    test('classifies phone widths', () {
      expect(AppBreakpoint.fromWidth(320), AppBreakpoint.phone);
      expect(AppBreakpoint.fromWidth(599.9), AppBreakpoint.phone);
    });

    test('classifies tablet widths', () {
      expect(AppBreakpoint.fromWidth(600), AppBreakpoint.tablet);
      expect(AppBreakpoint.fromWidth(1023.9), AppBreakpoint.tablet);
    });

    test('classifies desktop widths', () {
      expect(AppBreakpoint.fromWidth(1024), AppBreakpoint.desktop);
      expect(AppBreakpoint.fromWidth(2560), AppBreakpoint.desktop);
    });
  });
}
