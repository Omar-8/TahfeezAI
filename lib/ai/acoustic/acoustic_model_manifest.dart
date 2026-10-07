import 'quran_acoustic_model.dart';
import 'quran_phonetic_reference.dart';

/// The compatibility contract between Tahfeez and an acoustic model file,
/// stored beside it (`<model>.json`). Swapping models — the current
/// 386 MB development model for a distilled student later — is a file swap
/// plus this manifest: nothing in the verifier, tracker or UI changes, as
/// long as the manifest matches what Tahfeez expects.
class AcousticModelManifest {
  const AcousticModelManifest({
    required this.id,
    required this.format,
    required this.sampleRate,
    required this.classes,
    required this.vocabulary,
    required this.frameMs,
    required this.maxWindowSeconds,
    required this.sha256,
    required this.bytes,
    this.licence,
    this.experimental = false,
    this.stream,
  });

  /// The manifest format Tahfeez reads.
  static const currentFormat = 1;

  /// The vocabulary version: the phoneme classes in order.
  static String get expectedVocabulary => quranPhoneticVocabulary.join('|');

  factory AcousticModelManifest.fromJson(Map<String, Object?> json) {
    T field<T>(String key) {
      final value = json[key];
      if (value is! T) {
        throw FormatException('Model manifest: "$key" missing or invalid');
      }
      return value;
    }

    return AcousticModelManifest(
      id: field<String>('id'),
      format: field<int>('format'),
      sampleRate: field<int>('sample_rate'),
      classes: field<int>('classes'),
      vocabulary: field<List<Object?>>('vocabulary').cast<String>(),
      frameMs: field<int>('frame_ms'),
      maxWindowSeconds: field<num>('max_window_seconds').toDouble(),
      sha256: field<String>('sha256'),
      bytes: field<int>('bytes'),
      licence: json['licence'] as String?,
      experimental: json['experimental'] == true,
      stream: switch (json['stream']) {
        final Map<String, Object?> s => AcousticStreamConfig.fromJson(s),
        null => null,
        _ => throw const FormatException('Model manifest: "stream" invalid'),
      },
    );
  }

  final String id;
  final int format;
  final int sampleRate;
  final int classes;
  final List<String> vocabulary;
  final int frameMs;

  /// The longest audio one run may take (memory grows with it).
  final double maxWindowSeconds;

  /// Of the model file, hex.
  final String sha256;
  final int bytes;
  final String? licence;

  /// Not cleared for distribution (see `docs/THIRD_PARTY_RESOURCES.md`).
  final bool experimental;

  /// A streaming model's chunking, or `null` for a model run on windows.
  final AcousticStreamConfig? stream;

  /// Why Tahfeez can't use a model with this manifest, or `null`.
  String? get incompatibility {
    if (format != currentFormat) return 'manifest format $format';
    if (sampleRate != 16000) return 'sample rate $sampleRate';
    if (classes != quranPhoneticVocabulary.length) return '$classes classes';
    if (vocabulary.join('|') != expectedVocabulary) {
      return 'a different phoneme vocabulary';
    }
    if (frameMs != 40) return '$frameMs ms frames';
    if (maxWindowSeconds < 4) return 'windows under 4 s';
    return null;
  }

  AcousticModelInfo get info => AcousticModelInfo(
    id: id,
    vocabulary: vocabulary,
    sampleRate: sampleRate,
    frameDuration: Duration(milliseconds: frameMs),
  );
}

/// How a streaming model is fed (`stream` in the manifest): chunk by chunk,
/// each run taking [chunkSamples] of new audio and the [overlapSamples]
/// after it, with the model's state carried from run to run on the
/// platform side. Each chunk's frames are final: no frame is computed twice.
class AcousticStreamConfig {
  const AcousticStreamConfig({
    required this.chunkSamples,
    required this.overlapSamples,
    required this.chunkSeconds,
    required this.leftSeconds,
  });

  factory AcousticStreamConfig.fromJson(Map<String, Object?> json) {
    T field<T>(String key) {
      final value = json[key];
      if (value is! T) {
        throw FormatException(
          'Model manifest: "stream.$key" missing or invalid',
        );
      }
      return value;
    }

    return AcousticStreamConfig(
      chunkSamples: field<int>('chunk_samples'),
      overlapSamples: field<int>('overlap_samples'),
      chunkSeconds: field<num>('chunk_s').toDouble(),
      leftSeconds: field<num>('left_s').toDouble(),
    );
  }

  /// New audio per run (a whole number of 40 ms frames).
  final int chunkSamples;

  /// Audio after the chunk each run also needs (the last fbank frames').
  final int overlapSamples;

  /// The look-ahead (one chunk) and the past the model remembers.
  final double chunkSeconds, leftSeconds;
}
