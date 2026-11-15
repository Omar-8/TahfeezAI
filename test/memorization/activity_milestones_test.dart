import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tahfeez_ai/core/storage/storage_providers.dart';
import 'package:tahfeez_ai/memorization/application/activity_milestones.dart';
import 'package:tahfeez_ai/memorization/application/activity_stats.dart';
import 'package:tahfeez_ai/memorization/application/memorization_progress.dart';
import 'package:tahfeez_ai/memorization/domain/milestones.dart';

import '../test_helpers/memory_storage.dart';

/// Lifetime counts reached — ayahs and words recited, days in the Mushaf
/// (owner, 2026-11-15): each celebrated once, as it is crossed; those
/// already reached when the app first looks are not news.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('the counts\' milestones', () {
    expect(
      Milestones.activity(
        recitedAyahs: 5200,
        recitedWords: 9999,
        mushafSeconds: 15 * 86400,
      ).map((m) => m.id),
      [
        'activity-ayahs-1000',
        'activity-ayahs-5000',
        'activity-mushafDays-1',
        'activity-mushafDays-7',
        'activity-mushafDays-14',
      ],
    );
  });

  late MemoryStorage storage;
  late ProviderContainer c;

  Future<void> start({ActivityStats saved = const ActivityStats()}) async {
    storage.values[ActivityStatsController.storageKey] = jsonEncode(
      saved.toJson(),
    );
    c = ProviderContainer(
      overrides: [
        browserStorageProvider.overrideWithValue(storage),
        milestonesReachedProvider.overrideWith((ref) async => const []),
      ],
    );
    addTearDown(c.dispose);
    c.listen(activityMilestonesProvider, (_, _) {});
    c.listen(milestoneProvider, (_, _) {});
    await pumpEventQueue();
  }

  Milestone? shown() => c.read(milestoneProvider);

  setUp(() => storage = MemoryStorage());

  test('already past some at the first look: none shown; the next crossed: '
      'shown, once', () async {
    await start(saved: const ActivityStats(recitedAyahs: 4990));
    expect(shown(), isNull, reason: '1,000 reached before: not news');
    c.read(activityStatsProvider.notifier).add(recitedAyahs: 5);
    await pumpEventQueue();
    expect(shown(), isNull);
    c.read(activityStatsProvider.notifier).add(recitedAyahs: 10);
    await pumpEventQueue();
    expect(shown(), const ActivityMilestone(ActivityKind.ayahs, 5000).having);
    c.read(milestoneProvider.notifier).dismiss();
    c.read(activityStatsProvider.notifier).add(recitedAyahs: 10);
    await pumpEventQueue();
    expect(shown(), isNull, reason: 'once');
  });

  test('several crossed at once: the highest of each kind', () async {
    await start(saved: const ActivityStats(recitedWords: 9000));
    c
        .read(activityStatsProvider.notifier)
        .add(recitedWords: 100000, mushafSeconds: 8 * 86400);
    await pumpEventQueue();
    final ids = <String>[];
    for (var m = shown(); m != null; m = shown()) {
      ids.add(m.id);
      c.read(milestoneProvider.notifier).dismiss();
    }
    expect(
      ids,
      unorderedEquals(['activity-words-100000', 'activity-mushafDays-7']),
    );
  });

  test('remembered: the app started again, not shown again', () async {
    await start(saved: const ActivityStats(recitedAyahs: 990));
    c.read(activityStatsProvider.notifier).add(recitedAyahs: 20);
    await pumpEventQueue();
    expect(shown()?.id, 'activity-ayahs-1000');
    await start(saved: const ActivityStats(recitedAyahs: 1010));
    expect(shown(), isNull);
  });
}

extension on ActivityMilestone {
  /// Matches a milestone with the same id.
  Matcher get having => predicate<Milestone?>((m) => m?.id == id, id);
}
