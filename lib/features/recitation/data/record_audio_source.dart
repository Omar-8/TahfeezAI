import 'package:audio_session/audio_session.dart';
import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform, kIsWeb;
import 'package:flutter/services.dart' show EventChannel;
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

  static bool get _ios =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;

  /// iOS while reciting: play and record — the recorder's own category —
  /// so a word played meanwhile keeps the mic. Unconfigured, the player
  /// would set "playback" on its first sound, and recording would stop.
  static final _reciting = AudioSessionConfiguration(
    avAudioSessionCategory: AVAudioSessionCategory.playAndRecord,
    avAudioSessionCategoryOptions:
        AVAudioSessionCategoryOptions.defaultToSpeaker |
        AVAudioSessionCategoryOptions.allowBluetooth |
        AVAudioSessionCategoryOptions.allowBluetoothA2dp,
    avAudioSessionMode: AVAudioSessionMode.defaultMode,
  );

  @override
  Future<RecitationAudioCapture> start(RecitationAudioFormat requested) async {
    if (_ios) await (await AudioSession.instance).configure(_reciting);
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
        // Android: never paused by audio focus — the app's own audio (a
        // word played mid-recitation) took it for good and left the mic
        // paused (owner, 2026-11-01: playing audio must not touch the
        // recitation or the mic); a call pauses the recitation instead
        // (phone_calls.dart). iOS: the app's own audio never interrupts
        // its session, a call does — paused, and resumed after it.
        audioInterruption: _ios
            ? AudioInterruptionMode.pauseResume
            : AudioInterruptionMode.none,
      ),
    );
    await _recorder.setOnConfigChanged(null);
    return RecitationAudioCapture(format: actual, audio: stream);
  }

  /// Android: the audio mode (CallStateChannel.kt — no phone permission
  /// needed). iOS: the audio session's interruptions (a call, Siri, an
  /// alarm), not the ducking ones.
  @override
  Stream<bool> get calls {
    if (kIsWeb) return const Stream.empty();
    if (_ios) {
      return Stream.fromFuture(AudioSession.instance)
          .asyncExpand((session) => session.interruptionEventStream)
          .where((e) => e.type != AudioInterruptionType.duck)
          .map((e) => e.begin);
    }
    if (defaultTargetPlatform == TargetPlatform.android) {
      return const EventChannel('tahfeez/call')
          .receiveBroadcastStream()
          .map((inCall) => inCall == true);
    }
    return const Stream.empty();
  }

  @override
  Future<void> stop() async {
    await _recorder.stop();
    // Listening again: the player's own session (music).
    if (_ios) {
      await (await AudioSession.instance).configure(
        const AudioSessionConfiguration.music(),
      );
    }
  }

  @override
  Future<void> dispose() => _recorder.dispose();
}
