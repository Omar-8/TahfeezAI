import 'dart:typed_data';

import '../domain/recitation_audio_format.dart';

/// Size of the canonical 44-byte RIFF/WAVE header [wavHeader] writes.
const wavHeaderLength = 44;

/// A canonical PCM16 WAV header for [dataLength] bytes of [format] audio.
///
/// The Android sink writes a placeholder header first and patches it with
/// the real length on close, so a recording can be streamed straight to
/// disk without buffering the whole session in memory.
Uint8List wavHeader(RecitationAudioFormat format, int dataLength) {
  final bytes = ByteData(wavHeaderLength);
  void ascii(int offset, String s) {
    for (var i = 0; i < s.length; i++) {
      bytes.setUint8(offset + i, s.codeUnitAt(i));
    }
  }

  final blockAlign = format.channels * format.bytesPerSample;
  ascii(0, 'RIFF');
  bytes.setUint32(4, 36 + dataLength, Endian.little);
  ascii(8, 'WAVE');
  ascii(12, 'fmt ');
  bytes.setUint32(16, 16, Endian.little); // fmt chunk size
  bytes.setUint16(20, 1, Endian.little); // PCM
  bytes.setUint16(22, format.channels, Endian.little);
  bytes.setUint32(24, format.sampleRate, Endian.little);
  bytes.setUint32(28, format.bytesPerSecond, Endian.little);
  bytes.setUint16(32, blockAlign, Endian.little);
  bytes.setUint16(34, format.bytesPerSample * 8, Endian.little);
  ascii(36, 'data');
  bytes.setUint32(40, dataLength, Endian.little);
  return bytes.buffer.asUint8List();
}
