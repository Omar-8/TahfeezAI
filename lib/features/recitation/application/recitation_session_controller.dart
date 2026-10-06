import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../quran/domain/models/quran_location.dart';
import '../domain/recitation_audio_format.dart';
import '../domain/recitation_audio_source.dart';
import '../domain/recitation_recording_store.dart';
import '../domain/recitation_session.dart';
import 'recitation_providers.dart';

enum RecitationPhase {
  idle,

  /// Asking for permission / opening the microphone.
  starting,
  listening,

  /// The microphone is still open, but audio is neither recorded nor
  /// forwarded to [RecitationSessionController.liveAudio].
  paused,

  /// Closing the microphone and finishing the recording.
  stopping,
  permissionDenied,
  error,
}

class RecitationSessionState {
  const RecitationSessionState({
    this.phase = RecitationPhase.idle,
    this.session,
    this.elapsed = Duration.zero,
    this.lastCompleted,
    this.errorMessage,
  });

  final RecitationPhase phase;

  /// The running session, while [isActive].
  final RecitationSession? session;

  /// Audio actually captured so far — pauses excluded.
  final Duration elapsed;

  /// The most recent session this controller finished and saved.
  final RecitationSession? lastCompleted;

  final String? errorMessage;

  bool get isActive => switch (phase) {
    RecitationPhase.starting ||
    RecitationPhase.listening ||
    RecitationPhase.paused ||
    RecitationPhase.stopping => true,
    _ => false,
  };

  RecitationSessionState copyWith({RecitationPhase? phase, Duration? elapsed}) {
    return RecitationSessionState(
      phase: phase ?? this.phase,
      session: session,
      elapsed: elapsed ?? this.elapsed,
      lastCompleted: lastCompleted,
      errorMessage: errorMessage,
    );
  }
}

/// Runs one continuous live recitation session at a time: opens the
/// microphone once, keeps it open through pauses, records everything
/// captured while listening into a single recording, and republishes the
/// same PCM on [liveAudio] for a streaming recognizer.
///
/// The app shell's recitation bar keeps this provider alive while a
/// Mushaf is open or a session runs; if it is ever disposed mid-session,
/// the session is ended and saved rather than lost.
class RecitationSessionController extends Notifier<RecitationSessionState> {
  // Read once in [build]: the session may still be finishing after this
  // provider is disposed, when `ref` can no longer be used.
  late RecitationAudioSource Function() _sourceFactory;
  late RecitationRecordingStore _store;
  late RecitationSessionRepository _repository;
  late bool _keepRecordings;
  late DateTime Function() _clock;
  final _live = StreamController<Uint8List>.broadcast();

  // Created on first start, so merely showing the recitation bar never
  // touches the microphone plugin.
  RecitationAudioSource? _createdSource;
  RecitationAudioSource get _source => _createdSource ??= _sourceFactory();

  RecitationSessionState _state = const RecitationSessionState();
  RecitationAudioFormat? _format;
  RecitationRecordingSink? _sink;
  StreamSubscription<Uint8List>? _capture;
  int _recordedBytes = 0;
  bool _disposed = false;

  @override
  RecitationSessionState build() {
    _sourceFactory = ref.read(recitationAudioSourceFactoryProvider);
    _store = ref.read(recitationRecordingStoreProvider);
    _keepRecordings = ref.read(recitationKeepRecordingsProvider);
    _repository = ref.read(recitationSessionRepositoryProvider);
    _clock = ref.read(recitationClockProvider);
    ref.onDispose(_onDispose);
    return _state;
  }

  /// PCM16LE chunks captured while [RecitationPhase.listening], in
  /// [liveFormat]. Broadcast: subscribers only see audio from the moment
  /// they subscribe, and nothing is delivered while paused.
  ///
  /// This is the hook the next milestone's streaming recognizer consumes.
  Stream<Uint8List> get liveAudio => _live.stream;

  /// The format of [liveAudio] for the running session, if any.
  RecitationAudioFormat? get liveFormat => _format;

  void _emit(RecitationSessionState next) {
    _state = next;
    if (!_disposed) state = next;
  }

