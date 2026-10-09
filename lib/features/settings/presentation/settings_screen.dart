import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show SystemNavigator;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/core_providers.dart';
import '../../../core/localization/generated/app_localizations.dart';
import '../../../core/routing/app_routes.dart';
import '../../../core/localization/locale_controller.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/components/components.dart';
import '../../../core/theme/app_surface_tone.dart';
import '../../../core/notifications/daily_reminder_scheduler.dart';
import '../../../core/theme/app_typography.dart';
import '../../memorize/application/memorization_reminder.dart';
import '../../../core/theme/theme_controller.dart';
import '../../../quran/application/ayah_sheet_content.dart';
import '../../../quran/application/tafsir_library_controller.dart';
import '../../../quran/application/tafsir_selection_controller.dart';
import '../../../quran/presentation/tafsir_packs_sheet.dart';
import '../../../quran/presentation/translation_packs_sheet.dart';
import '../../../wbw/application/wbw_preferences_controller.dart';
import '../../mushaf/application/mushaf_page_translations.dart';
import '../application/reset_all_data.dart';
import '../../listen/application/reciter_controller.dart';
import '../../listen/domain/quran_audio_sources.dart';
import '../../listen/presentation/listen_sheet.dart';
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
    final arabicFont = ref.watch(arabicFontControllerProvider);
    final reminderSupported = ref
        .watch(dailyReminderSchedulerProvider)
        .supported;
    final reminder = ref.watch(memorizationReminderProvider);
    final reminderTime = TimeOfDay(
      hour: reminder.minutes ~/ 60,
      minute: reminder.minutes % 60,
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
          const SizedBox(height: TahfeezSpacing.lg),
          group(
            l10n.settingsArabicFont,
            Icons.font_download_outlined,
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: TahfeezSpacing.smPlus,
              children: [
                Wrap(
                  key: const ValueKey('settings-arabic-font'),
                  spacing: TahfeezSpacing.sm,
                  runSpacing: TahfeezSpacing.sm,
                  children: [
                    for (final font in ArabicUiFont.values)
                      ChoiceChip(
                        key: ValueKey('settings-arabic-font-${font.name}'),
                        // Each name in its own font.
                        label: Text(
                          font.arabicName,
                          style: TextStyle(fontFamily: font.family),
                        ),
                        selected: font == arabicFont,
                        showCheckmark: false,
                        onSelected: (_) => ref
                            .read(arabicFontControllerProvider.notifier)
                            .setFont(font),
                      ),
                  ],
                ),
                Text(
                  'مساء الخير · آية اليوم · متابعة القراءة',
                  textDirection: TextDirection.rtl,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    fontFamily: arabicFont.family,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: TahfeezSpacing.lg),
          group(
            l10n.readerTranslationTafsir,
            Icons.translate_outlined,
            const _MeaningSettings(),
          ),
          const SizedBox(height: TahfeezSpacing.lg),
          group(
            l10n.listenTitle,
            Icons.headphones_outlined,
            const _ListenSettings(),
          ),
          if (reminderSupported) ...[
            const SizedBox(height: TahfeezSpacing.lg),
            group(
              l10n.memReminderTitle,
              Icons.notifications_outlined,
              Column(
                children: [
                  SwitchListTile(
                    key: const ValueKey('settings-reminder'),
                    contentPadding: EdgeInsets.zero,
                    title: Text(l10n.memReminderSwitch),
                    subtitle: Text(
                      l10n.memReminderAt(reminderTime.format(context)),
                    ),
                    value: reminder.enabled,
                    onChanged: (on) async {
                      final messenger = ScaffoldMessenger.of(context);
                      final done = await ref
                          .read(memorizationReminderProvider.notifier)
                          .setEnabled(on);
                      if (!done) {
                        messenger.showSnackBar(
                          SnackBar(content: Text(l10n.memReminderDenied)),
                        );
                      }
                    },
                  ),
                  ListTile(
                    key: const ValueKey('settings-reminder-time'),
                    contentPadding: EdgeInsets.zero,
                    enabled: reminder.enabled,
                    leading: const Icon(Icons.schedule),
                    title: Text(l10n.memReminderTime),
                    trailing: Text(reminderTime.format(context)),
                    onTap: () async {
                      final picked = await showTimePicker(
                        context: context,
                        initialTime: reminderTime,
                      );
                      if (picked == null) return;
                      await ref
                          .read(memorizationReminderProvider.notifier)
                          .setTime(picked.hour * 60 + picked.minute);
                    },
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: TahfeezSpacing.lg),
          TahfeezCard(
            child: ListTile(
              key: const ValueKey('settings-about'),
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.info_outline),
              title: Text(l10n.aboutTitle),
              subtitle: Text(l10n.aboutSubtitle),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.push(AppRoutes.about),
            ),
          ),
          const SizedBox(height: TahfeezSpacing.lg),
          TahfeezCard(
            child: ListTile(
              key: const ValueKey('settings-reset'),
              contentPadding: EdgeInsets.zero,
              leading: Icon(
                Icons.delete_forever_outlined,
                color: theme.colorScheme.error,
              ),
              title: Text(
                l10n.settingsResetTitle,
                style: TextStyle(color: theme.colorScheme.error),
              ),
              subtitle: Text(l10n.settingsResetSub),
              onTap: () => _confirmReset(context, ref),
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

/// Settings → Translation & tafsir: what the ayah sheet shows, and whether
/// word meanings show the transliteration too.
class _MeaningSettings extends ConsumerWidget {
  const _MeaningSettings();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final books = ref.watch(activeTranslationBooksProvider).value;
    final tafsirId = ref.watch(tafsirSelectionControllerProvider);
    final tafsirName = [
      for (final t in ref.watch(tafsirLibraryControllerProvider).value ?? [])
        if (t.work.id == tafsirId) t.work.displayName,
    ].firstOrNull;
    final content = ref.watch(ayahSheetContentProvider);
    final transliteration = ref.watch(
      wbwShowTransliterationPreferenceControllerProvider,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ListTile(
          key: const ValueKey('settings-translations'),
          contentPadding: EdgeInsets.zero,
          title: Text(l10n.searchTranslations),
          subtitle: Text(
            books == null || books.isEmpty
                ? l10n.readerSelected(0)
                : [for (final b in books.values) b.author].join(', '),
          ),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => showTranslationPacksSheet(context),
        ),
        ListTile(
          key: const ValueKey('settings-tafsir'),
          contentPadding: EdgeInsets.zero,
          title: Text(l10n.readerTafsir),
          subtitle: Text(tafsirName ?? l10n.settingsTafsirNone),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => showTafsirPacksSheet(context),
        ),
        const SizedBox(height: TahfeezSpacing.sm),
        Text(
          l10n.settingsLongPressShows,
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: TahfeezSpacing.sm),
        SegmentedButton<AyahSheetContent>(
          key: const ValueKey('settings-ayah-sheet-content'),
          showSelectedIcon: false,
          segments: [
            ButtonSegment(
              value: AyahSheetContent.translation,
              label: Text(l10n.settingsShowTranslation),
            ),
            ButtonSegment(
              value: AyahSheetContent.tafsir,
              label: Text(l10n.settingsShowTafsir),
            ),
            ButtonSegment(
              value: AyahSheetContent.both,
              label: Text(l10n.settingsShowBoth),
            ),
          ],
          selected: {content},
          onSelectionChanged: (s) =>
              ref.read(ayahSheetContentProvider.notifier).set(s.first),
        ),
        const SizedBox(height: TahfeezSpacing.sm),
        SwitchListTile(
          key: const ValueKey('settings-transliteration'),
          contentPadding: EdgeInsets.zero,
          title: Text(l10n.settingsTransliteration),
          value: transliteration,
          onChanged: (on) => ref
              .read(wbwShowTransliterationPreferenceControllerProvider.notifier)
              .setEnabled(on),
        ),
      ],
    );
  }
}

/// Asks before deleting everything; then, on Android, closes the app so it
/// opens fresh (elsewhere: asks for a reload).
Future<void> _confirmReset(BuildContext context, WidgetRef ref) async {
  final l10n = AppLocalizations.of(context);
  final scheme = Theme.of(context).colorScheme;
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(l10n.settingsResetConfirmTitle),
      content: Text(l10n.settingsResetConfirmBody),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(l10n.commonCancel),
        ),
        FilledButton(
          key: const ValueKey('settings-reset-confirm'),
          style: FilledButton.styleFrom(
            backgroundColor: scheme.error,
            foregroundColor: scheme.onError,
          ),
          onPressed: () => Navigator.of(context).pop(true),
          child: Text(l10n.settingsResetConfirm),
        ),
      ],
    ),
  );
  if (confirmed != true || !context.mounted) return;
  final android = ref.read(platformCapabilitiesProvider).isAndroid;
  final messenger = ScaffoldMessenger.of(context);
  await resetAllData(ref);
  if (android) {
    await SystemNavigator.pop();
  } else {
    messenger.showSnackBar(SnackBar(content: Text(l10n.settingsResetDone)));
  }
}

/// Settings → Recitation audio: the reciter heard in the Mushaf.
class _ListenSettings extends ConsumerWidget {
  const _ListenSettings();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final reciter = reciterFor(ref.watch(reciterProvider));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ListTile(
          key: const ValueKey('settings-reciter'),
          contentPadding: EdgeInsets.zero,
          title: Text(l10n.listenReciter),
          subtitle: Text(reciterName(context, reciter)),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => showReciterSheet(context),
        ),
        Text(
          l10n.listenSourcesNote,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}
