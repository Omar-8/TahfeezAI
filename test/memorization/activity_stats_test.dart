import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tahfeez_ai/memorization/application/activity_stats.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('activity is counted, the Mushaf timed, and the totals kept', () async {
    final first = ProviderContainer();
    final stats = first.read(activityStatsProvider.notifier);
    stats.add(recitedWords: 12, recitedAyahs: 2); // before the saved totals
    await Future<void>.delayed(const Duration(milliseconds: 10));
    stats.add(heardAyahs: 3);
    stats.mushafShown(true);
    await Future<void>.delayed(const Duration(milliseconds: 1100));
    stats.mushafShown(false);
    final now = first.read(activityStatsProvider);
    expect((now.recitedWords, now.recitedAyahs, now.heardAyahs), (12, 2, 3));
    expect(now.mushafSeconds, 1);
    await Future<void>.delayed(const Duration(milliseconds: 2100)); // saved
    first.dispose();

    final next = ProviderContainer();
    addTearDown(next.dispose);
    next.read(activityStatsProvider);
    await Future<void>.delayed(const Duration(milliseconds: 10));
    expect(next.read(activityStatsProvider).recitedWords, 12);
    expect(next.read(activityStatsProvider).mushafSeconds, 1);
  });
}
