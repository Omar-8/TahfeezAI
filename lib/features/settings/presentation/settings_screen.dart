import 'dart:async';

import 'package:file_picker/file_picker.dart';

import '../../../core/sharing/image_sharer.dart';
import '../../../core/ui/reopen_required.dart';
import '../../../core/ui/bar_space.dart';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

import '../../../core/ui/settings_search.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../home/presentation/home_sky.dart';
import '../../../core/core_providers.dart';
import '../../../core/localization/clock_format.dart';
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
import '../../onboarding/presentation/first_run_setup.dart';
import '../../khatmah/application/khatmah_controller.dart';
import '../../khatmah/application/khatmah_reminder.dart';
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
import '../../../core/ui/app_name_text.dart';
import '../../../core/ui/animations_setting.dart';
import '../../../core/theme/tahfeez_motion.dart';
import '../../salawat/salawat_reminder.dart';
import '../../athkar/application/athkar_reminder.dart';
import '../../habits/application/habits_controller.dart';
import '../../habits/domain/habit.dart' show HabitReminderKind;
import '../../habits/domain/habit_catalog.dart';
import '../../prayer/application/prayer_controller.dart';
import '../../prayer/domain/prayer_times.dart';

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

  static String _fold(String s) => foldForSearch(s);

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
          if (e.widget case SearchText(:final text)
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

    // Opened from the side menu, over a tab: back returns to it.
    return SkyBackdrop(
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
            // First: the welcome setup and its recitation demo, to see
            // again (those who had the app before it never saw it).
            sections.add((
              collapsed: false,
              words: [l10n.settingsSetupAgain, l10n.settingsSetupAgainSub],
              widget: _SetupCard(onTap: () => showFirstRunSetup(context)),
            ));
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
            // 12- or 24-hour, everywhere (owner, 2026-11-22).
            group(
              l10n.settingsTimeFormat,
              Icons.schedule,
              SegmentedButton<ClockFormat>(
                key: const ValueKey('settings-time-format'),
                showSelectedIcon: false,
                segments: [
                  ButtonSegment(
                    value: ClockFormat.system,
                    label: Text(l10n.settingsTimeFormatSystem),
                  ),
                  ButtonSegment(
                    value: ClockFormat.h12,
                    label: Text(l10n.settingsTimeFormat12),
                  ),
                  ButtonSegment(
                    value: ClockFormat.h24,
                    label: Text(l10n.settingsTimeFormat24),
                  ),
                ],
                selected: {ref.watch(clockFormatProvider)},
                onSelectionChanged: (s) => unawaited(
                  ref.read(clockFormatProvider.notifier).set(s.first),
                ),
              ),
              words: [
                l10n.settingsTimeFormatSystem,
                l10n.settingsTimeFormat12,
                l10n.settingsTimeFormat24,
              ],
              summary: switch (ref.watch(clockFormatProvider)) {
                ClockFormat.system => l10n.settingsTimeFormatSystem,
                ClockFormat.h12 => l10n.settingsTimeFormat12,
                ClockFormat.h24 => l10n.settingsTimeFormat24,
              },
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
                    title: SearchText(l10n.settingsTimeOfDay),
                    subtitle: SearchText(l10n.settingsTimeOfDaySub),
                    value: ref.watch(homeSkyProvider),
                    onChanged: (on) =>
                        ref.read(homeSkyProvider.notifier).setEnabled(on),
                  ),
                  SwitchListTile(
                    key: const ValueKey('settings-animations'),
                    contentPadding: EdgeInsets.zero,
                    title: SearchText(l10n.settingsAnimations),
                    subtitle: SearchText(l10n.settingsAnimationsSub),
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
                title: SearchText(l10n.sajdahReminder),
                subtitle: SearchText(l10n.sajdahReminderSub),
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
            // Every notification the app sends, each on or off at its
            // time (owner, 2026-11-21): the daily reminder, the khatmah's,
            // the morning and evening athkar.
            if (reminderSupported) {
              final khatmah = ref.watch(khatmahReminderProvider);
              final athkar = ref.watch(athkarReminderProvider);
              final morning = athkar[AthkarTime.morning]!;
              final evening = athkar[AthkarTime.evening]!;
              final messenger = ScaffoldMessenger.of(context);
              void denied(bool done) {
                if (!done) {
                  messenger.showSnackBar(
                    SnackBar(content: Text(l10n.memReminderDenied)),
                  );
                }
              }

              final on = [
                if (reminder.enabled) l10n.memTitle,
                if (khatmah.enabled) l10n.khatmahTitle,
                if (morning.enabled) l10n.athkarMorningTitle,
                if (evening.enabled) l10n.athkarEveningTitle,
                for (final h in ref.watch(habitsProvider).habits)
                  if (h.remindersOn && h.reminders.isNotEmpty)
                    habitName(l10n, h),
                if (ref.watch(prayerSettingsProvider).notify.isNotEmpty)
                  l10n.prayerTitle,
              ];
              group(
                l10n.settingsNotifications,
                Icons.notifications_outlined,
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // The Quran's reminders, then the athkar's, then the
                    // habits', each in one entry that opens (owner,
                    // 2026-11-22: not crowding the group).
                    _ReminderFold(
                      keyName: 'reading',
                      open: searching,
                      icon: Icons.auto_stories_outlined,
                      title: l10n.settingsReadingReminders,
                      on: [
                        if (reminder.enabled) l10n.memTitle,
                        if (khatmah.enabled) l10n.khatmahTitle,
                      ],
                      children: [
                        _NotificationRow(
                          keyName: 'reminder',
                          icon: Icons.school_outlined,
                          heading: l10n.memTitle,
                          title: l10n.memReminderSwitch,
                          enabled: reminder.enabled,
                          minutes: reminder.minutes,
                          onEnabled: (v) async => denied(
                            await ref
                                .read(memorizationReminderProvider.notifier)
                                .setEnabled(v),
                          ),
                          onTime: (m) => ref
                              .read(memorizationReminderProvider.notifier)
                              .setTime(m),
                        ),
                        _NotificationRow(
                          keyName: 'khatmah-reminder',
                          icon: Icons.menu_book_outlined,
                          heading: l10n.khatmahTitle,
                          title: l10n.khatmahReminderSwitch,
                          enabled: khatmah.enabled,
                          minutes: khatmah.minutes,
                          onEnabled: (v) async => denied(
                            await ref
                                .read(khatmahReminderProvider.notifier)
                                .setEnabled(v),
                          ),
                          onTime: (m) => ref
                              .read(khatmahReminderProvider.notifier)
                              .setTime(m),
                        ),
                      ],
                    ),
                    _ReminderFold(
                      keyName: 'athkar',
                      open: searching,
                      icon: Icons.record_voice_over_outlined,
                      title: l10n.athkarTitle,
                      on: [
                        if (morning.enabled) l10n.athkarMorningTitle,
                        if (evening.enabled) l10n.athkarEveningTitle,
                      ],
                      children: [
                        for (final (t, setting, icon, title) in [
                          (
                            AthkarTime.morning,
                            morning,
                            Icons.wb_sunny_outlined,
                            l10n.athkarMorningTitle,
                          ),
                          (
                            AthkarTime.evening,
                            evening,
                            Icons.nights_stay_outlined,
                            l10n.athkarEveningTitle,
                          ),
                        ])
                          _NotificationRow(
                            keyName: 'athkar-${t.name}',
                            icon: icon,
                            heading: l10n.athkarTitle,
                            title: title,
                            enabled: setting.enabled,
                            minutes: setting.minutes,
                            onEnabled: (v) async => denied(
                              await ref
                                  .read(athkarReminderProvider.notifier)
                                  .setEnabled(t, v),
                            ),
                            onTime: (m) => ref
                                .read(athkarReminderProvider.notifier)
                                .setTime(t, m),
                          ),
                      ],
                    ),
                    // The prayers' (owner, 2026-11-21): set on prayer
                    // times' own page.
                    ListTile(
                      key: const ValueKey('settings-prayer'),
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.mosque_outlined),
                      title: Text(l10n.prayerTitle),
                      subtitle: Text(
                        ref.watch(prayerSettingsProvider).notify.isEmpty
                            ? l10n.commonOff
                            : [
                                for (final p in Prayer.values)
                                  if (ref
                                      .watch(prayerSettingsProvider)
                                      .notify
                                      .contains(p))
                                    prayerName(l10n, p),
                              ].join(' · '),
                      ),
                      trailing: const Icon(Icons.chevron_right_rounded),
                      onTap: () => context.push(AppRoutes.prayer),
                    ),
                    if (ref
                            .watch(habitsProvider)
                            .habits
                            .where((h) => h.reminders.isNotEmpty)
                            .toList()
                        case final withReminders when withReminders.isNotEmpty)
                      _ReminderFold(
                        keyName: 'habits',
                        open: searching,
                        icon: Icons.event_available_outlined,
                        title: l10n.habitsTitle,
                        on: [
                          for (final h in withReminders)
                            if (h.remindersOn) habitName(l10n, h),
                        ],
                        children: [
                          // Each habit: its switch, then each reminder's
                          // time to change (owner, 2026-11-22).
                          for (final h in withReminders) ...[
                            SwitchListTile(
                              key: ValueKey('settings-habit-${h.id}'),
                              contentPadding: EdgeInsets.zero,
                              secondary: Icon(habitIcon(h)),
                              title: Text(habitName(l10n, h)),
                              subtitle: h.remindersOn
                                  ? null
                                  : Text(
                                      [
                                        for (final r in h.reminders)
                                          TimeOfDay(
                                            hour: r.minutes ~/ 60,
                                            minute: r.minutes % 60,
                                          ).format(context),
                                      ].join(' · '),
                                    ),
                              value: h.remindersOn,
                              onChanged: (v) async {
                                if (v &&
                                    !await ref
                                        .read(dailyReminderSchedulerProvider)
                                        .requestPermission()) {
                                  denied(false);
                                  return;
                                }
                                ref
                                    .read(habitsProvider.notifier)
                                    .update(h.copyWith(remindersOn: v));
                              },
                            ),
                            if (h.remindersOn)
                              for (final (i, r) in h.reminders.indexed)
                                ListTile(
                                  key: ValueKey(
                                    'settings-habit-${h.id}-time-$i',
                                  ),
                                  contentPadding:
                                      const EdgeInsetsDirectional.only(
                                        start: 40,
                                      ),
                                  leading: const Icon(Icons.schedule),
                                  title: Text(switch (r.kind) {
                                    HabitReminderKind.fastTomorrow =>
                                      l10n.habitsReminderEveningBefore,
                                    HabitReminderKind.suhoor =>
                                      l10n.habitsReminderSuhoor,
                                    HabitReminderKind.reminder =>
                                      l10n.memReminderTime,
                                  }),
                                  trailing: Text(
                                    TimeOfDay(
                                      hour: r.minutes ~/ 60,
                                      minute: r.minutes % 60,
                                    ).format(context),
                                  ),
                                  onTap: () async {
                                    final picked = await showTimePicker(
                                      context: context,
                                      initialTime: TimeOfDay(
                                        hour: r.minutes ~/ 60,
                                        minute: r.minutes % 60,
                                      ),
                                    );
                                    if (picked == null) return;
                                    final now = ref
                                        .read(habitsProvider)
                                        .habit(h.id);
                                    if (now == null) return;
                                    ref
                                        .read(habitsProvider.notifier)
                                        .update(
                                          now.copyWith(
                                            reminders: [
                                              for (final (k, x)
                                                  in now.reminders.indexed)
                                                k == i
                                                    ? x.withMinutes(
                                                        picked.hour * 60 +
                                                            picked.minute,
                                                      )
                                                    : x,
                                            ],
                                          ),
                                        );
                                  },
                                ),
                          ],
                        ],
                      ),
                  ],
                ),
                words: [
                  l10n.settingsReadingReminders,
                  l10n.habitsTitle,
                  l10n.memReminderTitle,
                  l10n.memReminderSwitch,
                  l10n.memReminderTime,
                  l10n.khatmahReminderSwitch,
                  l10n.athkarTitle,
                  l10n.athkarMorningTitle,
                  l10n.athkarEveningTitle,
                ],
                summary: on.isEmpty ? l10n.commonOff : on.join(' · '),
                collapsed: true,
              );
            }
            group(
              l10n.salawatSettingTitle,
              Icons.favorite_outline_rounded,
              SwitchListTile(
                key: const ValueKey('settings-salawat'),
                contentPadding: EdgeInsets.zero,
                title: SearchText(l10n.salawatSettingSwitch),
                value: ref.watch(salawatReminderProvider),
                onChanged: (on) =>
                    ref.read(salawatReminderProvider.notifier).setEnabled(on),
              ),
              words: [l10n.salawatSettingTitle, l10n.salawatSettingSwitch],
              summary: ref.watch(salawatReminderProvider)
                  ? l10n.commonOn
                  : l10n.commonOff,
              collapsed: true,
            );
            group(
              l10n.settingsBackupTitle,
              Icons.save_alt_rounded,
              Column(
                children: [
                  ListTile(
                    key: const ValueKey('settings-export'),
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.upload_file_rounded),
                    title: SearchText(l10n.settingsExportTitle),
                    subtitle: SearchText(l10n.settingsExportSub),
                    onTap: () => _export(context, ref),
                  ),
                  ListTile(
                    key: const ValueKey('settings-import'),
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.download_rounded),
                    title: SearchText(l10n.settingsImportTitle),
                    subtitle: SearchText(l10n.settingsImportSub),
                    onTap: () => _import(context, ref),
                  ),
                  ListTile(
                    key: const ValueKey('settings-reset'),
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(
                      Icons.delete_forever_outlined,
                      color: theme.colorScheme.error,
                    ),
                    title: SearchText(
                      l10n.settingsResetTitle,
                      style: TextStyle(color: theme.colorScheme.error),
                    ),
                    subtitle: SearchText(l10n.settingsResetSub),
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
            return SettingsSearchScope(
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
          title: SearchText(l10n.searchTranslations),
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
          title: SearchText(l10n.readerTafsir),
          subtitle: Text(tafsirLabel ?? l10n.settingsTafsirNone),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => showTafsirPacksSheet(context),
        ),
        SwitchListTile(
          key: const ValueKey('settings-transliteration'),
          contentPadding: EdgeInsets.zero,
          title: SearchText(l10n.settingsTransliteration),
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
  await resetAllData(ref);
  // Started over (Android closes, the web reloads, iOS asks to reopen):
  // what the app read before must not be saved over the reset.
  await startOverAfterDataReplaced(ref, DataReplaced.reset);
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
    await ref.read(dailyReminderSchedulerProvider).cancelAll();
    await importUserData(
      bytes,
      storage: ref.read(browserStorageProvider),
      memorization: ref.read(memorizationRepositoryProvider),
    );
  } on Object {
    messenger.showSnackBar(SnackBar(content: Text(l10n.settingsImportFailed)));
    return;
  }
  if (!android) {
    // The imported reminders, scheduled again.
    ref
      ..invalidate(memorizationReminderProvider)
      ..invalidate(khatmahProvider)
      ..invalidate(khatmahReminderProvider)
      ..invalidate(athkarReminderProvider);
  }
  // Started over (Android closes, the web reloads, iOS asks to reopen):
  // what the app read before must not be saved over the backup (2026-11-15).
  await startOverAfterDataReplaced(ref, DataReplaced.imported);
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
      title: SearchText(title),
      subtitle: SearchText(subtitle),
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
              title: SearchText(l10n.settingsUpdateOffers),
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
            title: SearchText(l10n.aboutTitle),
            subtitle: SearchText(l10n.aboutSubtitle),
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
          title: SearchText(l10n.listenReciter),
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

/// Settings' first card: the welcome setup — language, where to begin, a
/// reciter, how reciting works — to go through again.
class _SetupCard extends StatelessWidget {
  const _SetupCard({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return TahfeezCard(
      key: const ValueKey('settings-setup-again'),
      onTap: onTap,
      child: Row(
        spacing: TahfeezSpacing.smPlus,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: scheme.primaryContainer,
            ),
            child: Icon(
              Icons.auto_awesome_outlined,
              size: 20,
              color: scheme.onPrimaryContainer,
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: 2,
              children: [
                SearchText(
                  l10n.settingsSetupAgain,
                  style: theme.textTheme.titleSmall,
                ),
                SearchText(
                  l10n.settingsSetupAgainSub,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          Icon(
            Icons.chevron_right_rounded,
            color: scheme.onSurfaceVariant,
            textDirection: Directionality.of(context),
          ),
        ],
      ),
    );
  }
}

/// One notification in Settings → Notifications: what it is for, its
/// switch, and its time (once on).
/// Reminders of one kind in one entry that opens (owner, 2026-11-22): its
/// title, which of them are on (else "Off"), and their rows. Open while
/// Settings is searched ([open]), so what matches shows.
class _ReminderFold extends StatelessWidget {
  const _ReminderFold({
    required this.keyName,
    required this.open,
    required this.icon,
    required this.title,
    required this.on,
    required this.children,
  });

  /// Its key: `settings-$keyName`.
  final String keyName;
  final bool open;
  final IconData icon;
  final String title;
  final List<String> on;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => KeyedSubtree(
    // (A new tile when searching starts or ends: opened or closed again.)
    key: ValueKey('$keyName-$open'),
    child: ExpansionTile(
      key: ValueKey('settings-$keyName'),
      initiallyExpanded: open,
      tilePadding: EdgeInsets.zero,
      childrenPadding: const EdgeInsetsDirectional.only(
        start: TahfeezSpacing.md,
      ),
      leading: Icon(icon),
      title: Text(title),
      subtitle: Text(
        on.isEmpty ? AppLocalizations.of(context).commonOff : on.join(' · '),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      children: children,
    ),
  );
}

class _NotificationRow extends StatelessWidget {
  const _NotificationRow({
    required this.keyName,
    required this.icon,
    required this.heading,
    required this.title,
    required this.enabled,
    required this.minutes,
    required this.onEnabled,
    required this.onTime,
  });

  /// Its keys: `settings-$keyName` (its switch), `…-time`.
  final String keyName;
  final IconData icon;
  final String heading, title;
  final bool enabled;
  final int minutes;
  final Future<void> Function(bool) onEnabled;
  final Future<void> Function(int) onTime;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final time = TimeOfDay(hour: minutes ~/ 60, minute: minutes % 60);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SwitchListTile(
          key: ValueKey('settings-$keyName'),
          contentPadding: EdgeInsets.zero,
          secondary: Icon(icon),
          title: SearchText(title),
          subtitle: Text(
            enabled
                ? '$heading · ${l10n.memReminderAt(time.format(context))}'
                : heading,
          ),
          value: enabled,
          onChanged: onEnabled,
        ),
        if (enabled)
          ListTile(
            key: ValueKey('settings-$keyName-time'),
            contentPadding: const EdgeInsetsDirectional.only(start: 40),
            leading: const Icon(Icons.schedule),
            title: Text(l10n.memReminderTime),
            trailing: Text(time.format(context)),
            onTap: () async {
              final picked = await showTimePicker(
                context: context,
                initialTime: time,
              );
              if (picked == null) return;
              await onTime(picked.hour * 60 + picked.minute);
            },
          ),
      ],
    );
  }
}
