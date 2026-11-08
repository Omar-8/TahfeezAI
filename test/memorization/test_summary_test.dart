import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tahfeez_ai/memorization/application/memorization_today.dart';
import 'package:tahfeez_ai/memorization/data/memorization_database.dart';
import 'package:tahfeez_ai/memorization/domain/models/memorization_models.dart';
import 'package:tahfeez_ai/memorization/memorization_providers.dart';

/// A session's results: its ayahs; a Follow along run's: every turn's (a
/// session each) together.
void main() {
  late ProviderContainer container;
  late MemorizationDatabase db;
  final at = DateTime(2026, 11, 3, 10);

  setUp(() {
    db = MemorizationDatabase(NativeDatabase.memory());
    container = ProviderContainer(
      overrides: [memorizationDatabaseProvider.overrideWithValue(db)],
    );
  });
  tearDown(() async {
    container.dispose();
    await db.close();
  });

  AyahAttempt attempt(int ayah, String session) => AyahAttempt(
    ayahId: ayah,
    sessionId: session,
    at: at,
    grade: AyahGrade.good,
    words: 4,
    hidden: true,
  );

  List<int> ayahs() => [
    for (final r in container.read(testSummaryProvider)!.rows) r.attempt.ayahId,
  ];

  test('sessions summed up one by one', () async {
    final summaries = container.read(testSummaryProvider.notifier);
    await summaries.record([attempt(112001, 'a')]);
    await summaries.record([attempt(112002, 'b')]);
    expect(ayahs(), [112002], reason: 'a new session: its own results');
  });

  test(
    'a Follow along run: its turns together, then one by one again',
    () async {
      final summaries = container.read(testSummaryProvider.notifier)
        ..beginRun();
      await summaries.record([attempt(112001, 'turn 1')]);
      await summaries.record([attempt(112002, 'turn 2')]);
      expect(ayahs(), [112001, 112002]);
      summaries.endRun();
      await summaries.record([attempt(112003, 'after')]);
      expect(ayahs(), [112003]);
    },
  );

  test('each ayah\'s last test before this session kept, to compare '
      '(a loop\'s earlier passes are this session, not "last time")', () async {
    final summaries = container.read(testSummaryProvider.notifier);
    await summaries.record([attempt(112001, 'yesterday')]);
    await summaries.record([
      attempt(112001, 'today'),
      attempt(112002, 'today'),
    ]);
    // A second pass of the same session.
    await summaries.record([attempt(112001, 'today')]);
    final rows = container.read(testSummaryProvider)!.rows;
    expect(
      [for (final r in rows) r.previous?.sessionId],
      ['yesterday', null, 'yesterday'],
    );
  });
}
