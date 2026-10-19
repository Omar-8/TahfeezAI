import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/services.dart';

import 'acoustic_model_manifest.dart';
import 'quran_acoustic_model.dart';

/// Whether an on-device acoustic model is installed, and usable.
enum LocalAcousticModelState {
  /// This platform has no local runtime yet (web: pending).
  unsupported,

  /// No model file on the device.
  absent,

  /// A model file without a valid, compatible manifest.
  invalid,

  /// Installed and compatible (not loaded yet).
  present,

  /// Loaded and ready to run.
  loaded,
}

class LocalAcousticModelStatus {
  const LocalAcousticModelStatus(
    this.state, {
    this.detail,
    this.path,
    this.manifest,
  });

  final LocalAcousticModelState state;

  /// What is wrong, or where it was looked for.
  final String? detail;
  final String? path;
  final AcousticModelManifest? manifest;

  bool get usable =>
      state == LocalAcousticModelState.present ||
      state == LocalAcousticModelState.loaded;

  @override
  String toString() => switch (state) {
    LocalAcousticModelState.unsupported =>
      'On-device model not supported here${detail == null ? '' : ' ($detail)'}',
    LocalAcousticModelState.absent =>
      'No acoustic model installed${detail == null ? '' : ' — looked in $detail'}',
    LocalAcousticModelState.invalid => 'Acoustic model unusable: $detail',
    LocalAcousticModelState.present ||
    LocalAcousticModelState.loaded => '${manifest?.id ?? 'model'} at $path',
  };
}

/// Where ONNX Runtime runs the model on Android.
enum AcousticExecutionProvider { cpu, xnnpack, nnapi }

/// What loading took.
class AcousticModelLoad {
  const AcousticModelLoad({
    required this.provider,
    required this.loadTime,
    this.hashTime,
    this.sessionTime,
  });

  final AcousticExecutionProvider provider;
  final Duration loadTime;
  final Duration? hashTime, sessionTime;
}

/// Device measurements around the model (Android).
class AcousticDeviceStats {
  const AcousticDeviceStats({
    this.pssKb,
    this.nativeHeapBytes,
    this.cpuTime,
    this.batteryPercent,
    this.batteryMicroAmps,
    this.batteryCelsius,
    this.cores,
  });

  factory AcousticDeviceStats.fromMap(Map<Object?, Object?> m) =>
      AcousticDeviceStats(
        pssKb: m['pssKb'] as int?,
        nativeHeapBytes: m['nativeHeapBytes'] as int?,
        cpuTime: m['cpuMs'] == null
            ? null
            : Duration(milliseconds: m['cpuMs']! as int),
        batteryPercent: (m['batteryPercent'] as num?)?.toDouble(),
        batteryMicroAmps: m['batteryMicroAmps'] as int?,
        batteryCelsius: switch (m['batteryTenthsC']) {
          final int t when t >= 0 => t / 10,
          _ => null,
        },
        cores: m['cores'] as int?,
      );

  final int? pssKb, nativeHeapBytes, batteryMicroAmps, cores;
  final Duration? cpuTime;
  final double? batteryPercent, batteryCelsius;
}

/// The Quran acoustic model on this device (Android: ONNX Runtime through
/// `QuranAcousticModelChannel.kt`). Loaded once and reused; the session,
/// tensors and providers stay on the platform side — Tahfeez sees only
/// [QuranAcousticModel].
///
/// Development builds use a sideloaded model (see
/// `docs/ARCHITECTURE.md` §32); nothing is bundled.
class LocalQuranAcousticModel implements QuranAcousticModel {
  LocalQuranAcousticModel({
    MethodChannel? channel,
    this.provider = AcousticExecutionProvider.cpu,
    this.threads = 0,
  }) : _channel = channel ?? const MethodChannel(channelName);

  static const channelName = 'tahfeez/quran_acoustic_model';

  final MethodChannel _channel;
  final AcousticExecutionProvider provider;

  /// Intra-op threads; 0: the phone's fast cores less one (2-4), on Android
  /// (`QuranAcousticModelChannel.fastCoreThreads`).
  final int threads;

  /// How often [status] retries a channel not registered yet (300 ms apart).
  static int statusAttempts = 10;

  AcousticModelManifest? _manifest;
  Future<AcousticModelLoad>? _loading;

  /// The last run's model time and CPU time.
  Duration? lastRunTime, lastCpuTime;

  @override
  AcousticModelInfo get info =>
      _manifest?.info ??
      const AcousticModelInfo(id: 'local (not loaded)', vocabulary: []);

