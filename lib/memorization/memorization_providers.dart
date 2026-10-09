import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/database/database_connection.dart';
import 'application/memorization_today.dart';
import 'data/drift_memorization_repository.dart';
import 'data/memorization_database.dart';
import 'domain/models/memorization_models.dart';
import 'domain/repositories/memorization_repository.dart';

/// The memorization database, opened through the cross-platform helper
/// every Tahfeez database uses.
final memorizationDatabaseProvider = Provider<MemorizationDatabase>((ref) {
  final db = MemorizationDatabase(
    openConnection(databaseName: 'tahfeez_memorization'),
  );
  ref.onDispose(db.close);
  return db;
});

/// The app-wide [MemorizationRepository]; tests override it.
final memorizationRepositoryProvider = Provider<MemorizationRepository>(
  (ref) => DriftMemorizationRepository(ref.watch(memorizationDatabaseProvider)),
);

/// Stores a finished recitation test's graded ayahs (`gradeTest`) and adds
/// them to the session's summary. A failure to store is logged, never thrown
/// at the recitation.
final memorizationRecorderProvider =
    Provider<Future<void> Function(List<AyahAttempt>)>((ref) {
      return (attempts) async {
        try {
          await ref.read(testSummaryProvider.notifier).record(attempts);
        } catch (e) {
          if (!kReleaseMode) debugPrint('Memorization: not recorded: $e');
        }
      };
    });

/// How long a finished test waits before it is graded, so the last ayah's
/// pronunciation check can confirm its verdicts; tests set none.
final memorizationRecordDelayProvider = Provider<Duration>(
  (ref) => const Duration(seconds: 1),
);
