import 'package:record/record.dart';

import '../domain/recitation_audio_format.dart';
import '../domain/recitation_audio_source.dart';

/// [RecitationAudioSource] backed by `package:record`'s PCM stream mode
/// (Android `AudioRecord`, Web `getUserMedia` + AudioWorklet).
class RecordPackageAudioSource implements RecitationAudioSource {
  RecordPackageAudioSource({AudioRecorder? recorder, this.processing = false})
    : _recorder = recorder ?? AudioRecorder();

  final AudioRecorder _recorder;

  /// The platform's noise suppression, echo cancelling and level control —
  /// off by default: suppression strips the soft hiss of ذ ث ف خ that the
  /// pronunciation check needs (owner's phone takes, 2026-10-20: one of two
  /// with it on had 6 such letters flagged, none of the takes without it
  /// more than 1).
  final bool processing;

  @override
  Future<MicrophonePermission> checkPermission({bool request = true}) async {
    final granted = await _recorder.hasPermission(request: request);
    return granted ? MicrophonePermission.granted : MicrophonePermission.denied;
  }

  @override
  Future<RecitationAudioCapture> start(RecitationAudioFormat requested) async {
    var actual = requested;
    // Fires synchronously during startStream if the platform had to adjust
    // the request (e.g. a browser that can't resample).
    await _recorder.setOnConfigChanged((config) {
      actual = RecitationAudioFormat(
        sampleRate: config.sampleRate,
        channels: config.numChannels,
      );
    });
    final stream = await _recorder.startStream(
      RecordConfig(
        encoder: AudioEncoder.pcm16bits,
        sampleRate: requested.sampleRate,
        numChannels: requested.channels,
        // The platform's clean-up: off by default (see [processing]).
        echoCancel: processing,
        noiseSuppress: processing,
        autoGain: processing,
        // A phone call or another app taking the mic shouldn't silently
        // end the session.
        audioInterruption: AudioInterruptionMode.pauseResume,
      ),
    );
    await _recorder.setOnConfigChanged(null);
    return RecitationAudioCapture(format: actual, audio: stream);
  }

  @override
  Future<void> stop() async {
    await _recorder.stop();
  }

  @override
  Future<void> dispose() => _recorder.dispose();
}
