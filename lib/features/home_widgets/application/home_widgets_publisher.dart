import 'dart:async';

import 'dart:ui' show PlatformDispatcher;

import 'package:flutter/material.dart' show ThemeMode;
import 'package:flutter/scheduler.dart' show SchedulerBinding;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show ProviderListenable;
import 'package:intl/intl.dart' show DateFormat;

import '../../../core/localization/clock_format.dart';
import '../../../core/localization/fallback_localizations.dart';
import '../../../core/localization/generated/app_localizations.dart';
import '../../../core/localization/locale_controller.dart';
import '../../../core/notifications/reminder_locale.dart';
import '../../../core/routing/app_router.dart';
import '../../../core/routing/quran_location_routing.dart';
import '../../../core/theme/theme_controller.dart';
import '../../../memorization/application/memorization_today.dart';
import '../../../quran/application/meaning_defaults.dart';
import '../../../quran/application/meaning_packs.dart'
    show shownTranslationSlugsProvider;
import '../../../quran/application/quran_dataset_status.dart';
import '../../../quran/domain/models/quran_location.dart';
import '../../../quran/quran_providers.dart';
import '../../../quran/translation_providers.dart';
import '../../habits/application/habits_controller.dart';
import '../../habits/domain/hijri.dart';
import '../../home/application/home_providers.dart';
import '../../home/presentation/home_date_card.dart' show nextHijriEvent;
import '../../home/presentation/home_location_label.dart';
import '../../khatmah/application/khatmah_controller.dart';
import '../../prayer/application/prayer_controller.dart';
import '../../prayer/application/saved_place.dart';
import '../../prayer/domain/prayer_times.dart';
import '../../prayer/presentation/prayer_card.dart' show placeLabel;
import '../../qibla/data/country_names.dart';
import '../../quran/application/quran_index_providers.dart';
import '../data/home_widget_bridge.dart';
import '../domain/home_widget_payload.dart';

/// Keeps the home-screen widgets up to date (owner, 2026-11-22): whenever
/// what they show changes — the place or prayer settings, the language or
/// theme, reading, memorization, the khatmah — a moment later (changes come
/// in bursts) it writes it all again; at start, and at each day's first
/// open, too. A widget tapped opens its screen.
class HomeWidgetsPublisher extends Notifier<void> {
  /// Days of prayer times and dates written ahead.
  static const daysAhead = 30;

  Timer? _soon;

  @override
  void build() {
    final bridge = ref.watch(homeWidgetBridgeProvider);
    if (!bridge.supported) return;
    ref.onDispose(() => _soon?.cancel());
    void soon() {
      _soon?.cancel();
      _soon = Timer(const Duration(seconds: 2), () => unawaited(_publish()));
    }

    for (final p in <ProviderListenable<Object?>>[
      // The app's language (and so right to left or not), its time format.
      localeControllerProvider,
      clockFormatProvider,
      savedPlaceProvider,
      prayerSettingsProvider,
      countryNamesProvider,
      themeModeControllerProvider,
      continueReadingProvider,
      todayPlanProvider,
      newLessonProvider,
      khatmahTodayProvider,
      indexedSurahsProvider,
      hasInstalledQuranDatasetProvider,
      shownTranslationSlugsProvider,
      habitsProvider.select((s) => s.hijriAdjust),
    ]) {
      ref.listen(p, (_, _) => soon());
    }
    soon();
    // Opened from a widget: its screen.
    final taps = bridge.taps.listen(_open);
    ref.onDispose(taps.cancel);
    unawaited(bridge.launchedWith().then(_open));
  }

