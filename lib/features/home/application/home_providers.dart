import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/localization/locale_controller.dart';
import '../../../quran/application/quran_dataset_status.dart';
import '../../../quran/application/quran_script_code.dart';
import '../../../quran/application/recent_quran_location.dart';
import '../../../quran/application/translation_selection_controller.dart';
import '../../../quran/domain/models/quran_location.dart';
import '../../../quran/domain/models/quran_refs.dart';
import '../../../quran/domain/models/surah_models.dart';
import '../../../quran/quran_providers.dart';
import '../../../quran/translation_providers.dart';
import '../../recitation/application/recitation_providers.dart';
import '../../recitation/application/recitation_session_controller.dart';
import '../../recitation/domain/recitation_session.dart';

part 'home_providers.g.dart';

/// Ayahs curated for Home's Daily Ayah: short, self-contained verses that
/// read well on their own. Verse *references* only (chapter and verse
/// numbers, like a table of contents) — the text always comes from the
/// installed, source-verified dataset, never from here.
const dailyAyahReferences = <VerseRef>[
  (chapterNo: 1, verseNo: 5),
  (chapterNo: 2, verseNo: 152),
  (chapterNo: 2, verseNo: 153),
  (chapterNo: 2, verseNo: 186),
  (chapterNo: 2, verseNo: 201),
  (chapterNo: 2, verseNo: 286),
  (chapterNo: 3, verseNo: 8),
  (chapterNo: 3, verseNo: 139),
  (chapterNo: 3, verseNo: 173),
  (chapterNo: 3, verseNo: 200),
  (chapterNo: 7, verseNo: 23),
  (chapterNo: 9, verseNo: 51),
  (chapterNo: 13, verseNo: 28),
  (chapterNo: 14, verseNo: 7),
  (chapterNo: 17, verseNo: 24),
  (chapterNo: 18, verseNo: 10),
  (chapterNo: 20, verseNo: 114),
  (chapterNo: 21, verseNo: 87),
  (chapterNo: 25, verseNo: 74),
  (chapterNo: 29, verseNo: 69),
  (chapterNo: 39, verseNo: 53),
  (chapterNo: 40, verseNo: 60),
  (chapterNo: 49, verseNo: 13),
  (chapterNo: 65, verseNo: 3),
  (chapterNo: 67, verseNo: 2),
  (chapterNo: 93, verseNo: 5),
  (chapterNo: 94, verseNo: 5),
  (chapterNo: 94, verseNo: 6),
];

/// Today's ayah from [dailyAyahReferences]: date-seeded, so it is stable
/// across rebuilds and restarts on the same calendar day without any
/// stored state, and changes at midnight. Pure and separately testable.
VerseRef dailyAyahVerseForDate(DateTime date) {
  final epoch = DateTime(2024, 1, 1);
  final days = DateTime(
    date.year,
    date.month,
    date.day,
  ).difference(epoch).inDays;
  final n = dailyAyahReferences.length;
  return dailyAyahReferences[(days % n + n) % n];
}

/// Today's ayah: its reference, its words in the selected script (the
/// display layer pairs them with the validated QPC Hafs text and font
/// where available, exactly as the reader does) and the first active
/// translation.
class DailyAyahReference {
  const DailyAyahReference({
    required this.surahNo,
    required this.verseNo,
    this.ayahId,
    this.chapterName,
    this.words = const [],
    this.translation,
  });

  final int surahNo;
  final int verseNo;

  /// `surahNo * 1000 + verseNo`, the dataset's stable verse id.
  final int? ayahId;

  /// The chapter's localized name, when the installed dataset has a
  /// [SurahLocalization] for the current UI language; `null` falls back to
  /// a numeric-only reference.
  final String? chapterName;

  /// The verse's words in the selected script, in order.
  final List<String> words;

  /// The first active translation's text, if any is installed and active.
  final String? translation;
}

@riverpod
Future<DailyAyahReference?> dailyAyah(Ref ref) async {
  final installed = await ref.watch(hasInstalledQuranDatasetProvider.future);
  if (!installed) return null;

  final repository = ref.watch(quranRepositoryProvider);
  final verse = dailyAyahVerseForDate(DateTime.now());
  final ayah = await repository.getAyah(verse);
  if (ayah == null) return null;
  final words = await repository.getWordsForAyah(
    ayah.id,
    scriptCode: ref.watch(quranScriptCodeProvider),
  );

  final languageCode =
      ref.watch(localeControllerProvider)?.languageCode ?? 'en';
  final localization = await repository.getSurahLocalization(
    verse.chapterNo,
    languageCode: languageCode,
  );
  final slugs = ref.watch(translationSelectionControllerProvider);
  final translation = slugs.isEmpty
      ? null
      : await ref
            .watch(translationRepositoryProvider)
            .getVerseText(verse, slug: slugs.first);

  return DailyAyahReference(
    surahNo: verse.chapterNo,
    verseNo: verse.verseNo,
    ayahId: ayah.id,
    chapterName: localization?.name,
    words: [for (final w in words) w.text],
    translation: translation?.text,
  );
}

/// Chapter numbers curated for Home's "Featured Reading" rail. These are
/// structural chapter *numbers*, not Quran text, so curating them here does
/// not touch `docs/CLEAN_ROOM_RULES.md`'s "never generate canonical Quran
/// text with AI" rule — they are the same kind of reference a table of
/// contents would list.
const featuredReadingSurahNumbers = <int>[1, 18, 36, 55, 67];

