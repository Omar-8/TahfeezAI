import 'dart:typed_data';

import 'recitation_audio_format.dart';

/// Writes one session's audio as a single recording.
abstract class RecitationRecordingSink {
  /// Appends PCM16LE [chunk] to the recording.
  void add(Uint8List chunk);

  /// Finishes the recording and returns a reference to it — a file path
  /// on Android, an in-memory object URL on the web — or `null` if nothing
  /// could be kept.
  Future<String?> close();

  /// Abandons the recording and deletes whatever was written.
  Future<void> discard();
}

/// Creates a [RecitationRecordingSink] per session.
abstract class RecitationRecordingStore {
  Future<RecitationRecordingSink> open({
    required String sessionId,
    required RecitationAudioFormat format,
  });
}