  /// Whether the model is installed and compatible.
  Future<LocalAcousticModelStatus> status() async {
    Map<Object?, Object?>? raw;
    // The platform side registers with the activity; right after launch it
    // may not be there yet.
    for (var attempt = 0; raw == null; attempt++) {
      try {
        raw = (await _channel.invokeMapMethod<Object?, Object?>('status'))!;
      } on MissingPluginException {
        if (attempt >= statusAttempts) {
          return const LocalAcousticModelStatus(
            LocalAcousticModelState.unsupported,
          );
        }
        await Future<void>.delayed(const Duration(milliseconds: 300));
      }
    }
    final path = raw['path'] as String?;
    switch (raw['state']) {
      case 'unsupported':
        return LocalAcousticModelStatus(
          LocalAcousticModelState.unsupported,
          detail: raw['detail'] as String?,
        );
      case 'absent':
        return LocalAcousticModelStatus(
          LocalAcousticModelState.absent,
          detail: (raw['searched'] as List?)?.join(', '),
        );
      case 'invalid':
        return LocalAcousticModelStatus(
          LocalAcousticModelState.invalid,
          detail: raw['detail'] as String?,
          path: path,
        );
    }
    final AcousticModelManifest manifest;
    try {
      manifest = AcousticModelManifest.fromJson(
        jsonDecode(raw['manifest']! as String) as Map<String, Object?>,
      );
    } on FormatException catch (e) {
      return LocalAcousticModelStatus(
        LocalAcousticModelState.invalid,
        detail: e.message,
        path: path,
      );
    }
    final problem = manifest.incompatibility;
    if (problem != null) {
      return LocalAcousticModelStatus(
        LocalAcousticModelState.invalid,
        detail: 'incompatible: $problem',
        path: path,
        manifest: manifest,
      );
    }
    if (raw['bytes'] != manifest.bytes) {
      return LocalAcousticModelStatus(
        LocalAcousticModelState.invalid,
        detail:
            'file is ${raw['bytes']} bytes, manifest says '
            '${manifest.bytes} (incomplete copy?)',
        path: path,
        manifest: manifest,
      );
    }
    _manifest = manifest;
    return LocalAcousticModelStatus(
      raw['state'] == 'loaded'
          ? LocalAcousticModelState.loaded
          : LocalAcousticModelState.present,
      path: path,
      manifest: manifest,
    );
  }

  /// Loads the model once (checking its SHA-256 against the manifest);
  /// later calls return the same load.
  Future<AcousticModelLoad> load() => _loading ??= _load();

  Future<AcousticModelLoad> _load() async {
    final status = await this.status();
    if (!status.usable) {
      _loading = null;
      throw StateError('$status');
    }
    try {
      final raw = (await _channel.invokeMapMethod<Object?, Object?>('load', {
        'provider': provider.name,
        'threads': threads,
      }))!;
      Duration? ms(Object? v) => v is int ? Duration(milliseconds: v) : null;
      return AcousticModelLoad(
        provider: provider,
        loadTime: ms(raw['loadMs']) ?? Duration.zero,
        hashTime: ms(raw['hashMs']),
        sessionTime: ms(raw['sessionMs']),
      );
    } catch (_) {
      _loading = null;
      rethrow;
    }
  }

  @override
  Future<AcousticFrames> run(Float32List samples) async {
    await load();
    final limit = (_manifest!.maxWindowSeconds * _manifest!.sampleRate).round();
    if (samples.length > limit) {
      throw ArgumentError(
        '${samples.length} samples: over the model\'s '
        '${_manifest!.maxWindowSeconds} s window',
      );
    }
    final raw = (await _channel.invokeMapMethod<Object?, Object?>('run', {
      'samples': samples,
    }))!;
    final frames = raw['frames']! as int;
    final classes = raw['classes']! as int;
    final logProbs = raw['logProbs']! as Float32List;
    if (classes != _manifest!.classes || logProbs.length != frames * classes) {
      throw StateError('Model returned $frames x $classes frames');
    }
    lastRunTime = Duration(milliseconds: raw['ms']! as int);
    lastCpuTime = Duration(milliseconds: raw['cpuMs']! as int);
    return AcousticFrames(
      frames: frames,
      classes: classes,
      logProbs: logProbs,
      frameDuration: info.frameDuration,
    );
  }

  /// A streaming model's chunking (its manifest's), or `null`.
  AcousticStreamConfig? get stream => _manifest?.stream;

  /// A streaming model: its state back to the start (a new recitation).
  Future<void> streamReset() async {
    await load();
    await _channel.invokeMethod<void>('streamReset');
  }

  /// A streaming model: one chunk ([AcousticStreamConfig.chunkSamples] of
  /// audio and the [AcousticStreamConfig.overlapSamples] after it), the
  /// state carried on from the previous chunk. Its frames are final.
  /// [commit] `false`: a provisional look at a partial chunk (the audio
  /// stopped mid-chunk), the state left as it was for the real chunk.
  Future<AcousticFrames> streamRun(
    Float32List samples, {
    bool commit = true,
  }) async {
    await load();
    final raw = (await _channel.invokeMapMethod<Object?, Object?>('streamRun', {
      'samples': samples,
      'commit': commit,
    }))!;
    final frames = raw['frames']! as int;
    final classes = raw['classes']! as int;
    final logProbs = raw['logProbs']! as Float32List;
    if (classes != _manifest!.classes || logProbs.length != frames * classes) {
      throw StateError('Model returned $frames x $classes frames');
    }
    lastRunTime = Duration(milliseconds: raw['ms']! as int);
    lastCpuTime = Duration(milliseconds: raw['cpuMs']! as int);
    return AcousticFrames(
      frames: frames,
      classes: classes,
      logProbs: logProbs,
      frameDuration: info.frameDuration,
    );
  }

  Future<AcousticDeviceStats?> deviceStats() async {
    try {
      final raw = await _channel.invokeMapMethod<Object?, Object?>('stats');
      return raw == null ? null : AcousticDeviceStats.fromMap(raw);
    } on MissingPluginException {
      return null;
    }
  }

  @override
  Future<void> dispose() async {
    if (_loading == null) return; // never loaded
    _loading = null;
    try {
      await _channel.invokeMethod<void>('unload');
    } on MissingPluginException {
      // Nothing loaded.
    }
  }
}
