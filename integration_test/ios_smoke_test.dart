// The iOS build's first check (CI, a simulator — .github/workflows/ios.yml):
// the app starts, Home shows, and the Mushaf renders with the native
// engine. Screenshots of each go to the driver (test_driver/).
//
//   flutter drive --driver=test_driver/integration_test.dart \
//     --target=integration_test/ios_smoke_test.dart -d <simulator>
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:integration_test/integration_test.dart';
import 'package:qvp_flutter/qvp_flutter.dart';
import 'package:tahfeez_ai/app/bootstrap.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('starts, shows Home, and the Mushaf renders', (tester) async {
    await bootstrap();
    // Frames for [seconds] (the app animates, so it never settles).
    Future<void> run(int seconds) async {
      for (var i = 0; i < seconds * 10; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
    }

    await run(20); // the first launch seeds the Quran database
    await binding.takeScreenshot('1-home');

    final router = GoRouter.of(tester.element(find.byType(Navigator).first));
    for (final (surah, name) in [(1, 'al-fatiha'), (2, 'al-baqarah')]) {
      router.go('/quran/surah/$surah');
      await run(10);
      await binding.takeScreenshot('${surah + 1}-mushaf-$name');
      expect(
        find.byType(QvpPageView),
        findsWidgets,
        reason: 'the native engine draws the page',
      );
    }
  });
}
