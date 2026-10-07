import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../ai/acoustic/acoustic_frame_stream.dart';
import '../../../ai/acoustic/acoustic_model_manifest.dart';
import '../../../ai/acoustic/local_quran_acoustic_model.dart';
import '../../../ai/acoustic/pause_detector.dart';
import '../../../ai/acoustic/pcm_ring.dart';
import '../../../ai/acoustic/quran_acoustic_model.dart';
import '../../../ai/acoustic/screen_awake.dart';
import '../../../ai/matching/local_quran_position_tracker.dart'
    show WordPlacement;
import 'recitation_ai_config.dart';
import 'recitation_session_controller.dart';

/// The on-device model, loaded once per app run and reused.
/// `TAHFEEZ_ACOUSTIC_PROVIDER` = `cpu` (default) | `xnnpack` | `nnapi`;
/// `TAHFEEZ_ACOUSTIC_THREADS` = intra-op threads (0: ONNX Runtime's
/// choice).
final localQuranAcousticModelProvider = Provider<LocalQuranAcousticModel>((
  ref,
) {
  const provider = String.fromEnvironment(
    'TAHFEEZ_ACOUSTIC_PROVIDER',
    defaultValue: 'cpu',
  );
  final model = LocalQuranAcousticModel(
    provider: AcousticExecutionProvider.values.byName(provider),
    threads: const int.fromEnvironment('TAHFEEZ_ACOUSTIC_THREADS'),
  );
  ref.onDispose(() => unawaited(model.dispose()));
  return model;
});

/// Keeps the screen on while the pipeline listens; overridden in tests.
final screenAwakeProvider = Provider<ScreenAwake>((ref) => const ScreenAwake());

/// How to cut the live stream into model runs.
///
/// 0.4 s hop with 0.25 s of context each side: on recorded recitation (v2.5
/// model, short-context trained; `test/fixtures` scenarios) words are placed
/// ~0.57 s after they end (median), as accurately as at 0.5 s / 0.3 s
/// (~0.70 s) for about the same model work. (v2.3 needed 1 s / 0.5 s: shorter
/// hops misplaced words.) `TAHFEEZ_ACOUSTIC_HOP_MS` /
/// `TAHFEEZ_ACOUSTIC_CONTEXT_MS` override it for measurements.
final acousticWindowingProvider = Provider<AcousticWindowing>(
  (ref) => const AcousticWindowing(
    minHop: Duration(
      milliseconds: int.fromEnvironment(
        'TAHFEEZ_ACOUSTIC_HOP_MS',
        defaultValue: 400,
      ),
    ),
    maxHop: Duration(seconds: 4),
    context: Duration(
      milliseconds: int.fromEnvironment(
        'TAHFEEZ_ACOUSTIC_CONTEXT_MS',
        defaultValue: 250,
      ),
    ),
  ),
);

class LocalAcousticInferenceState {
  const LocalAcousticInferenceState({
    this.model,
    this.load,
    this.loading = false,
    this.active = false,
    this.windows = 0,
    this.audioSeconds = 0,
    this.modelSeconds = 0,
    this.lastWindow,
    this.lastRun,
    this.lag = Duration.zero,
    this.droppedSeconds = 0,
    this.followLatency,
    this.locateLatency,
    this.device,
    this.peakPssKb,
    this.error,
  });

  final LocalAcousticModelStatus? model;
  final AcousticModelLoad? load;
  final bool loading;

  /// Listening to a session.
  final bool active;

  /// Model runs so far, the audio they kept, and the time they took.
  final int windows;
  final double audioSeconds, modelSeconds;

  /// The last run: its window length and how long it took.
  final Duration? lastWindow, lastRun;

  /// Audio received but not yet turned into frames.
  final Duration lag;

  /// Audio skipped because the model fell too far behind.
  final double droppedSeconds;

  /// From a word's last sound being received to the tracker placing it;
  /// from the first speech to the reciter being located.
  final Duration? followLatency, locateLatency;
  final AcousticDeviceStats? device;
  final int? peakPssKb;
  final String? error;

  /// Real-time factor of the model runs (model time / audio kept).
  double? get rtf => audioSeconds == 0 ? null : modelSeconds / audioSeconds;

  bool get ready => model?.usable == true && error == null;

