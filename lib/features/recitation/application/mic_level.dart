import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'recitation_session_controller.dart';

/// How loudly the microphone hears the reciter, from 0 (silence) to 1, for
/// a live indicator: updated with each audio chunk while a session
/// listens, falling to 0 when it pauses or stops. A [ValueListenable], so
/// only the indicator repaints — not the bar around it.
final micLevelProvider = Provider.autoDispose<ValueListenable<double>>((ref) {
  final level = ValueNotifier<double>(0);
  final audio = ref
      .read(recitationSessionControllerProvider.notifier)
      .liveAudio
      .listen((chunk) => level.value = MicLevel.next(level.value, chunk));
  ref.listen(recitationSessionControllerProvider, (_, next) {
    if (next.phase != RecitationPhase.listening) level.value = 0;
  });
  ref.onDispose(() {
    audio.cancel();
    level.dispose();
  });
  return level;
});

abstract final class MicLevel {
  /// Quieter than this (dBFS) shows as silence; [_loud] and louder as full.
  static const _quiet = -55.0, _loud = -15.0;

  /// The level after [chunk] (PCM16LE): its loudness, rising at once and
  /// falling back gently from [previous].
  static double next(double previous, Uint8List chunk) {
    final heard = of(chunk);
    return heard >= previous ? heard : math.max(heard, previous * 0.7);
  }

  /// [chunk]'s loudness (PCM16LE; every fourth sample is enough), 0 to 1.
  static double of(Uint8List chunk) {
    final samples = chunk.lengthInBytes ~/ 2;
    if (samples == 0) return 0;
    final data = ByteData.sublistView(chunk);
    var sum = 0.0, n = 0;
    for (var i = 0; i < samples; i += 4) {
      final s = data.getInt16(i * 2, Endian.little) / 32768;
      sum += s * s;
      n++;
    }
    final rms = math.sqrt(sum / n);
    if (rms <= 0) return 0;
    final db = 20 * math.log(rms) / math.ln10;
    return ((db - _quiet) / (_loud - _quiet)).clamp(0.0, 1.0);
  }
}
