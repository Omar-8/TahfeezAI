import '../core/localization/fallback_localizations.dart';
import '../features/guide/guide.dart';
import 'get_the_app_prompt.dart';
import '../features/recitation/presentation/web_model_preload.dart';
import '../features/memorize/presentation/milestone_banner.dart';

import 'package:dynamic_color/dynamic_color.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/localization/generated/app_localizations.dart';
import '../core/localization/locale_controller.dart';
import '../core/localization/supported_locales.dart';
import '../core/routing/app_router.dart';
import '../core/theme/app_surface_tone.dart';
import '../core/theme/app_theme.dart';
import '../core/theme/components/tahfeez_bottom_sheet.dart';
import '../core/theme/theme_controller.dart';
import '../features/memorize/application/memorization_reminder.dart';
import '../features/khatmah/application/khatmah_reminder.dart';
import '../quran/application/meaning_language_follower.dart';
import '../quran/presentation/meaning_packs_layer.dart';
import '../core/ui/animations_setting.dart';

/// TahfeezAI's root widget.
///
/// Wires together theme (light/dark/family/optional dynamic color,
/// `core/theme`), localization (RTL-capable, `core/localization`), and
/// routing (`core/routing`) — behind Riverpod so every piece is
/// independently swappable/testable.
class TahfeezApp extends ConsumerWidget {
  const TahfeezApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeControllerProvider);
    final family = ref.watch(themeFamilyControllerProvider);
    final useDynamicColor = ref.watch(dynamicColorPreferenceControllerProvider);
    final tone = ref.watch(appSurfaceToneProvider);
    final arabicFont = ref.watch(arabicFontControllerProvider);
    final localeOverride = ref.watch(localeControllerProvider);
    final router = ref.watch(appRouterProvider);
    // Started with the app: restores the daily reminder, reschedules it and
    // handles a tap on it.
    ref.listen(memorizationReminderProvider, (_, _) {});
    // The khatmah's: each day's pages, scheduled again as they change.
    ref.listen(khatmahReminderProvider, (_, _) {});
    // Translations, tafsir and word meanings follow the app's language.
    ref.listen(meaningLanguageFollowerProvider, (_, _) {});

    // DynamicColorBuilder provides the OS's Material You palette on
    // platforms that have one (Android 12+); `lightDynamic`/`darkDynamic`
    // are `null` everywhere else (iOS, web, older Android) — in which case
    // this always falls back to the selected TahfeezThemeFamily, per this
    // milestone's "support platform dynamic/system color only where
    // appropriate and optional" requirement.
    return DynamicColorBuilder(
      builder: (lightDynamic, darkDynamic) {
        final ColorScheme lightScheme;
        if (useDynamicColor && lightDynamic != null) {
          lightScheme = lightDynamic;
        } else {
          lightScheme = family.colorScheme(Brightness.light);
        }

        final ColorScheme darkScheme;
        if (useDynamicColor && darkDynamic != null) {
          darkScheme = darkDynamic;
        } else {
          darkScheme = family.colorScheme(Brightness.dark);
        }

        return MaterialApp.router(
          onGenerateTitle: (context) => AppLocalizations.of(context).appName,
          debugShowCheckedModeBanner: false,
          themeMode: themeMode,
          theme: buildTahfeezTheme(
            tone.apply(lightScheme),
            arabicFont: arabicFont,
          ),
          darkTheme: buildTahfeezTheme(
            tone.apply(darkScheme),
            arabicFont: arabicFont,
          ),
          locale: localeOverride,
          supportedLocales: kTahfeezSupportedLocales,
          localizationsDelegates: const [
            AppLocalizations.delegate,
            // First: for the UI languages Flutter lacks (Hausa, Kurdish,
            // Somali), before the global delegates would refuse them.
            ...kFallbackLocalizationsDelegates,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          routerConfig: router,
          // The Mushaf's guide, above every screen and menu.
          // and a milestone just reached, gently, over that.
          builder: (context, child) => _WebSheetWidth(
            // (In a phone's browser: where to get the app.)
            child: GetTheAppPrompt(
              // (In a browser: the recitation model, fetched meanwhile.)
              child: WebModelPreload(
                child: AnimationsOff(
                  child: MilestoneLayer(
                    child: MeaningPacksLayer(
                      child: GuideLayer(
                        child: child ?? const SizedBox.shrink(),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// In a wide browser window, every bottom sheet — those not sized by
/// [sheetBelowAppBar] too — as wide as the reading column
/// ([webSheetMaxWidth]); elsewhere the theme as it is.
class _WebSheetWidth extends StatelessWidget {
  const _WebSheetWidth({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final width = webSheetMaxWidth(context);
    if (width == double.infinity) return child;
    final theme = Theme.of(context);
    return Theme(
      data: theme.copyWith(
        bottomSheetTheme: theme.bottomSheetTheme.copyWith(
          constraints: BoxConstraints(maxWidth: width),
        ),
      ),
      child: child,
    );
  }
}
