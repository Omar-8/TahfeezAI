import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tahfeez_ai/features/quran/application/quran_index_providers.dart';
import 'package:tahfeez_ai/memorization/application/memorization_today.dart';
import 'package:tahfeez_ai/memorization/data/drift_memorization_repository.dart';
import 'package:tahfeez_ai/memorization/data/memorization_database.dart';
import 'package:tahfeez_ai/memorization/domain/models/memorization_models.dart';
import 'package:tahfeez_ai/memorization/memorization_providers.dart';
import 'package:tahfeez_ai/quran/domain/models/surah_models.dart';

void main() {
  test('a surah\'s progress: the share memorized, and tajweed in its '
      'ayahs\' latest recitations', () async {
    final db = MemorizationDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final repo = DriftMemorizationRepository(db);
    final container = ProviderContainer(
      overrides: [
        memorizationRepositoryProvider.overrideWithValue(repo),
        indexedSurahsProvider.overrideWith(
          (ref) async => [
            IndexedSurah(
              surah: const Surah(
                surahNo: 112,
                ayahCount: 4,
                revelationOrder: 22,
                rukusCount: 1,
                revelationType: RevelationType.meccan,
              ),
              arabicName: null,
              localizedName: 'Al-Ikhlas',
            ),
          ],
        ),
      ],
    );
    addTearDown(container.dispose);
    final t0 = DateTime(2026, 10, 9);
    AyahAttempt a(int id, {int pronunciation = 0, DateTime? at}) => AyahAttempt(
      ayahId: id,
      sessionId: 's',
      at: at ?? t0,
      grade: pronunciation > 0 ? AyahGrade.hard : AyahGrade.good,
      words: 4,
      pronunciation: pronunciation,
      hidden: true,
    );
    // Three of the four ayahs recited from memory; the first one twice, its
    // latest with a pronunciation mistake.
    await repo.recordTest([a(112001), a(112002), a(112003)]);
    await repo.recordTest([
      a(112001, pronunciation: 2, at: t0.add(const Duration(hours: 1))),
    ]);
    // Watched, as the surah list does.
    container.listen(surahProgressProvider, (_, _) {});
    final progress = await container.read(surahProgressProvider.future);
    final p = progress[112]!;
    expect((p.ayahs, p.memorized), (4, 3));
    expect(p.memorization, 0.75);
    expect(p.tajweed, closeTo(10 / 12, 1e-9));
    expect(progress.containsKey(113), isFalse);
  });

  test('progress updates as tests are recorded', () async {
    final db = MemorizationDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final repo = DriftMemorizationRepository(db);
    final container = ProviderContainer(
      overrides: [
        memorizationRepositoryProvider.overrideWithValue(repo),
        indexedSurahsProvider.overrideWith(
          (ref) async => [
            IndexedSurah(
              surah: const Surah(
                surahNo: 112,
                ayahCount: 4,
                revelationOrder: 22,
                rukusCount: 1,
                revelationType: RevelationType.meccan,
              ),
              arabicName: null,
              localizedName: 'Al-Ikhlas',
            ),
          ],
        ),
      ],
    );
    addTearDown(container.dispose);
    container.listen(surahProgressProvider, (_, _) {});
    AyahAttempt a(int id) => AyahAttempt(
      ayahId: id,
      sessionId: 's',
      at: DateTime(2026, 10, 9),
      grade: AyahGrade.good,
      words: 4,
      hidden: true,
    );
    await repo.recordTest([a(112001)]);
    await pumpEventQueue();
    expect(
      (await container.read(surahProgressProvider.future))[112]!.memorized,
      1,
    );
    await repo.recordTest([a(112002), a(112003), a(112004)]);
    await pumpEventQueue();
    expect(
      (await container.read(surahProgressProvider.future))[112]!.memorized,
      4,
      reason: 'the surah finished',
    );
  });
}
