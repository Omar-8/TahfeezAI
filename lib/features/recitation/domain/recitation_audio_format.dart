/// The raw audio format a live recitation session captures and exposes.
///
/// Always uncompressed, little-endian, signed 16-bit PCM — the format
/// streaming speech recognizers consume directly, with no decode step
/// between the microphone and the recognizer. 16 kHz mono is the default
/// because it is what on-device and cloud ASR models expect; a platform may
/// still report a different [sampleRate]/[channels] if the hardware refused
/// the request (see `RecitationAudioCapture.format`).
class RecitationAudioFormat {
  const RecitationAudioFormat({this.sampleRate = 16000, this.channels = 1})
    : assert(sampleRate > 0),
      assert(channels > 0);

  /// The format every session asks for first.
  static const speech = RecitationAudioFormat();

  final int sampleRate;
  final int channels;

  /// PCM16: two bytes per sample.
  int get bytesPerSample => 2;

  int get bytesPerSecond => sampleRate * channels * bytesPerSample;

  /// Duration of [byteCount] bytes of audio in this format.
  Duration durationOf(int byteCount) => Duration(
    microseconds:
        (byteCount * Duration.microsecondsPerSecond) ~/ bytesPerSecond,
  );

  @override
  bool operator ==(Object other) =>
      other is RecitationAudioFormat &&
      other.sampleRate == sampleRate &&
      other.channels == channels;

  @override
  int get hashCode => Object.hash(sampleRate, channels);

  @override
  String toString() =>
      'RecitationAudioFormat(${sampleRate}Hz, ${channels}ch, pcm16le)';
}
