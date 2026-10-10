import 'package:flutter_test/flutter_test.dart';
import 'package:tahfeez_ai/features/mushaf/application/mushaf_word_overlay.dart';

void main() {
  test('showBefore keeps the words before the range shown', () {
    const first = (ayahId: 2005, wordIndex: 0);
    const last = (ayahId: 2005, wordIndex: 8);
    const before = (ayahId: 2004, wordIndex: 3);
    const inside = (ayahId: 2005, wordIndex: 2);
    const after = (ayahId: 2006, wordIndex: 0);
    const hiding = MushafWordOverlay(first: first, last: last);
    expect(hiding.isHidden(before), isTrue);
    const followAlong = MushafWordOverlay(
      first: first,
      last: last,
      showBefore: true,
    );
    expect(followAlong.isHidden(before), isFalse);
    expect(followAlong.isHidden(inside), isTrue);
    expect(followAlong.isHidden(after), isTrue);
  });
}