  void _open(Uri? uri) {
    final route = homeWidgetRoute(uri);
    if (route == null) return;
    // After the first frame: the router may not be built yet at launch.
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (!ref.mounted) return;
      final router = ref.read(appRouterProvider);
      final root = '/${Uri.parse(route).pathSegments.firstOrNull ?? ''}';
      // A tab's own screens: there; any other page over Home (back
      // returns to it).
      if (const {
        AppRoutes.home,
        AppRoutes.quran,
        AppRoutes.memorize,
      }.contains(root)) {
        router.go(route);
      } else {
        router.go(AppRoutes.home);
        unawaited(router.push(route));
      }
    });
  }

  Future<void> _publish() async {
    if (!ref.mounted) return;
    try {
      final payload = await buildPayload();
      if (!ref.mounted) return;
      final bridge = ref.read(homeWidgetBridgeProvider);
      await bridge.publish(payload);
      // The prayer widget's next prayer, as each comes (and each midnight).
      final now = ref.read(memorizationClockProvider)();
      await bridge.scheduleRedraws(
        [
          for (final d in payload.prayer?.days.take(3) ?? const <PrayerDay>[])
            for (final at in d.at)
              if (DateTime.fromMillisecondsSinceEpoch(at).isAfter(now))
                DateTime.fromMillisecondsSinceEpoch(at),
        ],
        [
          for (var d = 0; d <= 7; d++) ...[
            if (d > 0) DateTime(now.year, now.month, now.day + d),
            // The date card's sun or moon (SkyTime) changes at these hours.
            for (final h in const [5, 7, 17, 19])
              if (DateTime(now.year, now.month, now.day + d, h).isAfter(now))
                DateTime(now.year, now.month, now.day + d, h),
          ],
        ],
      );
    } on Object {
      // (A widget left as it was: never the app's problem.)
    }
  }

  /// Everything the widgets show, now.
  Future<HomeWidgetPayload> buildPayload() async {
    final l10n = lookupAppLocalizations(reminderLocale(ref));
    final language = l10n.localeName.split('_').first;
    final intl = intlLocaleOf(reminderLocale(ref));
    final now = ref.read(memorizationClockProvider)();
    final today = DateTime(now.year, now.month, now.day);

    // Prayer times, 30 days.
    final place = ref.read(savedPlaceProvider);
    final settings = ref.read(prayerSettingsProvider);
    const order = [
      Prayer.fajr,
      Prayer.sunrise,
      Prayer.dhuhr,
      Prayer.asr,
      Prayer.maghrib,
      Prayer.isha,
    ];
    // The times without AM/PM (owner, 2026-11-22): the locale's own clock
    // pattern, its day-period mark left out.
    // As the app's time format says (owner, 2026-11-22).
    final format = ref.read(clockFormatProvider);
    final use24 = use24Hour(
      format,
      phone24: PlatformDispatcher.instance.alwaysUse24HourFormat,
    );
    final clock = use24
        ? DateFormat.Hm(intl)
        : DateFormat(
            DateFormat.jm(intl).pattern!
                .replaceAll(RegExp(r'\s*a\s*'), ' ')
                .trim(),
            intl,
          );
    PrayerDays? prayer;
    if (place != null) {
      prayer = PrayerDays(
        place:
            placeLabel(place, ref.read(countryNamesProvider).value, language) ??
            l10n.prayerTitle,
        names: [for (final p in order) prayerName(l10n, p)],
        order: [for (final p in order) p.name],
        days: [
          for (var d = 0; d < daysAhead; d++)
            () {
              final day = DateTime(today.year, today.month, today.day + d);
              final t = prayerTimes(place, day, settings);
              return (
                date: isoDate(day),
                at: [for (final p in order) t[p]!.millisecondsSinceEpoch],
                shown: [for (final p in order) clock.format(t[p]!)],
              );
            }(),
        ],
      );
    }

    // Dates, 30 days.
    final adjust = ref.read(habitsProvider).hijriAdjust;
    final gregorian = DateFormat.MMMMEEEEd(intl);
    final gregorianShort = DateFormat.MMMEd(intl);
    final dates = [
      for (var d = 0; d < daysAhead; d++)
        () {
          final day = DateTime(today.year, today.month, today.day + d);
          final hijri = hijriOf(day, adjust: adjust);
          final event = nextHijriEvent(day, adjust: adjust);
          return (
            date: isoDate(day),
            gregorian: gregorian.format(day),
            gregorianShort: gregorianShort.format(day),
            hijri: formatHijri(hijri, language),
            hijriShort: '${hijri.day} ${hijriMonthName(hijri.month, language)}',
            hijriDay: hijri.day,
            event: switch (event) {
              null => null,
              (:final event, inDays: 0) => l10n.homeEventToday(
                event.title(l10n),
              ),
              (:final event, inDays: 1) => l10n.homeEventTomorrow(
                event.title(l10n),
              ),
              (:final event, :final inDays) => l10n.homeEventInDays(
                event.title(l10n),
                inDays,
              ),
            },
          );
        }(),
    ];

    return HomeWidgetPayload(
      language: language,
      rtl: usesArabicScript(language),
      clock: switch (format) {
        ClockFormat.system => 'system',
        ClockFormat.h12 => '12',
        ClockFormat.h24 => '24',
      },
      theme: switch (ref.read(themeModeControllerProvider)) {
        ThemeMode.light => 'light',
        ThemeMode.dark => 'dark',
        ThemeMode.system => 'system',
      },
      updated: now,
      labels: {
        'prayer': l10n.prayerTitle,
        'setLocation': l10n.prayerSetLocation,
        // "%1 in %2": the next prayer's name, then the time until it.
        'nextIn': l10n.prayerNextIn('%1', '%2'),
        'qibla': l10n.qiblaTitle,
        'athkar': l10n.athkarTitle,
        'habits': l10n.habitsTitle,
        'quran': l10n.navQuran,
        'ayah': l10n.homeSectionDailyAyah,
        'reading': l10n.homeSectionContinueReading,
        'readingEmpty': l10n.homeReadHistoryEmpty,
        'readingAction': l10n.homeContinueReadingAction,
        'date': l10n.hijriCalendarTitle,
        'memorize': l10n.homeSectionMemorization,
        'memorizeEmpty': l10n.homeMemNothing,
        'memorizeOpen': l10n.homeMemOpen,
        'khatmah': l10n.khatmahTitle,
        'khatmahStart': l10n.khatmahStart,
      },
      routes: {
        HomeWidgetKind.home.name: AppRoutes.home,
        HomeWidgetKind.today.name: AppRoutes.home,
        HomeWidgetKind.prayer.name: AppRoutes.prayer,
        HomeWidgetKind.qibla.name: AppRoutes.qibla,
        HomeWidgetKind.athkar.name: AppRoutes.athkar,
        HomeWidgetKind.habits.name: AppRoutes.habits,
        HomeWidgetKind.date.name: AppRoutes.hijriCalendar,
        HomeWidgetKind.memorize.name: AppRoutes.memorize,
        HomeWidgetKind.quran.name: AppRoutes.quran,
        HomeWidgetKind.reading.name: await _readingRoute() ?? AppRoutes.quran,
        HomeWidgetKind.khatmah.name: await _khatmahRoute(),
      },
      prayer: prayer,
      ayahs: await _ayahs(l10n),
      dates: dates,
      reading: await _reading(l10n),
      memorize: await _memorize(l10n, today),
      khatmah: _khatmah(l10n, today),
      until: [
        for (var m = 0; m < 15 * 60; m++)
          m >= 60
              ? l10n.activityHoursMinutes(m ~/ 60, m % 60)
              : l10n.activityMinutes(m),
      ],
    );
  }

  Future<String?> _readingRoute() async {
    final c = await ref.read(continueReadingProvider.future);
    final location = c.location;
    return location == null ? null : quranLocationRoute(location);
  }

  Future<({String title, String subtitle})?> _reading(
    AppLocalizations l10n,
  ) async {
    final c = await ref.read(continueReadingProvider.future);
    final location = c.location;
    if (location == null) return null;
    return (
      title: homeLocationLabel(l10n, location, chapterName: c.chapterName),
      subtitle: l10n.homeContinueReadingAction,
    );
  }

  Future<String> _khatmahRoute() async {
    final page = ref.read(khatmahTodayProvider)?.nextPage;
    if (page == null) return AppRoutes.home;
    final mushaf = await ref.read(defaultMushafProvider.future);
    return mushaf == null
        ? AppRoutes.home
        : '${AppRoutes.home}/page/${mushaf.id}/$page';
  }

  ({String date, String title, String line, double progress})? _khatmah(
    AppLocalizations l10n,
    DateTime today,
  ) {
    final k = ref.read(khatmahTodayProvider);
    if (k == null) return null;
    return (
      date: isoDate(today),
      title: k.dayNo <= k.days
          ? l10n.khatmahDayOf(k.dayNo, k.days)
          : l10n.khatmahPastEnd,
      line: k.finished
          ? l10n.khatmahFinished
          : k.doneToday
          ? l10n.khatmahTodayDone
          : k.from == k.to
          ? l10n.khatmahTodayPage(k.from)
          : l10n.khatmahTodayPages(k.from, k.to),
      progress: k.total == 0 ? 0 : (k.read / k.total).clamp(0, 1).toDouble(),
    );
  }

  Future<({String date, int done, int total, List<MemorizeRow> rows})?>
  _memorize(AppLocalizations l10n, DateTime today) async {
    final plan = await ref.read(todayPlanProvider.future);
    final lesson = await ref.read(newLessonProvider.future);
    if (lesson == null && plan.isEmpty) return null;
    final names = <int, String>{
      for (final s in ref.read(indexedSurahsProvider).value ?? const [])
        s.surah.surahNo:
            s.localizedName ?? s.arabicName ?? '${s.surah.surahNo}',
    };
    String range(int first, int last) {
      String name(int ayah) => names[ayah ~/ 1000] ?? '${ayah ~/ 1000}';
      if (first == last) return '${name(first)} ${first % 1000}';
      if (first ~/ 1000 == last ~/ 1000) {
        return '${name(first)} ${first % 1000}–${last % 1000}';
      }
      return '${name(first)} ${first % 1000} – ${name(last)} ${last % 1000}';
    }

    final lessonToday =
        lesson != null &&
        !lesson.rest &&
        !lesson.finished &&
        (lesson.done || lesson.runs.isNotEmpty);
    final total = (lessonToday ? 1 : 0) + plan.recent.length + plan.old.length;
    final done =
        (lessonToday && lesson.done ? 1 : 0) +
        plan.recent.where((t) => t.done).length +
        plan.old.where((t) => t.done).length;
    return (
      date: isoDate(today),
      done: done,
      total: total,
      rows: <MemorizeRow>[
        (
          title: l10n.memNewLesson,
          value: switch (lesson) {
            null => l10n.homeMemNoPlan,
            final l when l.finished => l10n.memPlanFinished,
            final l when l.done => l10n.memLessonDone,
            final l when l.rest => l10n.memLessonRest,
            final l when l.runs.isNotEmpty => range(
              l.runs.first.first,
              l.runs.last.last,
            ),
            _ => '',
          },
          done: lesson != null && (lesson.done || lesson.finished),
        ),
        if (plan.recent.isNotEmpty)
          (
            title: l10n.memRecent,
            value: l10n.homeMemTasksDone(
              plan.recent.where((t) => t.done).length,
              plan.recent.length,
            ),
            done: plan.recent.every((t) => t.done),
          ),
        if (plan.old.isNotEmpty)
          (
            title: l10n.memOld,
            value: l10n.homeMemTasksDone(
              plan.old.where((t) => t.done).length,
              plan.old.length,
            ),
            done: plan.old.every((t) => t.done),
          ),
      ],
    );
  }

  /// The daily ayahs, each from the installed dataset: its Uthmani words
  /// (the verified text — the widget only draws it), its reference in the
  /// app's language, the first shown translation.
  Future<List<WidgetAyah>> _ayahs(AppLocalizations l10n) async {
    if (!await ref.read(hasInstalledQuranDatasetProvider.future)) {
      return const [];
    }
    final repository = ref.read(quranRepositoryProvider);
    final language = l10n.localeName.split('_').first;
    final slugs = ref.read(shownTranslationSlugsProvider);
    final out = <WidgetAyah>[];
    for (final verse in dailyAyahReferences) {
      final ayah = await repository.getAyah(verse);
      if (ayah == null) return const [];
      final words = await repository.getWordsForAyah(
        ayah.id,
        scriptCode: 'uthmani',
      );
      final name = (await repository.getSurahLocalization(
        verse.chapterNo,
        languageCode: surahNameLanguage(language),
      ))?.name;
      final translation = slugs.isEmpty
          ? null
          : (await ref
                    .read(translationRepositoryProvider)
                    .getVerseText(verse, slug: slugs.first))
                ?.text;
      out.add((
        text: [for (final w in words) w.text].join(' '),
        reference: name != null
            ? l10n.homeDailyAyahReferenceNamed(name, verse.verseNo)
            : l10n.homeDailyAyahReference(verse.chapterNo, verse.verseNo),
        translation: translation,
        route: quranLocationRoute(
          QuranLocation.ayah(verse.chapterNo, verse.verseNo),
        ),
      ));
    }
    return out;
  }
}

final homeWidgetsPublisherProvider =
    NotifierProvider<HomeWidgetsPublisher, void>(HomeWidgetsPublisher.new);
