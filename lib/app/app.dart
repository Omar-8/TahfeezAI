import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/localization/generated/app_localizations.dart';
import '../core/localization/locale_controller.dart';
import '../core/localization/supported_locales.dart';
import '../core/routing/app_router.dart';
import '../core/theme/app_theme.dart';
import '../core/theme/theme_controller.dart';

/// Tahfeez AI's root widget.
///
/// Wires together the three foundations this milestone proves — theme
/// (light/dark, `core/theme`), localization (RTL-capable, `core/localization`),
/// and routing (`core/routing`) — behind Riverpod so every piece is
/// independently swappable/testable, per this milestone's architecture
/// goals.
class TahfeezApp extends ConsumerWidget {
  const TahfeezApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeControllerProvider);
    final localeOverride = ref.watch(localeControllerProvider);
    final router = ref.watch(appRouterProvider);

    return MaterialApp.router(
      onGenerateTitle: (context) => AppLocalizations.of(context).appName,
      debugShowCheckedModeBanner: false,
      themeMode: themeMode,
      theme: buildLightTheme(),
      darkTheme: buildDarkTheme(),
      locale: localeOverride,
      supportedLocales: kTahfeezSupportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      routerConfig: router,
    );
  }
}
