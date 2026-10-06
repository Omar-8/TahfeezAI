import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/generated/app_localizations.dart';
import '../../../core/localization/locale_controller.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/components/components.dart';
import '../../../core/theme/app_surface_tone.dart';
import '../../../core/theme/theme_controller.dart';
import 'theme_choices.dart';

/// The Settings tab: the app's language and theme (the Quran page's own
/// theme is chosen in the Mushaf, independently, so the two can be mixed).
/// Every choice is persisted by its controller ([LocaleController],
/// [ThemeModeController] with [AppSurfaceToneController]) and applies at
/// once.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final locale = ref.watch(localeControllerProvider);
    final appTheme = AppThemeChoice.of(
      ref.watch(themeModeControllerProvider),
      ref.watch(appSurfaceToneProvider),
    );

    Widget group(String title, IconData icon, Widget child) => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: TahfeezSpacing.sm,
      children: [
        TahfeezSectionHeader(title: title, icon: icon),
        TahfeezCard(child: child),
      ],
    );

    return Scaffold(
      appBar: TahfeezAppBar(
        title: Text(l10n.settingsTitle),
        centerTitle: false,
      ),
      body: ListView(
        padding: const EdgeInsets.all(TahfeezSpacing.md),
        children: [
          group(
            l10n.settingsLanguage,
            Icons.translate,
            RadioGroup<String>(
              groupValue: locale?.languageCode ?? '',
              onChanged: (code) => ref
                  .read(localeControllerProvider.notifier)
                  .setLocale(
                    code == null || code.isEmpty ? null : Locale(code),
                  ),
              child: Column(
                children: [
                  for (final (code, label) in [
                    ('', l10n.settingsLanguageSystem),
                    ('en', 'English'),
                    ('ar', 'العربية'),
                  ])
                    RadioListTile<String>(
                      value: code,
                      title: Text(label, style: theme.textTheme.bodyLarge),
                      contentPadding: EdgeInsets.zero,
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: TahfeezSpacing.lg),
          group(
            l10n.settingsAppTheme,
            Icons.palette_outlined,
            Wrap(
              key: const ValueKey('settings-app-theme'),
              spacing: TahfeezSpacing.sm,
              runSpacing: TahfeezSpacing.sm,
              children: [
                for (final choice in AppThemeChoice.values)
                  ChoiceChip(
                    avatar: choice == AppThemeChoice.system
                        ? const Icon(Icons.brightness_auto_outlined)
                        : ThemeSwatch(paper: _paper(choice), ink: _ink(choice)),
                    label: Text(choice.label(l10n)),
                    selected: choice == appTheme,
                    showCheckmark: false,
                    onSelected: (_) {
                      ref
                          .read(themeModeControllerProvider.notifier)
                          .setThemeMode(choice.mode);
                      ref
                          .read(appSurfaceToneProvider.notifier)
                          .setTone(choice.tone);
                    },
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// A theme choice's paper and ink, for its swatch.
Color _paper(AppThemeChoice c) =>
    c.tone.surface ??
    (c.mode == ThemeMode.dark
        ? const Color(0xFF171D1A)
        : const Color(0xFFFFFFFF));

Color _ink(AppThemeChoice c) =>
    c.tone.onSurface ??
    (c.mode == ThemeMode.dark
        ? const Color(0xFFECF2EF)
        : const Color(0xFF1C1C1C));
