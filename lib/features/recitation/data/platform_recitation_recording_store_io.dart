import 'package:path_provider/path_provider.dart';

import '../../../core/storage/file_storage.dart';
import '../domain/recitation_recording_store.dart';
import 'file_recitation_recording_store.dart';

/// [developerExport]: recordings go to the app's external files directory
/// (adb-readable) instead of its private data directory — development
/// diagnostics only (see `recitationKeepRecordingsProvider`).
RecitationRecordingStore createPlatformRecordingStore(
  FileStorage fileStorage, {
  bool developerExport = false,
}) => FileRecitationRecordingStore(
  developerExport ? _ExternalFilesStorage(fileStorage) : fileStorage,
);

class _ExternalFilesStorage implements FileStorage {
  const _ExternalFilesStorage(this._base);

  final FileStorage _base;

  @override
  Future<String> appDataDirectoryPath() async =>
      (await getExternalStorageDirectory())?.path ??
      await _base.appDataDirectoryPath();

  @override
  Future<String> cacheDirectoryPath() => _base.cacheDirectoryPath();

  @override
  Future<String> temporaryExportDirectoryPath() =>
      _base.temporaryExportDirectoryPath();
}
