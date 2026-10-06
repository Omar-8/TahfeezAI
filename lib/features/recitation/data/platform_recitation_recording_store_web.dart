import '../../../core/storage/file_storage.dart';
import '../domain/recitation_recording_store.dart';
import 'web_recitation_recording_store.dart';

RecitationRecordingStore createPlatformRecordingStore(
  FileStorage fileStorage, {
  bool developerExport = false,
}) => const WebRecitationRecordingStore();
