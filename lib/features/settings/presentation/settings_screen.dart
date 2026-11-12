import 'package:file_picker/file_picker.dart';

import '../../../core/sharing/image_sharer.dart';
import '../../../core/ui/bar_space.dart';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show SystemNavigator;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../home/presentation/home_sky.dart';
import '../../../core/core_providers.dart';
import '../../../core/localization/generated/app_localizations.dart';
import '../../../core/routing/app_routes.dart';
import '../../../core/localization/locale_controller.dart';
import '../../../core/localization/supported_locales.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/components/components.dart';
import '../../../core/theme/app_surface_tone.dart';
import '../../../core/notifications/daily_reminder_scheduler.dart';
import '../../../core/theme/app_typography.dart';
import '../../memorize/application/memorization_reminder.dart';
import '../../../core/theme/theme_controller.dart';
import '../../../quran/application/tafsir_library_controller.dart';
import '../../../quran/application/tafsir_selection_controller.dart';
import '../../../quran/presentation/tafsir_packs_sheet.dart';
import '../../../quran/presentation/translation_packs_sheet.dart';
import '../../../wbw/application/wbw_preferences_controller.dart';
import '../../mushaf/application/mushaf_page_translations.dart';
import '../application/problem_report.dart';
import '../application/reset_all_data.dart';
import '../application/user_data_backup.dart';
import '../../../core/app_store/app_store_service.dart';
import '../../../core/app_store/store_prompts.dart';
import '../../home/presentation/home_store_prompts.dart' show showUpdateOffer;
import '../../../core/storage/storage_providers.dart';
import '../../../memorization/memorization_providers.dart';
import '../../listen/application/reciter_downloads.dart';
import '../../listen/application/reciter_controller.dart';
import '../../recitation/application/hifz_controller.dart';
import '../../listen/domain/quran_audio_sources.dart';
import '../../listen/presentation/listen_sheet.dart';
import '../../listen/presentation/reciter_avatar.dart';
import 'arabic_font_choices.dart';
import 'theme_choices.dart';
import '../../../quran/presentation/meaning_resource_names.dart';
import '../../../core/ui/back_to_exit.dart';
import '../../../core/ui/app_name_text.dart';
import '../../../core/ui/animations_setting.dart';
import '../../../core/theme/tahfeez_motion.dart';

