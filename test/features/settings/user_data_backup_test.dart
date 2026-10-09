import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tahfeez_ai/core/storage/browser_storage.dart';
import 'package:tahfeez_ai/features/settings/application/user_data_backup.dart';
import 'package:tahfeez_ai/memorization/data/drift_memorization_repository.dart';
import 'package:tahfeez_ai/memorization/data/memorization_database.dart';
import 'package:tahfeez_ai/memorization/domain/models/memorization_models.dart';
import 'package:tahfeez_ai/memorization/domain/models/memorization_plan.dart';
import 'package:tahfeez_ai/quran/data/import/bundled_dataset_seeder.dart';

void main() {
  late MemorizationDatabase db;
  late DriftMemorizationRepository repo;
  final storage = SharedPreferencesBrowserStorage();
  final t0 = DateTime(2026, 10, 1, 9);

  setUp(() async {
    db = MemorizationDatabase(NativeDatabase.memory());
    repo = DriftMemorizationRepository(db);
    await storage.clearExcept(const {});
  });
  tearDown(() => db.close());

  test('export, then import into a fresh install: everything back', () async {
    await repo.recordTest([
      AyahAttempt(
        ayahId: 112001,
        sessionId: 's',
        at: t0,
        grade: AyahGrade.good,
        words: 4,
        wrong: 0,
        hidden: true,
      ),
    ]);
    await repo.markMemorized([114001]);
    await repo.savePlan(
      MemorizationPlan(fromAyah: 78001, toAyah: 114006, createdAt: t0),
    );
    await storage.setString('core.locale', 'de');
    await storage.setBool('hifz.strict', true);
    await storage.setString(BundledDatasetSeeder.seededVersionKey, 'v1');

    final bytes = await exportUserData(
      storage: storage,
      memorization: repo,
      now: t0,
    );
    final json = jsonDecode(utf8.decode(bytes)) as Map;
    expect(json['format'], 'tahfeez-ai-backup');
    expect(
      (json['settings'] as Map).containsKey(
        BundledDatasetSeeder.seededVersionKey,
      ),
      isFalse,
      reason: 'the install marker is not user data',
    );

    // A fresh install, with its own settings.
    await repo.clearAll();
    await storage.clearExcept({BundledDatasetSeeder.seededVersionKey});
    await storage.setString('core.locale', 'fr');
    await storage.setString('other', 'x');

    await importUserData(bytes, storage: storage, memorization: repo);
    final memories = await repo.watchMemories().first;
    expect(memories.keys, unorderedEquals([112001, 114001]));
    expect(memories[114001]!.verified, isFalse);
    expect((await repo.attemptsFor(112001)).single.at, t0);
    final plan = await repo.watchActivePlan().first;
    expect((plan!.fromAyah, plan.toAyah), (78001, 114006));
    expect(await storage.getString('core.locale'), 'de');
    expect(await storage.getBool('hifz.strict'), isTrue);
    expect(await storage.getString('other'), isNull);
    expect(
      await storage.getString(BundledDatasetSeeder.seededVersionKey),
      'v1',
    );
  });

  test('a file that is not a backup changes nothing', () async {
    await repo.markMemorized([114001]);
    await storage.setString('core.locale', 'de');
    for (final bad in [
      'not json',
      '{"format":"something-else","version":1}',
      '{"format":"tahfeez-ai-backup","version":99,'
          '"memorization":{},"settings":{}}',
    ]) {
      await expectLater(
        importUserData(utf8.encode(bad), storage: storage, memorization: repo),
        throwsA(isA<InvalidBackupException>()),
      );
    }
    expect((await repo.watchMemories().first).keys, [114001]);
    expect(await storage.getString('core.locale'), 'de');
  });
}
