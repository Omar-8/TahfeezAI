import 'dart:typed_data';

import '../../core/networking/network_client.dart';
import '../domain/offline_recitation.dart';
import 'quran_acoustic_model.dart';
import 'quran_phonetic_reference.dart';

/// [QuranAcousticModel] served over HTTP by
/// `tool/acoustic_verification/server.py`: PCM16 audio goes up, frame-level
/// log-probabilities come back. Alignment and verification stay on the
/// device — only the model runs remotely.
class RemoteAcousticModel implements QuranAcousticModel {
  RemoteAcousticModel({
    required this.network,
    required this.baseUrl,
    this.timeout = const Duration(seconds: 30),
  });

  final NetworkClient network;
  final String baseUrl;
  final Duration timeout;

  /// How long the server's model took for the last request.
  Duration? lastModelTime;

  @override
  AcousticModelInfo get info => AcousticModelInfo(
    id: 'remote:$baseUrl',
    vocabulary: quranPhoneticVocabulary,
  );

  @override
  Future<AcousticFrames> run(Float32List samples) async {
    ensureRecitationNetworkAllowed('sending recitation audio to $baseUrl');
    final pcm = ByteData(samples.length * 2);
    for (var i = 0; i < samples.length; i++) {
      final v = (samples[i] * 32767).round().clamp(-32768, 32767);
      pcm.setInt16(i * 2, v, Endian.little);
    }
    final response = await network.postBytes(
      '$baseUrl/v1/frames',
      pcm.buffer.asUint8List(),
      timeout: timeout,
    );
    final frames = int.parse(response.headers.value('x-frames') ?? '0');
    final classes = int.parse(response.headers.value('x-classes') ?? '0');
    final ms = int.tryParse(response.headers.value('x-model-ms') ?? '');
    lastModelTime = ms == null ? null : Duration(milliseconds: ms);
    final body = Uint8List.fromList(response.data ?? const []);
    if (classes != quranPhoneticVocabulary.length ||
        body.length != frames * classes * 4) {
      throw StateError(
        'Acoustic server returned $frames x $classes frames '
        '(${body.length} bytes)',
      );
    }
    final logProbs = Float32List(frames * classes);
    final view = ByteData.sublistView(body);
    for (var i = 0; i < logProbs.length; i++) {
      logProbs[i] = view.getFloat32(i * 4, Endian.little);
    }
    return AcousticFrames(
      frames: frames,
      classes: classes,
      logProbs: logProbs,
      frameDuration: info.frameDuration,
    );
  }

  @override
  Future<void> dispose() async {}
}