/// Why a featured chapter is shown first today.
enum FeaturedOccasion { friday, night }

/// One curated chapter, with its localized name resolved when the
/// installed dataset has one for the current UI language.
class FeaturedChapterRef {
  const FeaturedChapterRef({required this.surah, this.name, this.occasion});

  final Surah surah;
  final String? name;

  /// Set on the chapter brought to the front for today's occasion.
  final FeaturedOccasion? occasion;
}

/// [featuredReadingSurahNumbers] in today's order: Al-Kahf first on a
/// Friday, Al-Mulk first in the evening and at night (both customarily
/// recited then), the others as listed.
List<(int, FeaturedOccasion?)> featuredOrderFor(DateTime now) {
  final occasion = now.weekday == DateTime.friday
      ? (18, FeaturedOccasion.friday)
      : now.hour >= 19 || now.hour < 4
      ? (67, FeaturedOccasion.night)
      : null;
  if (occasion == null) {
    return [for (final n in featuredReadingSurahNumbers) (n, null)];
  }
  return [
    occasion,
    for (final n in featuredReadingSurahNumbers)
      if (n != occasion.$1) (n, null),
  ];
}

@riverpod
Future<List<FeaturedChapterRef>> featuredReadingChapters(Ref ref) async {
  final installed = await ref.watch(hasInstalledQuranDatasetProvider.future);
  if (!installed) return const [];

  final repository = ref.watch(quranRepositoryProvider);
  final languageCode =
      ref.watch(localeControllerProvider)?.languageCode ?? 'en';
  final chapters = <FeaturedChapterRef>[];
  for (final (surahNo, occasion) in featuredOrderFor(DateTime.now())) {
    final surah = await repository.getSurah(surahNo);
    if (surah == null) continue;
    final localization = await repository.getSurahLocalization(
      surahNo,
      languageCode: languageCode,
    );
    chapters.add(
      FeaturedChapterRef(
        surah: surah,
        name: localization?.name,
        occasion: occasion,
      ),
    );
  }
  return chapters;
}

/// Where "Continue Reading" picks up: the last place read (recorded by the
/// Quran index and the reader), with the chapter's name when it has one,
/// and the place the last recitation session started.
class ContinueReading {
  const ContinueReading({this.location, this.chapterName, this.lastRecitation});

  final QuranLocation? location;
  final String? chapterName;
  final RecitationSession? lastRecitation;
}

@riverpod
Future<ContinueReading> continueReading(Ref ref) async {
  final location = ref.watch(recentQuranLocationControllerProvider);
  _refreshOnSessionChange(ref);
  final sessions = await ref.watch(recitationSessionRepositoryProvider).list();
  final chapterNo = switch (location) {
    QuranLocationSurah(:final surahNo) => surahNo,
    QuranLocationAyah(:final chapterNo) => chapterNo,
    QuranLocationAyahRange(:final chapterNo) => chapterNo,
    _ => null,
  };
  String? name;
  if (chapterNo != null &&
      await ref.watch(hasInstalledQuranDatasetProvider.future)) {
    final languageCode =
        ref.watch(localeControllerProvider)?.languageCode ?? 'en';
    name =
        (await ref
                .watch(quranRepositoryProvider)
                .getSurahLocalization(chapterNo, languageCode: languageCode))
            ?.name;
  }
  return ContinueReading(
    location: location,
    chapterName: name,
    lastRecitation: sessions.isEmpty ? null : sessions.first,
  );
}

/// Recomputes the calling provider when a recitation session starts, pauses
/// or ends — not on every state change while one runs.
void _refreshOnSessionChange(Ref ref) {
  ref.listen(recitationSessionControllerProvider, (previous, next) {
    if (previous?.phase != next.phase) ref.invalidateSelf();
  });
}

/// Home's memorization summary: the latest sessions and this week's totals.
class MemorizationSummary {
  const MemorizationSummary({
    this.recent = const [],
    this.weekSessions = 0,
    this.weekMinutes = 0,
  });

  final List<RecitationSession> recent;
  final int weekSessions, weekMinutes;
}

/// [sessions] summarized as of [now]: the three latest, and the sessions and
/// minutes of the last seven days. Pure and separately testable.
MemorizationSummary summarizeSessions(
  List<RecitationSession> sessions,
  DateTime now,
) {
  final sorted = [...sessions]
    ..sort((a, b) => b.startedAt.compareTo(a.startedAt));
  final week = now.subtract(const Duration(days: 7));
  final thisWeek = [
    for (final s in sorted)
      if (s.startedAt.isAfter(week)) s,
  ];
  final seconds = thisWeek.fold<int>(0, (t, s) => t + s.duration.inSeconds);
  return MemorizationSummary(
    recent: sorted.take(3).toList(),
    weekSessions: thisWeek.length,
    weekMinutes: (seconds / 60).round(),
  );
}

@riverpod
Future<MemorizationSummary> memorizationSummary(Ref ref) async {
  _refreshOnSessionChange(ref);
  final sessions = await ref.watch(recitationSessionRepositoryProvider).list();
  return summarizeSessions(sessions, DateTime.now());
}

/// Outdated-resource summaries for the update banner. Always empty today:
/// `ResourceRepository` (`core/downloads`) is an interface with no concrete
/// implementation until the Resource Manager milestone (13) — this provider
/// is the seam the banner already depends on and hides itself while the
/// list is empty, matching the reference app's own "shown only if" banner
/// behavior.
@riverpod
Future<List<String>> outdatedResourceSummaries(Ref ref) async => const [];
