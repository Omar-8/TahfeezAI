import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../ai/speech/android_speech_live_recognizer.dart';
import '../../../ai/speech/live_quran_recognizer.dart';
import '../../../ai/speech/recognition_latency_tracker.dart';
import '../../../ai/speech/unavailable_live_recognizer.dart';
import '../../../ai/speech/web_recognizer_factory.dart';
import '../../../core/core_providers.dart';
import 'recitation_ai_config.dart';
import 'recitation_providers.dart';
import 'recitation_session_controller.dart';

/// Whether live recognition runs during a session at all: always on
/// Android and iOS (on the device, every build alike); on the web only in
/// development builds, whose engine sends audio to a cloud service — a
/// release must not (recitation stays on the device).
final liveRecognitionEnabledProvider = Provider<bool>((ref) {
  final capabilities = ref.watch(platformCapabilitiesProvider);
  return capabilities.isAndroid || capabilities.isIOS || !kReleaseMode;
});

/// Whether to show the recognition diagnostics panel: only in development
/// builds made with `--dart-define=TAHFEEZ_DEV_PANEL=true`.
final liveRecognitionDevPanelEnabledProvider = Provider<bool>(
  (ref) => !kReleaseMode && const bool.fromEnvironment('TAHFEEZ_DEV_PANEL'),
);

/// The recognition engine for this platform. The only place an engine is
/// chosen — everything else sees [LiveQuranRecognizer].
final liveQuranRecognizerFactoryProvider =
    Provider<LiveQuranRecognizer Function()>((ref) {
      final config = ref.watch(recitationAiConfigProvider);
      if (!config.speechRecognizerRuns) {
        // Following the reciter on the device: no Google / Web Speech.
        return () => UnavailableLiveRecognizer(
          config.offline
              ? 'Off: offline recitation'
              : 'Off: position from the on-device model',
        );
      }
      final capabilities = ref.watch(platformCapabilitiesProvider);
      if (capabilities.isAndroid) return AndroidSpeechLiveRecognizer.new;
      if (capabilities.isWeb) {
        return () => createWebSpeechRecognizer() ?? UnavailableLiveRecognizer();
      }
      return UnavailableLiveRecognizer.new;
    });

class LiveRecognitionState {
  const LiveRecognitionState({
    this.recognizerName = '',
    this.status = LiveRecognizerStatus.idle,
    this.statusDetail,
    this.latestPartial,
    this.latestFinal,
    this.firstPartialLatency,
    this.finalLatency,
    this.averageFirstPartialLatency,
    this.averageFinalLatency,
    this.partialCount = 0,
    this.finalCount = 0,
    this.lastError,
  });

  final String recognizerName;
  final LiveRecognizerStatus status;
  final String? statusDetail;
  final String? latestPartial;
  final String? latestFinal;

  /// Latest voice-onset → first partial.
  final Duration? firstPartialLatency;

  /// Latest voice-end → final transcript.
  final Duration? finalLatency;
  final Duration? averageFirstPartialLatency;
  final Duration? averageFinalLatency;
  final int partialCount;
  final int finalCount;
  final String? lastError;

  LiveRecognitionState copyWith({
    String? recognizerName,
    LiveRecognizerStatus? status,
    String? Function()? statusDetail,
    String? latestPartial,
    String? latestFinal,
    Duration? firstPartialLatency,
    Duration? finalLatency,
    Duration? averageFirstPartialLatency,
    Duration? averageFinalLatency,
    int? partialCount,
    int? finalCount,
    String? lastError,
  }) {
    return LiveRecognitionState(
      recognizerName: recognizerName ?? this.recognizerName,
      status: status ?? this.status,
      statusDetail: statusDetail == null ? this.statusDetail : statusDetail(),
      latestPartial: latestPartial ?? this.latestPartial,
      latestFinal: latestFinal ?? this.latestFinal,
      firstPartialLatency: firstPartialLatency ?? this.firstPartialLatency,
      finalLatency: finalLatency ?? this.finalLatency,
      averageFirstPartialLatency:
          averageFirstPartialLatency ?? this.averageFirstPartialLatency,
      averageFinalLatency: averageFinalLatency ?? this.averageFinalLatency,
      partialCount: partialCount ?? this.partialCount,
      finalCount: finalCount ?? this.finalCount,
      lastError: lastError ?? this.lastError,
    );
  }
}

/// Runs a [LiveQuranRecognizer] over the live recitation session: started
/// whenever the session is listening, stopped while it is paused or ended
/// (so a pause also finalizes the segment in progress). The R1 recording is
/// untouched — the recognizer only subscribes to the session's
/// `liveAudio` broadcast.
///
/// [events] re-publishes the engine's events for later consumers (Quran
/// alignment, mistake detection); the state is a diagnostics summary.
class LiveRecognitionController extends Notifier<LiveRecognitionState> {
  late LiveQuranRecognizer _recognizer;
  late DateTime Function() _clock;
  final _latency = RecognitionLatencyTracker();
  final _out = StreamController<LiveRecognitionEvent>.broadcast();
  StreamSubscription<LiveRecognitionEvent>? _engineEvents;
  StreamSubscription<Object?>? _audioTap;
  bool _running = false;
  bool _disposed = false;
  String? _sessionId;
  final _firstPartialSamples = <Duration>[];
  final _finalSamples = <Duration>[];

