import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tahfeez_ai/features/recitation/application/recitation_providers.dart';
import 'package:tahfeez_ai/features/recitation/application/recitation_session_controller.dart';
import 'package:tahfeez_ai/features/recitation/domain/recitation_audio_format.dart';
import 'package:tahfeez_ai/features/recitation/domain/recitation_audio_source.dart';
import 'package:tahfeez_ai/features/recitation/domain/recitation_recording_store.dart';
import 'package:tahfeez_ai/features/recitation/domain/recitation_session.dart';
import 'package:tahfeez_ai/quran/domain/models/quran_location.dart';

class FakeAudioSource implements RecitationAudioSource {
  FakeAudioSource({this.permission = MicrophonePermission.granted});

  MicrophonePermission permission;
  StreamController<Uint8List>? mic;
  int startCalls = 0;
  int stopCalls = 0;
  bool disposed = false;

  bool get micOpen => mic != null && !mic!.isClosed;

  @override
  Future<MicrophonePermission> checkPermission({bool request = true}) async =>
      permission;

  @override
  Future<RecitationAudioCapture> start(RecitationAudioFormat requested) async {
    startCalls++;
    mic = StreamController<Uint8List>();
    return RecitationAudioCapture(format: requested, audio: mic!.stream);
  }

  /// One second of 16 kHz mono PCM16 = 32000 bytes.
  void emitSeconds(double seconds, {int value = 1}) {
    final bytes = (RecitationAudioFormat.speech.bytesPerSecond * seconds)
        .round();
    mic!.add(Uint8List(bytes)..fillRange(0, bytes, value));
  }

  @override
  Future<void> stop() async {
    stopCalls++;
    await mic?.close();
  }

  @override
  Future<void> dispose() async => disposed = true;
}

class FakeSink implements RecitationRecordingSink {
  final bytes = BytesBuilder();
  bool closed = false;
  bool discarded = false;

  @override
  void add(Uint8List chunk) => bytes.add(chunk);

  @override
  Future<String?> close() async {
    closed = true;
    return 'fake://recording';
  }

  @override
  Future<void> discard() async => discarded = true;
}

class FakeStore implements RecitationRecordingStore {
  final sinks = <String, FakeSink>{};

  @override
  Future<RecitationRecordingSink> open({
    required String sessionId,
    required RecitationAudioFormat format,
  }) async => sinks[sessionId] = FakeSink();
}

class FakeRepository implements RecitationSessionRepository {
  final saved = <RecitationSession>[];

  @override
  Future<List<RecitationSession>> list() async => saved.reversed.toList();

  @override
  Future<void> save(RecitationSession session) async => saved.add(session);
}

void main() {
  late FakeAudioSource source;
  late FakeStore store;
  late FakeRepository repository;
  late ProviderContainer container;
  late ProviderSubscription<RecitationSessionState> keepAlive;
  var now = DateTime.utc(2026, 9, 27, 10);

  RecitationSessionController controller() =>
      container.read(recitationSessionControllerProvider.notifier);
  RecitationSessionState state() =>
      container.read(recitationSessionControllerProvider);

  setUp(() {
    source = FakeAudioSource();
    store = FakeStore();
    repository = FakeRepository();
    now = DateTime.utc(2026, 9, 27, 10);
    container = ProviderContainer(
      overrides: [
        recitationAudioSourceFactoryProvider.overrideWithValue(() => source),
        recitationRecordingStoreProvider.overrideWithValue(store),
        recitationSessionRepositoryProvider.overrideWithValue(repository),
        recitationKeepRecordingsProvider.overrideWithValue(true),
        recitationClockProvider.overrideWithValue(() => now),
      ],
    );
    keepAlive = container.listen(
      recitationSessionControllerProvider,
      (_, _) {},
    );
  });

  tearDown(() => container.dispose());

  const startPage = QuranLocation.page(1, 42);

  test('start → listening with a session anchored at the start page', () async {
    await controller().start(startLocation: startPage);

    expect(state().phase, RecitationPhase.listening);
    expect(state().session!.startLocation, startPage);
    expect(state().session!.startedAt, now);
    expect(source.micOpen, isTrue);
  });

  test('permission denied never opens the microphone', () async {
    source.permission = MicrophonePermission.denied;

    await controller().start(startLocation: startPage);

    expect(state().phase, RecitationPhase.permissionDenied);
    expect(source.startCalls, 0);
    controller().dismissError();
    expect(state().phase, RecitationPhase.idle);
  });

  test('pause keeps the mic open but drops audio from recording and live '
      'stream; resume picks up again', () async {
    await controller().start(startLocation: startPage);
    final live = <int>[];
    controller().liveAudio.listen((chunk) => live.add(chunk.length));

    source.emitSeconds(2);
    await pumpEventQueue();
    controller().pause();
    source.emitSeconds(5, value: 9);
    await pumpEventQueue();

    expect(state().phase, RecitationPhase.paused);
    expect(source.micOpen, isTrue, reason: 'mic stays open while paused');
    expect(source.startCalls, 1);
    expect(state().elapsed, const Duration(seconds: 2));

    controller().resume();
    source.emitSeconds(1);
    await pumpEventQueue();

    expect(state().phase, RecitationPhase.listening);
    expect(state().elapsed, const Duration(seconds: 3));
    expect(live, [64000, 32000]);
    final recorded = store.sinks.values.single.bytes.toBytes();
    expect(recorded.length, 96000);
    expect(recorded.contains(9), isFalse);
  });

  test('stop closes the mic, finishes one recording and saves the '
      'session', () async {
    await controller().start(startLocation: startPage);
    source.emitSeconds(1.5);
    await pumpEventQueue();
    now = now.add(const Duration(minutes: 1));

    final session = await controller().stop();

    expect(source.micOpen, isFalse);
    expect(store.sinks.values.single.closed, isTrue);
    expect(state().phase, RecitationPhase.idle);
    expect(state().lastCompleted, session);
    expect(repository.saved.single.id, session!.id);
    expect(session.endedAt, now);
    expect(session.duration, const Duration(milliseconds: 1500));
    expect(session.recordingReference, 'fake://recording');
    expect(session.startLocation, startPage);
  });

  test('a session with no captured audio discards its recording', () async {
    await controller().start(startLocation: startPage);

    final session = await controller().stop();

    expect(store.sinks.values.single.discarded, isTrue);
    expect(session!.recordingReference, isNull);
    expect(session.duration, Duration.zero);
  });

  test('disposing mid-session saves it and releases the mic', () async {
    await controller().start(startLocation: startPage);
    source.emitSeconds(1);
    await pumpEventQueue();

    keepAlive.close();
    container.dispose();
    await pumpEventQueue();

    expect(source.micOpen, isFalse);
    expect(source.disposed, isTrue);
    expect(repository.saved.single.duration, const Duration(seconds: 1));
  });

  test('a mic error ends the session but keeps what was recorded', () async {
    await controller().start(startLocation: startPage);
    source.emitSeconds(1);
    await pumpEventQueue();

    source.mic!.addError(StateError('device lost'));
    await pumpEventQueue();

    expect(state().phase, RecitationPhase.error);
    expect(repository.saved.single.duration, const Duration(seconds: 1));
  });
}
