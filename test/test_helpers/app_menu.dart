import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

/// Opens the side menu (☰ on the tab on screen) and its [entry]: `qibla`,
/// `bookmarks`, `settings` or `about` (owner, 2026-11-20: Settings left the
/// tab bar for the menu).
Future<void> openFromMenu(WidgetTester tester, String entry) async {
  await tester.tap(find.byKey(const ValueKey('app-menu')).hitTestable().first);
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(ValueKey('menu-$entry')));
  await tester.pumpAndSettle();
}
