import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:tahfeez_ai/core/localization/generated/app_localizations.dart';
import 'package:tahfeez_ai/core/routing/app_routes.dart';
import 'package:tahfeez_ai/features/bookmarks/presentation/bookmarks_screen.dart';
import 'package:tahfeez_ai/features/quran/application/quran_index_providers.dart';

/// No bookmarks yet: how to make one, and one step to the Qur'an.
void main() {
  testWidgets('no bookmarks: Open the Qur\'an opens the Qur\'an tab', (
    tester,
  ) async {
    final router = GoRouter(
      initialLocation: '/bookmarks',
      routes: [
        GoRoute(
          path: '/bookmarks',
          builder: (context, state) => const BookmarksScreen(),
        ),
        GoRoute(
          path: AppRoutes.quran,
          builder: (context, state) => const Text('the Qur\'an tab'),
        ),
      ],
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [indexedSurahsProvider.overrideWith((ref) async => [])],
        child: MaterialApp.router(
          routerConfig: router,
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: const [Locale('en')],
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('No bookmarks yet.'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('bookmarks-open-quran')));
    await tester.pumpAndSettle();
    expect(find.text('the Qur\'an tab'), findsOneWidget);
  });
}