  LocalAcousticInferenceState copyWith({
    LocalAcousticModelStatus? model,
    AcousticModelLoad? load,
    bool? loading,
    bool? active,
    int? windows,
    double? audioSeconds,
    double? modelSeconds,
    Duration? lastWindow,
    Duration? lastRun,
    Duration? lag,
    double? droppedSeconds,
    Duration? followLatency,
    Duration? locateLatency,
    AcousticDeviceStats? device,
    int? peakPssKb,
    String? Function()? error,
  }) => LocalAcousticInferenceState(
    model: model ?? this.model,
    load: load ?? this.load,
    loading: loading ?? this.loading,
    active: active ?? this.active,
    windows: windows ?? this.windows,
    audioSeconds: audioSeconds ?? this.audioSeconds,
    modelSeconds: modelSeconds ?? this.modelSeconds,
    lastWindow: lastWindow ?? this.lastWindow,
    lastRun: lastRun ?? this.lastRun,
    lag: lag ?? this.lag,
    droppedSeconds: droppedSeconds ?? this.droppedSeconds,
    followLatency: followLatency ?? this.followLatency,
    locateLatency: locateLatency ?? this.locateLatency,
    device: device ?? this.device,
    peakPssKb: peakPssKb ?? this.peakPssKb,
    error: error == null ? this.error : error(),
  );
}

