import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tahfeez_ai/ai/speech/android_speech_live_recognizer.dart';
import 'package:tahfeez_ai/ai/speech/live_quran_recognizer.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const methods = MethodChannel('tahfeez/live_speech');
  const events = 'tahfeez/live_speech/events';
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  late List<MethodCall> calls;
  late bool feedsAudio;

  setUp(() {
    calls = [];
    feedsAudio = true;
    messenger.setMockMethodCallHandler(methods, (call) async {
      calls.add(call);
      return switch (call.method) {
        'availability' => {
          'available': true,
          'onDevice': false,
          'feedsAudio': true,
          'sdk': 36,
        },
        'start' => {'feedsAudio': feedsAudio},
        _ => null,
      };
    });
    messenger.setMockStreamHandler(
      const EventChannel(events),
      MockStreamHandler.inline(onListen: (_, sink) => _sink = sink),
    );
  });

  tearDown(() {
    messenger.setMockMethodCallHandler(methods, null);
    messenger.setMockStreamHandler(const EventChannel(events), null);
  });

  test('availability', () async {
    final availability = await AndroidSpeechLiveRecognizer()
        .checkAvailability();
    expect(availability.available, isTrue);
    expect(availability.detail, contains('shared mic'));
  });

  test('starts with the input format and pipes audio in order', () async {
    final recognizer = AndroidSpeechLiveRecognizer();
    final audio = StreamController<Uint8List>();
    await recognizer.start(
      LiveAudioInput(sampleRate: 16000, channels: 1, audio: audio.stream),
    );
    audio
      ..add(Uint8List.fromList([1, 2]))
      ..add(Uint8List.fromList([3, 4]));
    await pumpEventQueue();

    expect(calls.first.method, 'start');
    expect(calls.first.arguments, {
      'language': 'ar-SA',
      'sampleRate': 16000,
      'channels': 1,
      'preferOnDevice': false,
    });
    expect(calls.where((c) => c.method == 'feed').map((c) => c.arguments), [
      [1, 2],
      [3, 4],
    ]);

    await recognizer.stop();
    audio.add(Uint8List.fromList([5]));
    await pumpEventQueue();
    expect(calls.last.method, 'stop');
    expect(calls.where((c) => c.method == 'feed'), hasLength(2));
  });

  test('does not pipe audio when the engine uses its own mic', () async {
    feedsAudio = false;
    final recognizer = AndroidSpeechLiveRecognizer();
    final audio = StreamController<Uint8List>();
    await recognizer.start(
      LiveAudioInput(sampleRate: 16000, channels: 1, audio: audio.stream),
    );
    audio.add(Uint8List(4));
    await pumpEventQueue();
    expect(calls.where((c) => c.method == 'feed'), isEmpty);
  });

  test('maps platform events', () async {
    final recognizer = AndroidSpeechLiveRecognizer();
    final received = <LiveRecognitionEvent>[];
    recognizer.events.listen(received.add);
    await recognizer.start(
      const LiveAudioInput(
        sampleRate: 16000,
        channels: 1,
        audio: Stream.empty(),
      ),
    );

    _sink!
      ..success({'type': 'status', 'status': 'listening', 'detail': 'x'})
      ..success({'type': 'partial', 'text': 'الله  لا'})
      ..success({'type': 'final', 'text': 'الله لا اله', 'confidence': 0.9})
      ..success({
        'type': 'error',
        'message': 'network error',
        'recoverable': true,
      });
    await pumpEventQueue();

    expect(
      (received[0] as LiveRecognizerStatusChanged).status,
      LiveRecognizerStatus.listening,
    );
    expect((received[1] as LivePartialTranscript).text, 'الله لا');
    expect((received[2] as LiveFinalTranscript).confidence, 0.9);
    expect((received[3] as LiveRecognitionError).recoverable, isTrue);
  });
}

MockStreamHandlerEventSink? _sink;
