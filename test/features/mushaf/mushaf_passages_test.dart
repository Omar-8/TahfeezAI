import 'package:flutter_test/flutter_test.dart';
import 'package:tahfeez_ai/features/mushaf/application/mushaf_passages.dart';

void main() {
  test('every passage has a tint, never the same as the one before', () {
    final tints = passageTints(556);
    expect(tints, hasLength(556));
    for (var i = 1; i < tints.length; i++) {
      expect(tints[i], isNot(tints[i - 1]), reason: 'passages $i and ${i + 1}');
    }
    expect(tints.toSet(), hasLength(passagePalette.length), reason: 'all used');
    expect(passageTints(556), tints, reason: 'the same colours every time');
  });
}
