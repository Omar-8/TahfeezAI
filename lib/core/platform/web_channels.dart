import 'dart:async';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'dart:typed_data';

import 'package:flutter/services.dart';
import 'package:flutter_web_plugins/flutter_web_plugins.dart';
import 'package:web/web.dart' as web;

import '../../ai/acoustic/acoustic_model_download.dart';

/// The web's answers to the channels the phones' own code answers, so the
/// same Dart drives both:
/// - `tahfeez/quran_acoustic_model`: the acoustic model, in a worker
///   (`web/acoustic/acoustic_worker.js`, ONNX Runtime Web);
/// - `tahfeez/alert`: a mistake's vibration (where the browser vibrates)
///   and beep (Web Audio).
void registerWebPlatformChannels() {
  final registrar = webPluginRegistrar;
  MethodChannel(
    'tahfeez/quran_acoustic_model',
    const StandardMethodCodec(),
    registrar,
  ).setMethodCallHandler(_AcousticWorker().handle);
  MethodChannel(
    'tahfeez/alert',
    const StandardMethodCodec(),
    registrar,
  ).setMethodCallHandler(_alert);
}

class _AcousticWorker {
  web.Worker? _worker;
  final _pending = <int, Completer<Object?>>{};
  var _next = 0;

  web.Worker get _started => _worker ??= web.Worker(
    'acoustic/acoustic_worker.js'.toJS,
    web.WorkerOptions(type: 'module'),
  )..onmessage = _reply.toJS;

  void _reply(web.MessageEvent event) {
    final data = event.data as JSObject;
    if (data.has('progress')) {
      acousticModelDownload.value =
          (data['progress'] as JSNumber).toDartDouble;
      return;
    }
    final id = (data['id'] as JSNumber).toDartInt;
    final completer = _pending.remove(id);
    if (completer == null) return;
    final error = data['error'];
    if (error != null) {
      completer.completeError(
        PlatformException(
          code: 'acoustic_model',
          message: (error as JSString).toDart,
        ),
      );
    } else {
      completer.complete(data['result'].dartify());
    }
  }

  Future<Object?> _call(String method, [JSObject? args]) {
    final id = _next++;
    final completer = _pending[id] = Completer<Object?>();
    final message = JSObject()
      ..['id'] = id.toJS
      ..['method'] = method.toJS
      ..['args'] = args;
    final samples = args?['samples'];
    // (The samples' buffer moves to the worker, not copied again.)
    _started.postMessage(
      message,
      samples == null ? JSArray() : [(samples as JSObject)['buffer']].toJS,
    );
    return completer.future;
  }

  Future<Object?> handle(MethodCall call) async {
    final arguments = call.arguments;
    JSObject? args;
    if (arguments is Map) {
      args = JSObject();
      for (final MapEntry(:key, :value) in arguments.entries) {
        args[key as String] = switch (value) {
          // A copy: its buffer goes to the worker.
          final Float32List samples => Float32List.fromList(samples).toJS,
          final Object? other => other.jsify(),
        };
      }
    }
    try {
      final result = await _call(call.method, args);
      if (call.method == 'load') acousticModelDownload.value = null;
      return _forDart(result);
    } catch (_) {
      if (call.method == 'load') acousticModelDownload.value = null;
      rethrow;
    }
  }

  /// What the phones' channel returns: maps of plain values, the frames a
  /// Float32List.
  static Object? _forDart(Object? result) {
    if (result is! Map) return result;
    return {
      for (final MapEntry(:key, :value) in result.entries)
        '$key': switch (value) {
          final ByteBuffer b => b.asFloat32List(),
          final TypedData t when key == 'logProbs' => Float32List.view(
            t.buffer,
            t.offsetInBytes,
            t.lengthInBytes ~/ 4,
          ),
          final double d when d == d.roundToDouble() => d.toInt(),
          _ => value,
        },
    };
  }
}

web.AudioContext? _audio;

Future<Object?> _alert(MethodCall call) async {
  switch (call.method) {
    case 'vibrate':
      web.window.navigator.vibrate((call.arguments as int? ?? 120).toJS);
    case 'pageDone':
      web.window.navigator.vibrate([40.toJS, 80.toJS, 40.toJS].toJS);
    case 'beep':
      final audio = _audio ??= web.AudioContext();
      final tone = audio.createOscillator()
        ..type = 'sine'
        ..frequency.value = 880;
      final gain = audio.createGain()..gain.value = 0.0001;
      tone.connect(gain);
      gain.connect(audio.destination);
      final now = audio.currentTime;
      gain.gain
        ..exponentialRampToValueAtTime(0.25, now + 0.01)
        ..exponentialRampToValueAtTime(0.0001, now + 0.12);
      tone
        ..start(now)
        ..stop(now + 0.13);
  }
  return null;
}
