import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/localization/locale_controller.dart';
import '../../../quran/domain/models/surah_models.dart';
import '../../../quran/quran_providers.dart';

part 'home_providers.g.dart';

/// The Quran database has real plumbing (Milestone 2) but no app-boot import
/// step wires an actual dataset into it yet — see `docs/ARCHITECTURE.md` §4a
/// and `docs/DATA_RESOURCE_REQUIREMENTS.md`. Every Home section that reads
/// Quran content checks this first and renders an "unavailable resource"
/// state when it's `false`, rather than showing broken or fabricated
/// content — this milestone's explicit "do not insert fake production
/// Quran data" requirement.
@riverpod
Future<bool> hasInstalledQuranDataset(Ref ref) async {
  final repository = ref.watch(quranRepositoryProvider);
  final surah = await repository.getSurah(1);
  return surah != null;
}

/// A deterministic, date-seeded chapter number, so "today's" featured verse
/// is stable across rebuilds/app restarts on the same calendar day without
/// needing any stored state. Pure and separately testable from the provider
/// that consumes it.
int dailyAyahSurahNoForDate(DateTime date) {
  final epoch = DateTime(2024, 1, 1);
  final daysSinceEpoch = DateTime(
    date.year,
    date.month,
    date.day,
  ).difference(epoch).inDays;
  return (daysSinceEpoch % 114 + 114) % 114 + 1;
}

/// Today's featured verse reference. Only ever verse 1 of the chosen
/// chapter, and only ever a chapter/verse *number* reference — no canonical
/// Arabic text is fetched or rendered here, since Quran-glyph rendering is
/// the Reader/Mushaf milestones' job, not Home's.
class DailyAyahReference {
  const DailyAyahReference({
    required this.surahNo,
    required this.verseNo,
    this.chapterName,
  });

  final int surahNo;
  final int verseNo;

  /// The chapter's localized name, when the installed dataset has a
  /// [SurahLocalization] for the current UI language; `null` falls back to
  /// a numeric-only reference.
  final String? chapterName;
}

@riverpod
Future<DailyAyahReference?> dailyAyah(Ref ref) async {
  final installed = await ref.watch(hasInstalledQuranDatasetProvider.future);
  if (!installed) return null;

  final repository = ref.watch(quranRepositoryProvider);
  final surahNo = dailyAyahSurahNoForDate(DateTime.now());
  final surah = await repository.getSurah(surahNo);
  if (surah == null) return null;

  final languageCode =
      ref.watch(localeControllerProvider)?.languageCode ?? 'en';
  final localization = await repository.getSurahLocalization(
    surahNo,
    languageCode: languageCode,
  );

  return DailyAyahReference(
    surahNo: surahNo,
    verseNo: 1,
    chapterName: localization?.name,
  );
}

/// Chapter numbers curated for Home's "Featured Reading" rail. These are
/// structural chapter *numbers*, not Quran text, so curating them here does
/// not touch `docs/CLEAN_ROOM_RULES.md`'s "never generate canonical Quran
/// text with AI" rule — they are the same kind of reference a table of
/// contents would list.
const featuredReadingSurahNumbers = <int>[1, 18, 36, 55, 67];

/// One curated chapter, with its localized name resolved when the
/// installed dataset has one for the current UI language.
class FeaturedChapterRef {
  const FeaturedChapterRef({required this.surah, this.name});

  final Surah surah;
  final String? name;
}

@riverpod
Future<List<FeaturedChapterRef>> featuredReadingChapters(Ref ref) async {
  final installed = await ref.watch(hasInstalledQuranDatasetProvider.future);
  if (!installed) return const [];

  final repository = ref.watch(quranRepositoryProvider);
  final languageCode =
      ref.watch(localeControllerProvider)?.languageCode ?? 'en';
  final chapters = <FeaturedChapterRef>[];
  for (final surahNo in featuredReadingSurahNumbers) {
    final surah = await repository.getSurah(surahNo);
    if (surah == null) continue;
    final localization = await repository.getSurahLocalization(
      surahNo,
      languageCode: languageCode,
    );
    chapters.add(FeaturedChapterRef(surah: surah, name: localization?.name));
  }
  return chapters;
}

/// Read-history preview for "Continue Reading". Always empty today: no
/// `UserDataRepository` provider exists yet (Milestone 11 owns it) — this
/// provider is the seam Home already depends on, so wiring the real
/// implementation later is a one-line change here, not a Home redesign.
@riverpod
Future<List<String>> readHistoryPreview(Ref ref) async => const [];

/// Outdated-resource summaries for the update banner. Always empty today:
/// `ResourceRepository` (`core/downloads`) is an interface with no concrete
/// implementation until the Resource Manager milestone (13) — this provider
/// is the seam the banner already depends on and hides itself while the
/// list is empty, matching the reference app's own "shown only if" banner
/// behavior.
@riverpod
Future<List<String>> outdatedResourceSummaries(Ref ref) async => const [];