  Stream<LiveRecognitionEvent> get events => _out.stream;

  @override
  LiveRecognitionState build() {
    _recognizer = ref.read(liveQuranRecognizerFactoryProvider)();
    _clock = ref.read(recitationClockProvider);
    _engineEvents = _recognizer.events.listen(_onEngineEvent);
    ref.onDispose(_onDispose);
    ref.listen(
      recitationSessionControllerProvider,
      (_, next) => _onSession(next),
      fireImmediately: true,
    );
    return LiveRecognitionState(recognizerName: _recognizer.name);
  }

  void _onSession(RecitationSessionState session) {
    final listening = session.phase == RecitationPhase.listening;
    if (listening && !_running) {
      if (session.session?.id != _sessionId) {
        _sessionId = session.session?.id;
        _resetForNewSession();
      }
      unawaited(_start());
    } else if (!listening && _running) {
      unawaited(_stop());
    }
  }

  void _resetForNewSession() {
    _firstPartialSamples.clear();
    _finalSamples.clear();
    _latency.reset();
    state = LiveRecognitionState(
      recognizerName: _recognizer.name,
      status: state.status,
      statusDetail: state.statusDetail,
    );
  }

  Future<void> _start() async {
    _running = true;
    final session = ref.read(recitationSessionControllerProvider.notifier);
    final format = session.liveFormat;
    if (format == null) {
      _running = false;
      return;
    }
    if (_recognizer is! UnavailableLiveRecognizer) {
      ensureRecitationNetworkAllowed('the ${_recognizer.name} recognizer');
    }
    final availability = await _recognizer.checkAvailability();
    if (_disposed || !_running) return;
    if (!availability.available) {
      state = state.copyWith(
        status: LiveRecognizerStatus.unavailable,
        statusDetail: () => availability.detail,
      );
      return;
    }
    _latency.reset();
    _audioTap = session.liveAudio.listen(
      (chunk) => _latency.onAudio(chunk, _clock()),
    );
    try {
      await _recognizer.start(
        LiveAudioInput(
          sampleRate: format.sampleRate,
          channels: format.channels,
          audio: session.liveAudio,
        ),
      );
    } catch (e) {
      if (_disposed) return;
      state = state.copyWith(
        status: LiveRecognizerStatus.error,
        lastError: '$e',
        statusDetail: () => '$e',
      );
    }
  }

  Future<void> _stop() async {
    _running = false;
    await _audioTap?.cancel();
    _audioTap = null;
    try {
      await _recognizer.stop();
    } catch (_) {
      // Already stopped.
    }
  }

  void _onEngineEvent(LiveRecognitionEvent event) {
    if (_disposed) return;
    _out.add(event);
    final now = _clock();
    switch (event) {
      case LivePartialTranscript(:final text):
        final latency = _latency.onPartial(now);
        if (latency != null) _firstPartialSamples.add(latency);
        state = state.copyWith(
          latestPartial: text,
          partialCount: state.partialCount + 1,
          firstPartialLatency: latency,
          averageFirstPartialLatency: _average(_firstPartialSamples),
        );
      case LiveFinalTranscript(:final text):
        final latency = _latency.onFinal(now);
        if (latency != null) _finalSamples.add(latency);
        state = state.copyWith(
          latestFinal: text,
          finalCount: state.finalCount + 1,
          finalLatency: latency,
          averageFinalLatency: _average(_finalSamples),
        );
      case LiveRecognizerStatusChanged(:final status, :final detail):
        state = state.copyWith(status: status, statusDetail: () => detail);
      case LiveRecognitionError(:final message, :final recoverable):
        state = state.copyWith(
          lastError: message,
          status: recoverable ? null : LiveRecognizerStatus.error,
        );
    }
  }

  static Duration? _average(List<Duration> samples) {
    if (samples.isEmpty) return null;
    final total = samples.fold<int>(0, (sum, d) => sum + d.inMicroseconds);
    return Duration(microseconds: total ~/ samples.length);
  }

  void _onDispose() {
    _disposed = true;
    _running = false;
    final recognizer = _recognizer;
    unawaited(() async {
      await _audioTap?.cancel();
      await _engineEvents?.cancel();
      await recognizer.dispose();
      await _out.close();
    }());
  }
}

final liveRecognitionControllerProvider =
    NotifierProvider.autoDispose<
      LiveRecognitionController,
      LiveRecognitionState
    >(LiveRecognitionController.new);
