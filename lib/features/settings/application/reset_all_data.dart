import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/notifications/daily_reminder_scheduler.dart';
import '../../../core/storage/storage_providers.dart';
import '../../../memorization/memorization_providers.dart';
import '../../../quran/data/import/bundled_dataset_seeder.dart';

/// Settings → Reset all data: deletes the user's own data — memorization
/// (memories, test results, plans), recitation history and every setting,
/// and cancels the daily reminder. The Quran, translations, tafsir and
/// word meanings (bundled resources, not user data) stay installed.
Future<void> resetAllData(WidgetRef ref) async {
  await ref.read(dailyReminderSchedulerProvider).cancel();
  await ref.read(memorizationRepositoryProvider).clearAll();
  await ref.read(browserStorageProvider).clearExcept(const {
    BundledDatasetSeeder.seededVersionKey,
  });
}
