import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tahfeez_ai/ai/speech/live_quran_recognizer.dart';
import 'package:tahfeez_ai/features/recitation/application/live_recognition_controller.dart';
import 'package:tahfeez_ai/features/recitation/application/recitation_providers.dart';
import 'package:tahfeez_ai/features/recitation/application/recitation_session_controller.dart';
import 'package:tahfeez_ai/quran/domain/models/quran_location.dart';

import 'recitation_session_controller_test.dart'
    show FakeAudioSource, FakeRepository, FakeStore;

class FakeRecognizer implements LiveQuranRecognizer {
  final events_ = StreamController<LiveRecognitionEvent>.broadcast();
  final inputs = <LiveAudioInput>[];
  final received = <int>[];
  int stops = 0;
  bool disposed = false;
  bool available = true;

  @override
  String get name => 'Fake';

  @override
  Stream<LiveRecognitionEvent> get events => events_.stream;

  @override
  Future<LiveRecognizerAvailability> checkAvailability() async =>
      LiveRecognizerAvailability(available: available, detail: 'fake');

  @override
  Future<void> start(LiveAudioInput input) async {
    inputs.add(input);
    input.audio.listen((c) => received.add(c.length));
    events_.add(
      const LiveRecognizerStatusChanged(LiveRecognizerStatus.listening),
    );
  }

  @override
  Future<void> stop() async => stops++;

  @override
  Future<void> dispose() async => disposed = true;
}

void main() {
  late FakeAudioSource source;
  late FakeRecognizer recognizer;
  late ProviderContainer container;
  var now = DateTime.utc(2026);

  RecitationSessionController session() =>
      container.read(recitationSessionControllerProvider.notifier);
  LiveRecognitionState state() =>
      container.read(liveRecognitionControllerProvider);

  setUp(() {
    source = FakeAudioSource();
    recognizer = FakeRecognizer();
    now = DateTime.utc(2026);
    container = ProviderContainer(
      overrides: [
        recitationAudioSourceFactoryProvider.overrideWithValue(() => source),
        recitationRecordingStoreProvider.overrideWithValue(FakeStore()),
        recitationSessionRepositoryProvider.overrideWithValue(FakeRepository()),
        recitationClockProvider.overrideWithValue(() => now),
        liveQuranRecognizerFactoryProvider.overrideWithValue(() => recognizer),
      ],
    );
    container.listen(liveRecognitionControllerProvider, (_, _) {});
  });

  tearDown(() => container.dispose());

  test('recognizes only while the session is listening', () async {
    expect(state().recognizerName, 'Fake');
    expect(recognizer.inputs, isEmpty);

    await session().start(startLocation: const QuranLocation.page(1, 42));
    await pumpEventQueue();
    expect(recognizer.inputs, hasLength(1));
    expect(recognizer.inputs.single.sampleRate, 16000);
    expect(state().status, LiveRecognizerStatus.listening);

    source.emitSeconds(0.1);
    await pumpEventQueue();
    expect(recognizer.received, [3200]);

    session().pause();
    await pumpEventQueue();
    expect(recognizer.stops, 1);
    source.emitSeconds(0.1);
    await pumpEventQueue();
    expect(recognizer.received, [3200], reason: 'paused audio is not fed');

    session().resume();
    await pumpEventQueue();
    expect(recognizer.inputs, hasLength(2));

    await session().stop();
    await pumpEventQueue();
    expect(recognizer.stops, 2);
  });

  test('tracks latest transcripts and latency', () async {
    await session().start(startLocation: const QuranLocation.page(1, 42));
    await pumpEventQueue();

    // Silence, then voice at t=1s.
    source.emitSeconds(0.1, value: 0);
    await pumpEventQueue();
    now = now.add(const Duration(seconds: 1));
    source.emitSeconds(0.1, value: 90);
    await pumpEventQueue();

    now = now.add(const Duration(milliseconds: 800));
    recognizer.events_.add(const LivePartialTranscript('الله'));
    await pumpEventQueue();
    expect(state().latestPartial, 'الله');
    expect(state().firstPartialLatency, const Duration(milliseconds: 800));

    recognizer.events_.add(const LivePartialTranscript('الله لا'));
    recognizer.events_.add(const LiveFinalTranscript('الله لا اله'));
    recognizer.events_.add(const LiveRecognitionError('network error'));
    await pumpEventQueue();
    expect(state().latestPartial, 'الله لا');
    expect(state().latestFinal, 'الله لا اله');
    expect(state().partialCount, 2);
    expect(state().finalCount, 1);
    expect(state().lastError, 'network error');
    expect(state().status, LiveRecognizerStatus.listening);
  });

  test('re-publishes engine events for later consumers', () async {
    final seen = <LiveRecognitionEvent>[];
    container
        .read(liveRecognitionControllerProvider.notifier)
        .events
        .listen(seen.add);
    recognizer.events_.add(const LivePartialTranscript('الله'));
    await pumpEventQueue();
    expect(seen.single, isA<LivePartialTranscript>());
  });

  test('an unavailable engine is reported, not started', () async {
    recognizer.available = false;
    await session().start(startLocation: const QuranLocation.page(1, 42));
    await pumpEventQueue();
    expect(state().status, LiveRecognizerStatus.unavailable);
    expect(recognizer.inputs, isEmpty);
    expect(
      container.read(recitationSessionControllerProvider).phase,
      RecitationPhase.listening,
      reason: 'recording carries on without recognition',
    );
  });

  test('disposing releases the engine', () async {
    container.dispose();
    await pumpEventQueue();
    expect(recognizer.disposed, isTrue);
  });
}
