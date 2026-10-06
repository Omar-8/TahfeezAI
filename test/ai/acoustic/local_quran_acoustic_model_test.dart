import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tahfeez_ai/ai/acoustic/acoustic_model_manifest.dart';
import 'package:tahfeez_ai/ai/acoustic/local_quran_acoustic_model.dart';
import 'package:tahfeez_ai/ai/acoustic/quran_acoustic_model.dart';
import 'package:tahfeez_ai/ai/acoustic/quran_phonetic_reference.dart';

Map<String, Object?> manifestJson({
  int format = 1,
  int sampleRate = 16000,
  int? classes,
  List<String>? vocabulary,
  int frameMs = 40,
  num maxWindow = 20,
  int bytes = 1000,
}) => {
  'id': 'test-model',
  'format': format,
  'sample_rate': sampleRate,
  'classes': classes ?? quranPhoneticVocabulary.length,
  'vocabulary': vocabulary ?? quranPhoneticVocabulary,
  'frame_ms': frameMs,
  'max_window_seconds': maxWindow,
  'sha256': 'ab' * 32,
  'bytes': bytes,
  'experimental': true,
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  LocalQuranAcousticModel.statusAttempts = 0;

  group('AcousticModelManifest', () {
    test('accepts a model matching what Tahfeez expects', () {
      final m = AcousticModelManifest.fromJson(manifestJson());
      expect(m.incompatibility, isNull);
      expect(m.info.frameDuration, const Duration(milliseconds: 40));
      expect(m.experimental, isTrue);
    });

    test('names what does not match', () {
      String? problem(Map<String, Object?> json) =>
          AcousticModelManifest.fromJson(json).incompatibility;
      expect(problem(manifestJson(format: 2)), contains('format'));
      expect(problem(manifestJson(sampleRate: 8000)), contains('8000'));
      expect(problem(manifestJson(classes: 42)), contains('42 classes'));
      expect(
        problem(
          manifestJson(vocabulary: [...quranPhoneticVocabulary.reversed]),
        ),
        contains('vocabulary'),
      );
      expect(problem(manifestJson(frameMs: 20)), contains('20 ms'));
      expect(problem(manifestJson(maxWindow: 2)), contains('4 s'));
    });

    test('a missing field is a format error', () {
      expect(
        () => AcousticModelManifest.fromJson(
          {...manifestJson()}..remove('sha256'),
        ),
        throwsFormatException,
      );
    });
  });

  group('LocalQuranAcousticModel', () {
    const channel = MethodChannel(LocalQuranAcousticModel.channelName);
    late Map<String, Object?> status;
    late List<MethodCall> calls;
    late Object? Function(MethodCall) run;

    setUp(() {
      calls = [];
      status = {
        'state': 'present',
        'path': '/data/models/quran_acoustic.onnx',
        'bytes': 1000,
        'manifest': jsonEncode(manifestJson()),
      };
      run = (call) {
        final samples = (call.arguments as Map)['samples'] as Float32List;
        final frames = samples.length ~/ 640;
        return {
          'frames': frames,
          'classes': 43,
          'logProbs': Float32List(frames * 43),
          'ms': 12,
          'cpuMs': 30,
        };
      };
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            calls.add(call);
            return switch (call.method) {
              'status' => status,
              'load' => {'loadMs': 900, 'hashMs': 0, 'sessionMs': 800},
              'run' => run(call),
              'stats' => {'pssKb': 1024, 'batteryTenthsC': 315},
              _ => null,
            };
          });
    });

    tearDown(
      () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null),
    );

    test('reports a missing model clearly, with where it looked', () async {
      status = {
        'state': 'absent',
        'searched': ['/sdcard/Android/data/x/files/models/quran_acoustic.onnx'],
      };
      final s = await LocalQuranAcousticModel().status();
      expect(s.state, LocalAcousticModelState.absent);
      expect(s.usable, isFalse);
      expect('$s', contains('No acoustic model installed'));
      expect('$s', contains('/sdcard/Android/data'));
      await expectLater(LocalQuranAcousticModel().load(), throwsStateError);
    });

    test('an incompatible or incomplete model is unusable', () async {
      status['manifest'] = jsonEncode(manifestJson(classes: 41));
      expect(
        (await LocalQuranAcousticModel().status()).state,
        LocalAcousticModelState.invalid,
      );
      status['manifest'] = jsonEncode(manifestJson());
      status['bytes'] = 999;
      final s = await LocalQuranAcousticModel().status();
      expect(s.state, LocalAcousticModelState.invalid);
      expect('$s', contains('incomplete'));
    });

    test('loads once, then runs windows', () async {
      final model = LocalQuranAcousticModel(
        provider: AcousticExecutionProvider.xnnpack,
        threads: 4,
      );
      final load = await model.load();
      expect(load.loadTime, const Duration(milliseconds: 900));
      await model.load();
      expect(calls.where((c) => c.method == 'load'), hasLength(1));
      expect(calls.firstWhere((c) => c.method == 'load').arguments, {
        'provider': 'xnnpack',
        'threads': 4,
      });

      final frames = await model.run(Float32List(16000 * 4));
      expect(frames.frames, 100);
      expect(frames.classes, 43);
      expect(model.info.id, 'test-model');
      expect(model.lastRunTime, const Duration(milliseconds: 12));
      expect((await model.deviceStats())!.batteryCelsius, 31.5);
    });

    test('refuses windows over the model limit, and a bad output', () async {
      final model = LocalQuranAcousticModel();
      await expectLater(
        model.run(Float32List(16000 * 21)),
        throwsArgumentError,
      );
      run = (_) => {
        'frames': 3,
        'classes': 43,
        'logProbs': Float32List(10),
        'ms': 1,
        'cpuMs': 1,
      };
      await expectLater(model.run(Float32List(16000)), throwsStateError);
    });

    test(
      'a device without the runtime (not 64-bit ARM) is unsupported',
      () async {
        status = {
          'state': 'unsupported',
          'detail': 'needs a 64-bit ARM device',
        };
        final s = await LocalQuranAcousticModel().status();
        expect(s.state, LocalAcousticModelState.unsupported);
        expect('$s', contains('64-bit ARM'));
      },
    );

    test('a platform without the channel is unsupported', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
      final s = await LocalQuranAcousticModel().status();
      expect(s.state, LocalAcousticModelState.unsupported);
    });

    test('is a QuranAcousticModel: nothing ONNX-specific leaks out', () {
      expect(LocalQuranAcousticModel(), isA<QuranAcousticModel>());
    });
  });

  test(
    'runInPieces: long audio in overlapping runs, stitched in order',
    () async {
      final model = _CountingModel();
      final frames = await runInPieces(model, Float32List(50 * 16000));
      expect(model.lengths, [20 * 16000, 20 * 16000, 14 * 16000]);
      // Every stream frame once, in order (frame i carries i).
      expect(frames.frames, 50 * 25);
      for (var f = 0; f < frames.frames; f++) {
        expect(frames.at(f, 0), f, reason: 'frame $f');
      }
      expect((await runInPieces(model, Float32List(16000))).frames, 25);
    },
  );
}

/// Frame i of a run starting at sample s carries s / 640 + i.
class _CountingModel implements QuranAcousticModel {
  final lengths = <int>[];
  int _next = 0;

  @override
  AcousticModelInfo get info =>
      const AcousticModelInfo(id: 'counting', vocabulary: []);

  @override
  Future<AcousticFrames> run(Float32List samples) async {
    lengths.add(samples.length);
    final n = samples.length ~/ 640;
    final start = _next;
    _next += (samples.length - 2 * 16000) ~/ 640;
    final lp = Float32List(n * 43);
    for (var i = 0; i < n; i++) {
      lp[i * 43] = (start + i).toDouble();
    }
    return AcousticFrames(
      frames: n,
      classes: 43,
      logProbs: lp,
      frameDuration: const Duration(milliseconds: 40),
    );
  }

  @override
  Future<void> dispose() async {}
}
