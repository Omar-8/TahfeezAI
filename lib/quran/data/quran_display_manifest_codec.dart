import '../domain/models/quran_display_models.dart';

/// Decodes the manifest written by
/// `tool/quran_data/build_qpc_hafs_display.dart`. The inverse encoder lives
/// in that script, since only the build tool ever writes this file — the
/// running app only ever reads it.
QpcHafsDisplayManifest qpcHafsDisplayManifestFromJson(
  Map<String, dynamic> json,
) {
  final wordsJson = json['words'] as Map<String, dynamic>;
  return QpcHafsDisplayManifest(
    schemaVersion: json['schemaVersion'] as int,
    sourceHash: json['sourceHash'] as String,
    importedAyahCount: json['importedAyahCount'] as int,
    excludedAyahIds: (json['excludedAyahIds'] as List).cast<int>(),
    wordsByAyahId: {
      for (final entry in wordsJson.entries)
        int.parse(entry.key): (entry.value as List).cast<String>(),
    },
  );
}