  Future<void> start({QuranLocation? startLocation}) async {
    if (_state.isActive) return;
    _emit(
      RecitationSessionState(
        phase: RecitationPhase.starting,
        lastCompleted: _state.lastCompleted,
      ),
    );

    try {
      final permission = await _source.checkPermission();
      if (_disposed) return;
      if (permission == MicrophonePermission.denied) {
        _emit(
          RecitationSessionState(
            phase: RecitationPhase.permissionDenied,
            lastCompleted: _state.lastCompleted,
          ),
        );
        return;
      }

      final capture = await _source.start(RecitationAudioFormat.speech);
      if (_disposed) {
        await _source.stop();
        return;
      }
      final startedAt = _clock();
      final session = RecitationSession(
        id: _newSessionId(startedAt),
        startedAt: startedAt,
        startLocation: startLocation,
      );
      _format = capture.format;
      _recordedBytes = 0;
      if (_keepRecordings) {
        _sink = await _store.open(
          sessionId: session.id,
          format: capture.format,
        );
      }
      if (_disposed) {
        await _source.stop();
        await _sink?.discard();
        return;
      }
      _capture = capture.audio.listen(
        _onChunk,
        onError: (Object error, StackTrace _) => _fail(error),
        // The platform closed the mic under us (e.g. revoked permission):
        // keep what was recorded.
        onDone: () {
          if (_state.isActive && _state.phase != RecitationPhase.stopping) {
            unawaited(stop());
          }
        },
      );
      _emit(
        RecitationSessionState(
          phase: RecitationPhase.listening,
          session: session,
          lastCompleted: _state.lastCompleted,
        ),
      );
    } catch (error) {
      await _fail(error);
    }
  }

  void pause() {
    if (_state.phase == RecitationPhase.listening) {
      _emit(_state.copyWith(phase: RecitationPhase.paused));
    }
  }

  void resume() {
    if (_state.phase == RecitationPhase.paused) {
      _emit(_state.copyWith(phase: RecitationPhase.listening));
    }
  }

  /// Ends the session (finishing and saving the recording when recordings
  /// are kept).
  Future<RecitationSession?> stop() async {
    if (_state.phase != RecitationPhase.listening &&
        _state.phase != RecitationPhase.paused) {
      return null;
    }
    _emit(_state.copyWith(phase: RecitationPhase.stopping));
    final completed = await _finish();
    _emit(
      RecitationSessionState(
        phase: completed == null ? RecitationPhase.error : RecitationPhase.idle,
        lastCompleted: completed ?? _state.lastCompleted,
        errorMessage: completed == null
            ? 'Could not save the recording.'
            : null,
      ),
    );
    return completed;
  }

  /// Clears a permission-denied/error state back to idle.
  void dismissError() {
    if (_state.phase == RecitationPhase.permissionDenied ||
        _state.phase == RecitationPhase.error) {
      _emit(RecitationSessionState(lastCompleted: _state.lastCompleted));
    }
  }

  void _onChunk(Uint8List chunk) {
    if (_state.phase != RecitationPhase.listening) return;
    _sink?.add(chunk);
    _recordedBytes += chunk.length;
    if (_live.hasListener) _live.add(chunk);
    final elapsed = _format!.durationOf(_recordedBytes);
    // The UI timer shows whole seconds; don't rebuild for every ~100 ms
    // chunk.
    if (elapsed.inSeconds != _state.elapsed.inSeconds) {
      _emit(_state.copyWith(elapsed: elapsed));
    }
  }

  /// Closes the mic and the recording and saves the session. Returns
  /// `null` if saving failed.
  Future<RecitationSession?> _finish() async {
    final session = _state.session;
    final sink = _sink;
    final format = _format;
    _sink = null;
    try {
      await _source.stop();
    } catch (_) {
      // Already closed — nothing to release.
    }
    await _capture?.cancel();
    _capture = null;
    if (session == null || format == null) return null;
    final completed = session.copyWith(
      endedAt: _clock(),
      duration: format.durationOf(_recordedBytes),
    );
    // Not keeping recordings: nothing to write or save.
    if (sink == null) return completed;

    try {
      String? reference;
      if (_recordedBytes == 0) {
        await sink.discard();
      } else {
        reference = await sink.close();
      }
      final saved = completed.copyWith(recordingReference: reference);
      await _repository.save(saved);
      return saved;
    } catch (_) {
      return null;
    }
  }

  Future<void> _fail(Object error) async {
    if (!kReleaseMode) debugPrint('Recitation session failed: $error');
    final hadSession = _state.session != null;
    if (hadSession) {
      await _finish();
    } else {
      try {
        await _source.stop();
      } catch (_) {}
    }
    _emit(
      RecitationSessionState(
        phase: RecitationPhase.error,
        lastCompleted: _state.lastCompleted,
        errorMessage: 'The microphone is unavailable.',
      ),
    );
  }

  void _onDispose() {
    _disposed = true;
    final running =
        _state.phase == RecitationPhase.listening ||
        _state.phase == RecitationPhase.paused;
    unawaited(() async {
      if (running) await _finish();
      await _live.close();
      await _createdSource?.dispose();
    }());
  }

  static final _random = Random();

  static String _newSessionId(DateTime startedAt) {
    final time = startedAt.toUtc().microsecondsSinceEpoch.toRadixString(36);
    // Not `1 << 32`: on the web that shift wraps to 0 and nextInt throws.
    final salt = _random.nextInt(0x7fffffff).toRadixString(36).padLeft(6, '0');
    return 'rs-$time-$salt';
  }
}

final recitationSessionControllerProvider =
    NotifierProvider.autoDispose<
      RecitationSessionController,
      RecitationSessionState
    >(RecitationSessionController.new);