/// The Settings tab: the app's language and theme (the Quran page's own
/// theme is chosen in the Mushaf, independently, so the two can be mixed).
/// Every choice is persisted by its controller ([LocaleController],
/// [ThemeModeController] with [AppSurfaceToneController]) and applies at
/// once.
///
/// Compact, with a search over every section's options.
class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  var _query = '';
  final _listKey = GlobalKey();

  /// Lower case, Arabic vowel marks dropped.
  static String _fold(String s) =>
      s.toLowerCase().replaceAll(RegExp('[\u064B-\u065F\u0670]'), '');

  void _search(String text) {
    setState(() => _query = text);
    if (_fold(text.trim()).length < 2) return;
    // The first option found brought into view (it is highlighted), once
    // its section has opened.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Future<void>.delayed(const Duration(milliseconds: 220), () {
        if (!mounted || _query != text) return;
        final list = _listKey.currentContext;
        if (list == null) return;
        Element? first;
        void visit(Element e) {
          if (first != null) return;
          if (e.widget case _SearchText(:final text)
              when _fold(text).contains(_fold(_query.trim()))) {
            first = e;
            return;
          }
          e.visitChildElements(visit);
        }

        (list as Element).visitChildElements(visit);
        if (first case final found?) {
          Scrollable.ensureVisible(
            found,
            alignment: 0.3,
            duration: TahfeezMotionDuration.medium,
            curve: Curves.easeOutCubic,
          );
        }
      });
    });
  }

  @override
  Widget build(BuildContext context) {
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

    // Each section with the words it is found by (its options' names).
    // The most used at the top, the others below — every one collapsed to
    // its header (owner, 2026-11-07/08) — opened, as they always look; a search
    // opens those it finds.
    final searching = _query.trim().isNotEmpty;
    final sections = <({List<String> words, Widget widget, bool collapsed})>[];
    void group(
      String title,
      IconData icon,
      Widget child, {
      List<String> words = const [],
      bool collapsed = false,
      String? summary,
      Widget? summaryLeading,
    }) {
      final card = TahfeezCard(
        padding: const EdgeInsets.symmetric(
          horizontal: TahfeezSpacing.md,
          vertical: TahfeezSpacing.sm,
        ),
        child: child,
      );
      sections.add((
        words: [title, ...words],
        collapsed: collapsed,
        // Every one closed at first, the most used at the top (owner,
        // 2026-11-08).
        widget: TahfeezCollapsibleSection(
          key: ValueKey('settings-group-$title'),
          title: title,
          icon: icon,
          summary: summary,
          summaryLeading: summaryLeading,
          open: searching,
          child: card,
        ),
      ));
    }

    return BackToExit(
      child: SkyBackdrop(
        child: Scaffold(
          appBar: TahfeezAppBar(
            title: Text(l10n.settingsTitle),
            centerTitle: false,
          ),
          body: Builder(
            builder: (context) {
              // Built afresh each time: this builder runs again on its own
              // (the keyboard closing changes the bottom space), and every
              // section added twice broke the list — the page frozen, the
              // search field not tappable.
              sections.clear();
              group(
                l10n.settingsLanguage,
                Icons.translate,
                _LanguageRow(
                  key: const ValueKey('settings-language'),
                  code: locale?.languageCode ?? '',
                  onChanged: (code) => ref
                      .read(localeControllerProvider.notifier)
                      .setLocale(code.isEmpty ? null : Locale(code)),
                ),
                words: [
                  l10n.settingsLanguageSystem,
                  for (final (_, _, name) in kAppLanguages) name,
                ],
                summary:
                    [
                      for (final (code, _, name) in kAppLanguages)
                        if (code == locale?.languageCode) name,
                    ].firstOrNull ??
                    l10n.settingsLanguageSystem,
              );
              group(
                l10n.settingsAppTheme,
                Icons.palette_outlined,
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Wrap(
                      key: const ValueKey('settings-app-theme'),
                      spacing: TahfeezSpacing.sm,
                      runSpacing: TahfeezSpacing.sm,
                      children: [
                        for (final choice in AppThemeChoice.values)
                          ChoiceChip(
                            avatar: choice == AppThemeChoice.system
                                ? const Icon(Icons.brightness_auto_outlined)
                                : ThemeSwatch(
                                    paper: _paper(choice),
                                    ink: _ink(choice),
                                  ),
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
                    SwitchListTile(
                      key: const ValueKey('settings-time-of-day'),
                      contentPadding: EdgeInsets.zero,
                      title: _SearchText(l10n.settingsTimeOfDay),
                      subtitle: _SearchText(l10n.settingsTimeOfDaySub),
                      value: ref.watch(homeSkyProvider),
                      onChanged: (on) =>
                          ref.read(homeSkyProvider.notifier).setEnabled(on),
                    ),
                    SwitchListTile(
                      key: const ValueKey('settings-animations'),
                      contentPadding: EdgeInsets.zero,
                      title: _SearchText(l10n.settingsAnimations),
                      subtitle: _SearchText(l10n.settingsAnimationsSub),
                      value: ref.watch(animationsProvider),
                      onChanged: (on) =>
                          ref.read(animationsProvider.notifier).setEnabled(on),
                    ),
                  ],
                ),
                words: [
                  for (final c in AppThemeChoice.values) c.label(l10n),
                  l10n.settingsTimeOfDay,
                  l10n.settingsTimeOfDaySub,
                  l10n.settingsAnimations,
                  l10n.settingsAnimationsSub,
                ],
                summary: appTheme.label(l10n),
              );
              group(
                l10n.settingsArabicFont,
                Icons.font_download_outlined,
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  spacing: TahfeezSpacing.smPlus,
                  children: [
                    const ArabicFontChoices(),
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
                words: [for (final f in ArabicUiFont.values) f.arabicName],
                summary: arabicFont.arabicName,
                collapsed: true,
              );
              group(
                l10n.readerTranslationTafsir,
                Icons.translate_outlined,
                const _MeaningSettings(),
                words: [
                  l10n.searchTranslations,
                  l10n.readerTafsir,
                  l10n.settingsTransliteration,
                ],
                summary: _meaningSummary(ref, l10n),
              );
              group(
                l10n.settingsRecitation,
                Icons.mic_none_rounded,
                // Also in the Mushaf's Hifz settings.
                SwitchListTile(
                  key: const ValueKey('settings-sajdah-reminder'),
                  contentPadding: EdgeInsets.zero,
                  title: _SearchText(l10n.sajdahReminder),
                  subtitle: _SearchText(l10n.sajdahReminderSub),
                  value: ref.watch(
                    hifzSettingsProvider.select((s) => s.sajdahReminder),
                  ),
                  onChanged: (on) => ref
                      .read(hifzSettingsProvider.notifier)
                      .update(
                        ref
                            .read(hifzSettingsProvider)
                            .copyWith(sajdahReminder: on),
                      ),
                ),
                words: [l10n.sajdahReminder, l10n.sajdahReminderSub],
                summary:
                    '${l10n.sajdahReminder}: ${ref.watch(hifzSettingsProvider.select((s) => s.sajdahReminder)) ? l10n.commonOn : l10n.commonOff}',
                collapsed: true,
              );
              group(
                l10n.listenTitle,
                Icons.headphones_outlined,
                const _ListenSettings(),
                words: [
                  l10n.listenReciter,
                  if (ref.read(reciterDownloadsProvider.notifier).supported)
                    l10n.listenDownload,
                  l10n.listenSearchReciters,
                ],
                summary: reciterName(
                  context,
                  reciterFor(ref.watch(reciterProvider)),
                ),
                summaryLeading: ReciterAvatar(
                  reciter: reciterFor(ref.watch(reciterProvider)),
                  size: 20,
                ),
              );
              if (reminderSupported) {
                group(
                  l10n.memReminderTitle,
                  Icons.notifications_outlined,
                  Column(
                    children: [
                      SwitchListTile(
                        key: const ValueKey('settings-reminder'),
                        contentPadding: EdgeInsets.zero,
                        title: _SearchText(l10n.memReminderSwitch),
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
                        title: _SearchText(l10n.memReminderTime),
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
                  words: [l10n.memReminderSwitch, l10n.memReminderTime],
                  summary: reminder.enabled
                      ? l10n.memReminderAt(reminderTime.format(context))
                      : l10n.commonOff,
                  collapsed: true,
                );
              }
              group(
                l10n.settingsBackupTitle,
                Icons.save_alt_rounded,
                Column(
                  children: [
                    ListTile(
                      key: const ValueKey('settings-export'),
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.upload_file_rounded),
                      title: _SearchText(l10n.settingsExportTitle),
                      subtitle: _SearchText(l10n.settingsExportSub),
                      onTap: () => _export(context, ref),
                    ),
                    ListTile(
                      key: const ValueKey('settings-import'),
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.download_rounded),
                      title: _SearchText(l10n.settingsImportTitle),
                      subtitle: _SearchText(l10n.settingsImportSub),
                      onTap: () => _import(context, ref),
                    ),
                    ListTile(
                      key: const ValueKey('settings-reset'),
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(
                        Icons.delete_forever_outlined,
                        color: theme.colorScheme.error,
                      ),
                      title: _SearchText(
                        l10n.settingsResetTitle,
                        style: TextStyle(color: theme.colorScheme.error),
                      ),
                      subtitle: _SearchText(l10n.settingsResetSub),
                      onTap: () => _confirmReset(context, ref),
                    ),
                  ],
                ),
                words: [
                  l10n.settingsExportTitle,
                  l10n.settingsImportTitle,
                  l10n.settingsResetTitle,
                  l10n.settingsResetSub,
                ],
                collapsed: true,
              );
              sections.add((
                collapsed: true,
                words: [
                  l10n.appName,
                  'GitHub',
                  l10n.settingsRate,
                  l10n.settingsShare,
                  l10n.settingsCheckUpdates,
                  l10n.settingsUpdateOffers,
                  l10n.aboutTitle,
                  l10n.aboutSubtitle,
                  l10n.privacyTitle,
                  l10n.settingsReport,
                ],
                // Last: the app — its version, source code, rating, sharing,
                // updates, and its sources.
                widget: TahfeezCollapsibleSection(
                  key: const ValueKey('settings-group-about'),
                  title: l10n.aboutTitle,
                  icon: Icons.info_outline_rounded,
                  open: searching,
                  child: const _AboutApp(),
                ),
              ));
              final query = _fold(_query.trim());
              final shown = [
                for (final collapsed in [false, true])
                  for (final section in sections)
                    if (section.collapsed == collapsed &&
                        (query.isEmpty ||
                            section.words.any((w) => _fold(w).contains(query))))
                      section.widget,
              ];
              // Rows compact (dense list tiles); chips and switches keep
              // their 48 × 48 to tap (a compact density shrank them to 40).
              return _SettingsQuery(
                query: query,
                child: ListTileTheme(
                  dense: true,
                  minVerticalPadding: 2,
                  child: ListView(
                    key: _listKey,
                    padding: withBarSpace(
                      context,
                      const EdgeInsets.fromLTRB(
                        TahfeezSpacing.md,
                        TahfeezSpacing.sm,
                        TahfeezSpacing.md,
                        TahfeezSpacing.md,
                      ),
                    ),
                    children: [
                      // Glass, as the groups below it.
                      TahfeezGlassSurface(
                        borderRadius: BorderRadius.circular(TahfeezRadii.pill),
                        blur: false,
                        child: TextField(
                          key: const ValueKey('settings-search'),
                          onChanged: _search,
                          textInputAction: TextInputAction.search,
                          textAlignVertical: TextAlignVertical.center,
                          decoration: InputDecoration(
                            prefixIcon: const Icon(Icons.search_rounded),
                            hintText: l10n.settingsSearchHint,
                            isDense: true,
                            // 48 high: a tap target's least.
                            constraints: const BoxConstraints(minHeight: 48),
                            border: InputBorder.none,
                            // Centred by `textAlignVertical`, not by
                            // paddings (the web's line metrics differ).
                            contentPadding: EdgeInsets.zero,
                          ),
                        ),
                      ),
                      const SizedBox(height: TahfeezSpacing.md),
                      if (shown.isEmpty)
                        Padding(
                          padding: const EdgeInsets.all(TahfeezSpacing.lg),
                          child: Text(
                            l10n.settingsNoMatch,
                            textAlign: TextAlign.center,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                      for (var i = 0; i < shown.length; i++) ...[
                        if (i > 0) const SizedBox(height: TahfeezSpacing.md),
                        shown[i],
                      ],
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

/// The settings search's text (folded), for [_SearchText].
class _SettingsQuery extends InheritedWidget {
  const _SettingsQuery({required this.query, required super.child});

  final String query;

  @override
  bool updateShouldNotify(_SettingsQuery old) => query != old.query;
}

/// An option's name or description, highlighted while the search finds it:
/// where in an opened section the match is.
class _SearchText extends StatelessWidget {
  const _SearchText(this.text, {this.style});

  final String text;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    final query =
        context.dependOnInheritedWidgetOfExactType<_SettingsQuery>()?.query ??
        '';
    final found =
        query.length >= 2 && _SettingsScreenState._fold(text).contains(query);
    if (!found) return Text(text, style: style);
    final scheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      key: const ValueKey('settings-search-match'),
      decoration: BoxDecoration(
        color: scheme.tertiaryContainer,
        borderRadius: BorderRadius.circular(TahfeezRadii.sm),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Text(
          text,
          style: (style ?? const TextStyle()).copyWith(
            color: scheme.onTertiaryContainer,
          ),
        ),
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

/// Settings → Translation & tafsir: which translations and tafsir, and
/// whether word meanings show the transliteration too.
/// Translation & tafsir closed: the translations chosen, and the tafsir.
String _meaningSummary(WidgetRef ref, AppLocalizations l10n) {
  final books = ref.watch(activeTranslationBooksProvider).value;
  final tafsirId = ref.watch(tafsirSelectionControllerProvider);
  final tafsir = [
    for (final t in ref.watch(tafsirLibraryControllerProvider).value ?? [])
      if (t.work.id == tafsirId) tafsirName(l10n, t.work),
  ].firstOrNull;
  return [
    if (books != null && books.isNotEmpty)
      for (final b in books.values) translationName(l10n, b),
    ?tafsir,
  ].join(' · ');
}

class _MeaningSettings extends ConsumerWidget {
  const _MeaningSettings();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final books = ref.watch(activeTranslationBooksProvider).value;
    final tafsirId = ref.watch(tafsirSelectionControllerProvider);
    final tafsirLabel = [
      for (final t in ref.watch(tafsirLibraryControllerProvider).value ?? [])
        if (t.work.id == tafsirId) tafsirName(l10n, t.work),
    ].firstOrNull;
    final transliteration = ref.watch(
      wbwShowTransliterationPreferenceControllerProvider,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ListTile(
          key: const ValueKey('settings-translations'),
          contentPadding: EdgeInsets.zero,
          title: _SearchText(l10n.searchTranslations),
          subtitle: Text(
            books == null || books.isEmpty
                ? l10n.readerSelected(0)
                : [for (final b in books.values) translationName(l10n, b)]
                      .join(', '),
          ),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => showTranslationPacksSheet(context),
        ),
        ListTile(
          key: const ValueKey('settings-tafsir'),
          contentPadding: EdgeInsets.zero,
          title: _SearchText(l10n.readerTafsir),
          subtitle: Text(tafsirLabel ?? l10n.settingsTafsirNone),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => showTafsirPacksSheet(context),
        ),
        SwitchListTile(
          key: const ValueKey('settings-transliteration'),
          contentPadding: EdgeInsets.zero,
          title: _SearchText(l10n.settingsTransliteration),
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

/// Saves a backup file where the user picks.
Future<void> _export(BuildContext context, WidgetRef ref) async {
  final l10n = AppLocalizations.of(context);
  final messenger = ScaffoldMessenger.of(context);
  try {
    final now = DateTime.now();
    final bytes = await exportUserData(
      storage: ref.read(browserStorageProvider),
      memorization: ref.read(memorizationRepositoryProvider),
      now: now,
    );
    final date = now.toIso8601String().substring(0, 10);
    final saved = await FilePicker.saveFile(
      fileName: 'tahfeez-backup-$date.json',
      bytes: bytes,
      mimeType: 'application/json',
    );
    // Web downloads it; elsewhere null means cancelled.
    if (saved == null && !kIsWeb) return;
    messenger.showSnackBar(SnackBar(content: Text(l10n.settingsExportDone)));
  } on Object {
    messenger.showSnackBar(SnackBar(content: Text(l10n.settingsExportFailed)));
  }
}

/// Picks a backup file, asks before replacing everything, then (like reset)
/// closes the app on Android so it opens with the imported data.
Future<void> _import(BuildContext context, WidgetRef ref) async {
  final l10n = AppLocalizations.of(context);
  final messenger = ScaffoldMessenger.of(context);
  final List<int> bytes;
  try {
    // Any file: some Android file providers don't tag JSON as JSON. The
    // import checks the contents.
    final file = (await FilePicker.pickFiles()).firstOrNull;
    if (file == null) return;
    bytes = await file.readAsBytes();
  } on Object {
    messenger.showSnackBar(SnackBar(content: Text(l10n.settingsImportFailed)));
    return;
  }
  if (!context.mounted) return;
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(l10n.settingsImportConfirmTitle),
      content: Text(l10n.settingsImportConfirmBody),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(l10n.commonCancel),
        ),
        FilledButton(
          key: const ValueKey('settings-import-confirm'),
          onPressed: () => Navigator.of(context).pop(true),
          child: Text(l10n.settingsImportConfirm),
        ),
      ],
    ),
  );
  if (confirmed != true || !context.mounted) return;
  final android = ref.read(platformCapabilitiesProvider).isAndroid;
  try {
    await ref.read(dailyReminderSchedulerProvider).cancel();
    await importUserData(
      bytes,
      storage: ref.read(browserStorageProvider),
      memorization: ref.read(memorizationRepositoryProvider),
    );
  } on Object {
    messenger.showSnackBar(SnackBar(content: Text(l10n.settingsImportFailed)));
    return;
  }
  if (android) {
    await SystemNavigator.pop();
  } else {
    messenger.showSnackBar(SnackBar(content: Text(l10n.settingsImportDone)));
  }
}

/// Settings' last section: the app's name and version, then the
/// GitHub, rate, share, check for updates (and whether to be told of
/// them), and its sources and licences.
class _AboutApp extends ConsumerStatefulWidget {
  const _AboutApp();

  @override
  ConsumerState<_AboutApp> createState() => _AboutAppState();
}

class _AboutAppState extends ConsumerState<_AboutApp> {
  bool? _updateOffers;

  @override
  void initState() {
    super.initState();
    ref.read(storePromptsProvider).updateOffersOn().then((on) {
      if (mounted) setState(() => _updateOffers = on);
    });
  }

  Future<void> _checkForUpdates() async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final available = await ref.read(appStoreServiceProvider).updateAvailable();
    if (!mounted) return;
    if (available ?? false) {
      await showUpdateOffer(context, ref);
    } else {
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            available == null
                ? (ref.read(platformCapabilitiesProvider).isIOS
                      ? l10n.updateCheckFailedAppStore
                      : l10n.updateCheckFailed)
                : l10n.updateUpToDate,
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final store = ref.read(appStoreServiceProvider);
    final version = ref.watch(appVersionProvider).value ?? '';
    final android = ref.watch(platformCapabilitiesProvider).isAndroid;
    Widget row(
      String key,
      IconData icon,
      String title,
      String subtitle,
      VoidCallback onTap,
    ) => ListTile(
      key: ValueKey(key),
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon),
      title: _SearchText(title),
      subtitle: _SearchText(subtitle),
      onTap: onTap,
    );
    return TahfeezCard(
      key: const ValueKey('settings-about-app'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            spacing: TahfeezSpacing.smPlus,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(TahfeezRadii.sm),
                child: Image.asset(
                  'assets/branding/splash_icon.png',
                  width: 44,
                  height: 44,
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AppNameText(
                      l10n.appName,
                      style: theme.textTheme.titleMedium,
                    ),
                    if (version.isNotEmpty)
                      Text(
                        l10n.aboutVersion(version),
                        key: const ValueKey('settings-version'),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: TahfeezSpacing.sm),
          row(
            'settings-github',
            Icons.code_rounded,
            l10n.settingsGitHub,
            l10n.settingsGitHubSub,
            () {
              if (kGitHubUrl.isNotEmpty) store.openUrl(kGitHubUrl);
            },
          ),
          // Rated in the phone's store: not in a browser.
          if (!ref.watch(platformCapabilitiesProvider).isWeb)
            row(
              'settings-rate',
              Icons.star_outline_rounded,
              l10n.settingsRate,
              // Where it is rated: this phone's store.
              ref.watch(platformCapabilitiesProvider).isIOS
                  ? l10n.settingsRateSubAppStore
                  : l10n.settingsRateSub,
              store.openListing,
            ),
          row(
            'settings-share',
            Icons.share_outlined,
            l10n.settingsShare,
            l10n.settingsShareSub,
            () => store.share(
              l10n.settingsShareText(store.listingUrl),
              origin: shareOrigin(context),
            ),
          ),
          // A problem: an email with the app's latest messages, written and
          // sent by the user.
          row(
            'settings-report',
            Icons.bug_report_outlined,
            l10n.settingsReport,
            l10n.settingsReportSub,
            () => sendProblemReport(
              store,
              subject: l10n.settingsReportSubject(version),
              body: problemReportBody(
                prompt: l10n.settingsReportPrompt,
                version: version,
                locale: Localizations.localeOf(context).toLanguageTag(),
              ),
            ),
          ),
          // Updates: Google Play's, or the App Store's on iOS.
          if (android || ref.watch(platformCapabilitiesProvider).isIOS) ...[
            row(
              'settings-check-updates',
              Icons.system_update_outlined,
              l10n.settingsCheckUpdates,
              l10n.aboutVersion(version),
              _checkForUpdates,
            ),
            SwitchListTile(
              key: const ValueKey('settings-update-offers'),
              contentPadding: EdgeInsets.zero,
              title: _SearchText(l10n.settingsUpdateOffers),
              value: _updateOffers ?? true,
              onChanged: (on) {
                setState(() => _updateOffers = on);
                ref.read(storePromptsProvider).setUpdateOffers(on);
              },
            ),
          ],
          ListTile(
            key: const ValueKey('settings-about'),
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.info_outline),
            title: _SearchText(l10n.aboutTitle),
            subtitle: _SearchText(l10n.aboutSubtitle),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push(AppRoutes.about),
          ),
        ],
      ),
    );
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
          title: _SearchText(l10n.listenReciter),
          subtitle: ReciterNameWithAvatar(
            reciter: reciter,
            name: reciterName(context, reciter),
          ),
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

/// The app language, chosen in a sheet over the whole app: a dropdown opens
/// inside the tab, where the bottom bar covers the end of its 26 entries.
class _LanguageRow extends StatelessWidget {
  const _LanguageRow({super.key, required this.code, required this.onChanged});

  final String code;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final languages = [
      ('', '🌐', l10n.settingsLanguageSystem),
      ...kAppLanguages,
    ];
    final (_, flag, label) = languages.firstWhere(
      (l) => l.$1 == code,
      orElse: () => languages.first,
    );
    Widget entry(String flag, String label) => Row(
      spacing: TahfeezSpacing.smPlus,
      children: [
        Text(flag, style: const TextStyle(fontSize: 22)),
        Flexible(
          child: Text(
            label,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodyLarge,
          ),
        ),
      ],
    );
    return InkWell(
      borderRadius: BorderRadius.circular(TahfeezRadii.md),
      onTap: () => showTahfeezModalBottomSheet<void>(
        context: context,
        title: l10n.settingsLanguage,
        builder: (sheet) => RadioGroup<String>(
          groupValue: code,
          onChanged: (picked) {
            Navigator.of(sheet).pop();
            if (picked != null && picked != code) onChanged(picked);
          },
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.fromLTRB(
              TahfeezSpacing.sm,
              0,
              TahfeezSpacing.sm,
              TahfeezSpacing.md,
            ),
            children: [
              for (final (value, flag, label) in languages)
                RadioListTile<String>(
                  key: ValueKey('settings-language-$value'),
                  value: value,
                  title: entry(flag, label),
                ),
            ],
          ),
        ),
      ),
      child: Container(
        constraints: const BoxConstraints(minHeight: 48),
        padding: const EdgeInsets.symmetric(vertical: TahfeezSpacing.sm),
        child: Row(
          children: [
            Expanded(child: entry(flag, label)),
            Icon(
              Icons.arrow_drop_down,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ],
        ),
      ),
    );
  }
}
