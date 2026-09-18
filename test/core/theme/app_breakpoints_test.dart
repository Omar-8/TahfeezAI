import 'package:flutter_test/flutter_test.dart';
import 'package:tahfeez_ai/core/theme/app_breakpoints.dart';

void main() {
  group('TahfeezBreakpoint.fromWidth', () {
    test('classifies phone widths', () {
      expect(TahfeezBreakpoint.fromWidth(320), TahfeezBreakpoint.phone);
      expect(TahfeezBreakpoint.fromWidth(599.9), TahfeezBreakpoint.phone);
    });

    test('classifies tablet widths', () {
      expect(TahfeezBreakpoint.fromWidth(600), TahfeezBreakpoint.tablet);
      expect(TahfeezBreakpoint.fromWidth(1023.9), TahfeezBreakpoint.tablet);
    });

    test('classifies desktop widths', () {
      expect(TahfeezBreakpoint.fromWidth(1024), TahfeezBreakpoint.desktop);
      expect(TahfeezBreakpoint.fromWidth(2560), TahfeezBreakpoint.desktop);
    });
  });
}