/// The single on-device inference pipeline: the session's one microphone
/// stream ([RecitationSessionController.liveAudio]) in, timestamped
/// acoustic frames out — computed once, used by every consumer (the
/// position tracker follows them; the verifier checks the same frames).
///
/// Audio goes into a bounded ring ([PcmRing], 90 s); windows are cut by
/// [AcousticWindowing] (≥ 2 s new audio, ≤ 6 s, 1 s context each side) and
/// run one at a time; each window's middle frames are kept in a bounded
/// [AcousticFrameStore] (90 s) and published on [frames]. When the reciter
/// pauses or stops, the tail is computed at once ([TimedAcousticFrames.last]).
/// Nothing leaves the device.
class LocalAcousticInferenceController
    extends Notifier<LocalAcousticInferenceState> {
  LocalQuranAcousticModel? _model;
  AcousticWindowing _windowing = const AcousticWindowing();
  ScreenAwake _screen = const ScreenAwake();
  final pcm = PcmRing();
  late final store = AcousticFrameStore(
    classes: 43,
    frameDuration: const Duration(milliseconds: 40),
  );
  final _out = StreamController<TimedAcousticFrames>.broadcast();
  StreamSubscription<Uint8List>? _audio;
  final _progress = StreamController<int>.broadcast();
  String? _sessionId;
  int _generation = 0;
  bool _busy = false;
  bool _flushPending = false;

  /// The reciter stopped (a pause in the audio) at this stream sample:
  /// compute up to it at once, as for a paused session, but keep listening.
  /// Only up to it — the microphone goes on delivering audio while the
  /// model runs, and flushing that too would chase the live edge with tiny
  /// windows that have no context.
  int? _pauseAt;
  PauseDetector _pauses = PauseDetector();

  /// A streaming model (its manifest's `stream`): the next chunk's first
  /// stream sample, and whether the model's state must start afresh first
  /// (a new session, or audio lost behind the ring).
  int _streamNext = 0;
  bool _streamFresh = true;

  /// When each received piece of audio arrived: (end sample, time).
  final _arrivals = <(int, DateTime)>[];
  int? _firstSpeechFrame;
  Timer? _statsTimer;

  /// Frames as they are computed (deduplicated, in stream order).
  Stream<TimedAcousticFrames> get frames => _out.stream;

  final _placed =
      StreamController<({List<WordPlacement> words, bool paused})>.broadcast();

  /// Words the position tracker placed, with their frames; [paused]: the
  /// audio paused after them. The verifier checks each ayah on exactly
  /// these frames.
  Stream<({List<WordPlacement> words, bool paused})> get placements =>
      _placed.stream;

  void recordPlacements(List<WordPlacement> words, {bool paused = false}) =>
      _placed.add((words: words, paused: paused));

  /// The sample count, after each piece of audio received.
  Stream<int> get progress => _progress.stream;

  /// Frames done (all before it are in [store]).
  int get done => store.end;

  @override
  LocalAcousticInferenceState build() {
    final config = ref.watch(recitationAiConfigProvider);
    _windowing = ref.watch(acousticWindowingProvider);
    _screen = ref.watch(screenAwakeProvider);
    ref.onDispose(_stop);
    if (config.acoustic != QuranAcousticBackend.local) {
      return const LocalAcousticInferenceState();
    }
    _model = ref.watch(localQuranAcousticModelProvider);
    ref.listen(
      recitationSessionControllerProvider,
      (_, next) => _onSession(next),
      fireImmediately: true,
    );
    // Warm up: find and load the model before the first recitation.
    unawaited(Future.microtask(_prepare));
    return const LocalAcousticInferenceState();
  }

  Future<void> _prepare() async {
    final model = _model;
    if (model == null || !ref.mounted) return;
    final status = await model.status();
    if (!ref.mounted) return;
    state = state.copyWith(model: status, loading: status.usable);
    if (!status.usable) return;
    try {
      final load = await model.load();
      if (!ref.mounted) return;
      state = state.copyWith(
        load: load,
        loading: false,
        model: await model.status(),
        error: () => null,
      );
      unawaited(_pump());
    } catch (e) {
      if (ref.mounted) {
        state = state.copyWith(loading: false, error: () => 'Model: $e');
      }
    }
  }

  void _onSession(RecitationSessionState session) {
    final listening = session.phase == RecitationPhase.listening;
    final id = session.session?.id;
    if (listening && _audio == null) {
      if (id != _sessionId) {
        _sessionId = id;
        _generation++;
        pcm.reset();
        store.reset();
        _streamNext = 0;
        _streamFresh = true;
        _arrivals.clear();
        _firstSpeechFrame = null;
        state = LocalAcousticInferenceState(
          model: state.model,
          load: state.load,
          loading: state.loading,
          active: true,
          error: state.error,
        );
      }
      _start();
    } else if (!listening && _audio != null) {
      _stop();
      // Paused or stopped: compute the tail now.
      _flushPending = true;
      unawaited(_pump());
      if (!session.isActive) state = state.copyWith(active: false);
    }
  }

  void _start() {
    final session = ref.read(recitationSessionControllerProvider.notifier);
    final format = session.liveFormat;
    if (format == null || format.sampleRate != 16000 || format.channels != 1) {
      state = state.copyWith(error: () => 'Needs 16 kHz mono audio');
      return;
    }
    _pauses = PauseDetector();
    _pauseAt = null;
    _audio = session.liveAudio.listen((chunk) {
      pcm.addPcm16(chunk);
      final n = chunk.length ~/ 2;
      if (_pauses.add(pcm.samples(pcm.written - n, pcm.written))) {
        _pauseAt = pcm.written;
      }
      _arrivals.add((pcm.written, DateTime.now()));
      if (_arrivals.length > 2000) _arrivals.removeRange(0, 1000);
      _progress.add(pcm.written);
      unawaited(_pump());
    });
    _statsTimer ??= Timer.periodic(
      const Duration(seconds: 10),
      (_) => unawaited(_sampleDevice()),
    );
    unawaited(_screen.keepOn(true));
    state = state.copyWith(active: true);
  }

  void _stop() {
    if (_audio != null) {
      unawaited(_screen.keepOn(false));
    }
    unawaited(_audio?.cancel());
    _audio = null;
    _statsTimer?.cancel();
    _statsTimer = null;
  }

  /// Runs windows while there is audio for one; one at a time.
  Future<void> _pump() async {
    final model = _model;
    if (_busy || model == null || state.load == null) return;
    _busy = true;
    final generation = _generation;
    try {
      final stream = model.stream;
      if (stream != null) {
        await _pumpStream(model, stream, generation);
        return;
      }
      while (ref.mounted && generation == _generation) {
        final pauseAt = _pauseAt;
        final flush = _flushPending || pauseAt != null;
        // A pause flushes only the audio heard before it.
        final written = _flushPending || pauseAt == null
            ? pcm.written
            : math.min(pauseAt, pcm.written);
        final window = _windowing.next(
          written: written,
          done: store.end,
          flush: flush,
          oldest: pcm.oldest,
        );
        if (window == null) {
          if (flush) {
            _flushPending = false;
            _pauseAt = null;
            // Mark the pause for consumers, even if no frames were left.
            final end = store.end;
            final tail = store.slice(math.max(store.start, end - 1), end);
            if (tail != null) {
              _out.add(
                TimedAcousticFrames(tail.start, tail.frames, last: true),
              );
            }
          }
          break;
        }
        if (window.keepFrom > store.end) {
          // The ring no longer holds what was missed: skip it.
          final skipped = window.keepFrom - store.end;
          state = state.copyWith(
            droppedSeconds: state.droppedSeconds + skipped * 0.04,
          );
          store.add(
            TimedAcousticFrames(
              store.end,
              _silence(skipped, model.info.frameDuration),
            ),
          );
        }
        final samples = pcm.samples(window.from, window.to);
        final started = DateTime.now();
        final AcousticFrames out;
        try {
          out = await model.run(samples);
        } catch (e) {
          if (ref.mounted) state = state.copyWith(error: () => 'Model: $e');
          break;
        }
        if (!ref.mounted || generation != _generation) break;
        final took = DateTime.now().difference(started);
        final offset = window.from ~/ _windowing.samplesPerFrame;
        final keepTo = math.min(window.keepTo, offset + out.frames);
        if (keepTo <= window.keepFrom) break;
        final kept = out.slice(window.keepFrom - offset, keepTo - offset - 1);
        final added = store.add(TimedAcousticFrames(window.keepFrom, kept));
        final lastOne =
            flush &&
            _windowing.next(
                  written: written,
                  done: store.end,
                  flush: true,
                  oldest: pcm.oldest,
                ) ==
                null;
        if (lastOne) {
          _flushPending = false;
          _pauseAt = null;
        }
        if (added != null) {
          _noteSpeech(added);
          _out.add(
            TimedAcousticFrames(added.start, added.frames, last: lastOne),
          );
        }
        state = state.copyWith(
          windows: state.windows + 1,
          audioSeconds: state.audioSeconds + kept.frames * 0.04,
          modelSeconds: state.modelSeconds + took.inMicroseconds / 1e6,
          lastWindow: Duration(
            milliseconds: (window.to - window.from) * 1000 ~/ 16000,
          ),
          lastRun: took,
          lag: Duration(
            milliseconds:
                (pcm.written - store.end * _windowing.samplesPerFrame) *
                1000 ~/
                16000,
          ),
          error: () => null,
        );
        if (lastOne) break;
      }
    } finally {
      _busy = false;
    }
  }

  /// A streaming model: each chunk of audio once, as soon as it (and the
  /// little audio after it the model needs) has arrived; its frames are
  /// final. A pause in the recitation needs nothing special — the
  /// microphone goes on, so the chunk holding the pause completes within a
  /// chunk's time, and is marked [TimedAcousticFrames.last]. When the
  /// session itself pauses or stops mid-chunk, that partial chunk is
  /// computed provisionally (padded with silence, the model's state kept),
  /// and replaced by its final frames if the recitation resumes.
  Future<void> _pumpStream(
    LocalQuranAcousticModel model,
    AcousticStreamConfig config,
    int generation,
  ) async {
    final spf = _windowing.samplesPerFrame;
    final need = config.chunkSamples + config.overlapSamples;
    while (ref.mounted && generation == _generation) {
      final flush = _flushPending;
      final written = pcm.written;
      if (_streamNext < pcm.oldest) {
        // Fell behind the ring: skip what it no longer holds, afresh.
        final resume = (pcm.oldest + spf - 1) ~/ spf * spf;
        final skipped = resume ~/ spf - store.end;
        if (skipped > 0) {
          store.add(
            TimedAcousticFrames(
              store.end,
              _silence(skipped, model.info.frameDuration),
            ),
          );
          state = state.copyWith(
            droppedSeconds: state.droppedSeconds + skipped * 0.04,
          );
        }
        _streamNext = resume;
        _streamFresh = true;
      }
      final full = written >= _streamNext + need;
      if (!full && !(flush && written - _streamNext >= spf)) {
        if (flush) {
          _flushPending = false;
          _markPause();
        }
        break;
      }
      if (_streamFresh) {
        // Only now, with a chunk to run: a model loaded before the session
        // is not reset twice.
        await model.streamReset();
        _streamFresh = false;
        if (!ref.mounted || generation != _generation) break;
      }
      final take = full ? need : written - _streamNext;
      final samples = Float32List(need)
        ..setAll(0, pcm.samples(_streamNext, _streamNext + take));
      final started = DateTime.now();
      final AcousticFrames out;
      try {
        out = await model.streamRun(samples, commit: full);
      } catch (e) {
        if (ref.mounted) state = state.copyWith(error: () => 'Model: $e');
        break;
      }
      if (!ref.mounted || generation != _generation) break;
      final took = DateTime.now().difference(started);
      final first = _streamNext ~/ spf;
      // A provisional chunk keeps only the frames its real audio reached.
      final keep = full ? out.frames : math.min(out.frames, take ~/ spf);
      if (keep <= 0) break;
      final added = store.put(
        TimedAcousticFrames(first, out.slice(0, keep - 1)),
      );
      if (full) _streamNext += config.chunkSamples;
      final pauseAt = _pauseAt;
      final paused = pauseAt != null && (first + keep) * spf >= pauseAt;
      if (paused) _pauseAt = null;
      if (!full) _flushPending = false;
      _noteSpeech(added);
      _out.add(
        TimedAcousticFrames(added.start, added.frames, last: !full || paused),
      );
      state = state.copyWith(
        windows: state.windows + 1,
        audioSeconds: state.audioSeconds + keep * 0.04,
        modelSeconds: state.modelSeconds + took.inMicroseconds / 1e6,
        lastWindow: Duration(milliseconds: take * 1000 ~/ 16000),
        lastRun: took,
        lag: Duration(
          milliseconds: (pcm.written - store.end * spf) * 1000 ~/ 16000,
        ),
        error: () => null,
      );
      if (!full) break;
    }
  }

  /// Marks a pause for the consumers, even if no frames were left.
  void _markPause() {
    final end = store.end;
    final tail = store.slice(math.max(store.start, end - 1), end);
    if (tail != null) {
      _out.add(TimedAcousticFrames(tail.start, tail.frames, last: true));
    }
  }

  static AcousticFrames _silence(int frames, Duration frameDuration) {
    final logProbs = Float32List(frames * 43)..fillRange(0, frames * 43, -30);
    for (var f = 0; f < frames; f++) {
      logProbs[f * 43] = 0; // blank
    }
    return AcousticFrames(
      frames: frames,
      classes: 43,
      logProbs: logProbs,
      frameDuration: frameDuration,
    );
  }

  void _noteSpeech(TimedAcousticFrames chunk) {
    if (_firstSpeechFrame != null) return;
    final f = chunk.frames;
    for (var i = 0; i < f.frames; i++) {
      var best = 0;
      for (var c = 1; c < f.classes; c++) {
        if (f.at(i, c) > f.at(i, best)) best = c;
      }
      if (best != 0) {
        _firstSpeechFrame = chunk.start + i;
        return;
      }
    }
  }

  /// When the audio of stream frame [frame] had been received.
  DateTime? receivedAt(int frame) {
    final sample = (frame + 1) * _windowing.samplesPerFrame;
    for (final (end, at) in _arrivals) {
      if (end >= sample) return at;
    }
    return null;
  }

  /// Frames for samples [from]..[to] — the verifier reuses what the
  /// tracker already followed instead of running the model again. Waits
  /// (up to [timeout]) for frames not computed yet; `null` if they were
  /// dropped.
  Future<TimedAcousticFrames?> framesFor(
    int from,
    int to, {
    Duration timeout = const Duration(seconds: 30),
  }) async {
    final spf = _windowing.samplesPerFrame;
    final first = (from + spf - 1) ~/ spf;
    final last = to ~/ spf;
    if (last <= first) return null;
    final deadline = DateTime.now().add(timeout);
    while (store.end < last) {
      if (DateTime.now().isAfter(deadline) || !ref.mounted) return null;
      try {
        await frames.first.timeout(deadline.difference(DateTime.now()));
      } on TimeoutException {
        return null;
      }
    }
    return store.slice(first, last);
  }

  /// The tracker placed a word ending at stream frame [frame].
  void recordFollow(int frame) {
    final at = receivedAt(frame);
    if (at == null) return;
    state = state.copyWith(followLatency: DateTime.now().difference(at));
  }

  /// The tracker located the reciter.
  void recordLocated() {
    final first = _firstSpeechFrame;
    final at = first == null ? null : receivedAt(first);
    if (at == null) return;
    state = state.copyWith(locateLatency: DateTime.now().difference(at));
  }

  Future<void> _sampleDevice() async {
    final stats = await _model?.deviceStats();
    if (stats == null || !ref.mounted) return;
    state = state.copyWith(
      device: stats,
      peakPssKb: math.max(state.peakPssKb ?? 0, stats.pssKb ?? 0),
    );
    if (!kReleaseMode) {
      debugPrint(
        'Acoustic device: pss ${stats.pssKb} kB, cpu ${stats.cpuTime}, '
        'battery ${stats.batteryPercent}% ${stats.batteryMicroAmps} µA '
        '${stats.batteryCelsius} °C, rtf ${state.rtf?.toStringAsFixed(2)}, '
        'lag ${state.lag.inMilliseconds} ms',
      );
    }
  }
}

final localAcousticInferenceControllerProvider =
    NotifierProvider.autoDispose<
      LocalAcousticInferenceController,
      LocalAcousticInferenceState
    >(LocalAcousticInferenceController.new);
