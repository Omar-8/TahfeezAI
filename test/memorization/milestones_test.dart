import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tahfeez_ai/core/storage/browser_storage.dart';
import 'package:tahfeez_ai/core/storage/storage_providers.dart';
import 'package:tahfeez_ai/memorization/application/memorization_progress.dart';
import 'package:tahfeez_ai/memorization/domain/milestones.dart';
import 'package:tahfeez_ai/memorization/domain/models/memorization_models.dart';

AyahMemory _memorized(int ayahId, {bool verified = true}) => AyahMemory(
  ayahId: ayahId,
  status: MemoryStatus.memorized,
  verified: verified,
);

void main() {
  test('a surah and juz recited from memory, not ones only marked', () {
    final memories = {
      for (var a = 1; a <= 4; a++) 112000 + a: _memorized(112000 + a),
      for (var a = 1; a <= 5; a++)
        113000 + a: _memorized(113000 + a, verified: false),
    };
    final ids = Milestones.reached(
      memories: memories,
      juzAyahs: {
        30: [112001, 112002, 112003, 112004],
        29: [113001],
      },
      surahAyahs: {112: 4, 113: 5},
      totalAyahs: 6236,
      streak: 0,
    ).map((m) => m.id);
    expect(ids, unorderedEquals(['juz-30', 'surah-112']));
  });

  test('shares of the Quran and streaks reached', () {
    final memories = {
      for (var a = 1; a <= 63; a++) 2000 + a: _memorized(2000 + a),
    };
    final ids = Milestones.reached(
      memories: memories,
      juzAyahs: const {},
      surahAyahs: const {},
      totalAyahs: 6236,
      streak: 8,
    ).map((m) => m.id);
    expect(ids, unorderedEquals(['share-1', 'streak-3', 'streak-7']));
  });

  group('the milestone shown', () {
    Future<ProviderContainer> start() async {
      final storage = _Memory()..values[MilestoneController.storageKey] = '[]';
      final container = ProviderContainer(
        overrides: [
          browserStorageProvider.overrideWithValue(storage),
          milestonesReachedProvider.overrideWith(
            (ref) async => ref.watch(_reached),
          ),
        ],
      );
      addTearDown(container.dispose);
      container.listen(milestoneProvider, (_, _) {});
      await pumpEventQueue();
      return container;
    }

    Future<void> reach(ProviderContainer c, List<Milestone> m) async {
      c.read(_reached.notifier).set(m);
      await pumpEventQueue();
    }

    List<int>? surahs(ProviderContainer c) =>
        (c.read(milestoneProvider) as SurahsMilestone?)?.surahs;

    test('surahs memorized before it shows: congratulated together', () async {
      final c = await start();
      await reach(c, const [SurahMilestone(112)]);
      await reach(c, const [SurahMilestone(112), SurahMilestone(113)]);
      await reach(c, const [
        SurahMilestone(112),
        SurahMilestone(113),
        SurahMilestone(114),
      ]);
      expect(surahs(c), [112, 113, 114]);
      c.read(milestoneProvider.notifier).dismiss();
      expect(c.read(milestoneProvider), isNull);
    });

    test('one memorized while another is on screen: shown after it', () async {
      final c = await start();
      await reach(c, const [SurahMilestone(112)]);
      final onScreen = c.read(milestoneProvider);
      await reach(c, const [SurahMilestone(112), SurahMilestone(113)]);
      c.read(milestoneProvider.notifier).dismiss(onScreen);
      expect(surahs(c), [113]);
    });

    test('a juz too: the juz first, then the surahs — none dropped', () async {
      final c = await start();
      await reach(c, const [
        SurahMilestone(113),
        SurahMilestone(114),
        JuzMilestone(30),
      ]);
      expect(c.read(milestoneProvider), isA<JuzMilestone>());
      c.read(milestoneProvider.notifier).dismiss();
      expect(surahs(c), [113, 114]);
    });
  });
}

/// Storage in memory, as a phone's.
class _Memory implements BrowserStorage {
  final values = <String, Object?>{};

  @override
  Future<String?> getString(String key) async => values[key] as String?;
  @override
  Future<void> setString(String key, String value) async => values[key] = value;
  @override
  Future<bool?> getBool(String key) async => values[key] as bool?;
  @override
  Future<void> setBool(String key, bool value) async => values[key] = value;
  @override
  Future<void> remove(String key) async => values.remove(key);
  @override
  Future<void> clearExcept(Set<String> keep) async =>
      values.removeWhere((k, _) => !keep.contains(k));
  @override
  Future<Map<String, Object?>> readAll() async => {...values};
  @override
  Future<void> writeAll(Map<String, Object?> v) async => values.addAll(v);
}

/// The milestones reached so far, set by the test.
class _Reached extends Notifier<List<Milestone>> {
  @override
  List<Milestone> build() => const [];

  void set(List<Milestone> m) => state = m;
}

final _reached = NotifierProvider<_Reached, List<Milestone>>(_Reached.new);
