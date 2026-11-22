import 'package:flutter_test/flutter_test.dart';
import 'package:tahfeez_ai/core/routing/last_screen.dart';

void main() {
  test('the screens opened again at start: the tabs, their screens and '
      'Quran places — nothing else', () {
    for (final ok in [
      '/home',
      '/quran',
      '/memorize',
      '/quran/page/1/40',
      '/home/ayah/2/153',
    ]) {
      expect(restorableScreen(ok), isTrue, reason: ok);
    }
    for (final no in [
      null,
      '',
      'home',
      '/debug/gallery',
      '/nowhere',
      '/quran/page',
      // Over a tab (the side menu's): nothing beneath them to go back to.
      '/settings',
      '/settings/about',
      '/qibla',
    ]) {
      expect(restorableScreen(no), isFalse, reason: '$no');
    }
  });
}
