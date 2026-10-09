import 'dart:convert';
import 'dart:typed_data';

import '../../../core/storage/browser_storage.dart';
import '../../../memorization/domain/repositories/memorization_repository.dart';
import '../../../quran/data/import/bundled_dataset_seeder.dart';

/// The backup file's format id and version.
const _format = 'tahfeez-ai-backup';
const _version = 1;

/// Not user data: the bundled datasets' install marker.
const _notBackedUp = {BundledDatasetSeeder.seededVersionKey};

/// Thrown by [importUserData] for a file that isn't a TahfeezAI backup.
class InvalidBackupException implements Exception {
  const InvalidBackupException();
}

/// Settings → Export: the user's own data — memorization (memories, test
/// results, plans) and every setting — as a JSON file's bytes. The Quran
/// and bundled resources aren't included; recordings stay on the device.
Future<Uint8List> exportUserData({
  required BrowserStorage storage,
  required MemorizationRepository memorization,
  DateTime? now,
}) async {
  final prefs = await storage.readAll();
  final backup = {
    'format': _format,
    'version': _version,
    'exportedAt': (now ?? DateTime.now()).toUtc().toIso8601String(),
    'memorization': await memorization.exportAll(),
    'settings': {
      for (final e in prefs.entries)
        if (!_notBackedUp.contains(e.key)) e.key: e.value,
    },
  };
  return utf8.encode(jsonEncode(backup));
}

/// Settings → Import: replaces the user's data with a backup from
/// [exportUserData]. Checks the file's form before changing anything.
/// (The caller cancels and reschedules the daily reminder.)
Future<void> importUserData(
  List<int> bytes, {
  required BrowserStorage storage,
  required MemorizationRepository memorization,
}) async {
  final Object? decoded;
  try {
    decoded = jsonDecode(utf8.decode(bytes));
  } on FormatException {
    throw const InvalidBackupException();
  }
  if (decoded is! Map ||
      decoded['format'] != _format ||
      decoded['version'] is! int ||
      (decoded['version'] as int) > _version ||
      decoded['memorization'] is! Map ||
      decoded['settings'] is! Map) {
    throw const InvalidBackupException();
  }
  final tables = (decoded['memorization'] as Map).cast<String, Object?>();
  final settings = {
    for (final e in (decoded['settings'] as Map).entries)
      if (!_notBackedUp.contains(e.key)) '${e.key}': e.value,
  };
  await memorization.importAll(tables);
  await storage.clearExcept(_notBackedUp);
  await storage.writeAll(settings);
}
