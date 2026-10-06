import 'dart:typed_data';

import 'recitation_audio_format.dart';

/// Whether the app may use the microphone.
enum MicrophonePermission { granted, denied }

/// A live, open microphone: the format it actually delivers and the PCM
/// chunks themselves.
class RecitationAudioCapture {
  const RecitationAudioCapture({required this.format, required this.audio});

  /// The format [audio] is really in — may differ from the requested one
  /// if the platform could not honor it.
  final RecitationAudioFormat format;

  /// Raw PCM16LE chunks, in capture order, until the source is stopped.
  final Stream<Uint8List> audio;
}

/// The microphone boundary for live recitation.
///
/// Presentation and application code never touch a recording plugin
/// directly; they go through this interface so the controller is testable
/// with a fake source and a future recognizer can be fed from the same
/// stream.
abstract class RecitationAudioSource {
  /// Checks — and, if [request] is true, asks the user for — microphone
  /// access.
  Future<MicrophonePermission> checkPermission({bool request = true});

  /// Opens the microphone and starts streaming [requested]-format PCM.
  ///
  /// The microphone stays open until [stop]; pausing a session is done by
  /// the caller ignoring chunks, not by closing the mic, so resuming is
  /// instant and never re-prompts for permission.
  Future<RecitationAudioCapture> start(RecitationAudioFormat requested);

  /// Closes the microphone. The capture stream completes afterwards.
  Future<void> stop();

  /// Releases the underlying recorder. The source can't be used after this.
  Future<void> dispose();
}
