import 'package:flutter/services.dart';

/// Keeps the screen on while on-device recitation AI is listening.
///
/// With the screen off, Android moves the app to its efficiency cores, and
/// the acoustic model ran ~6× slower (measured on a Snapdragon 870: an 8 s
/// window took 43 s instead of 6 s), so following would fall minutes
/// behind. Android only (`MainActivity`); elsewhere a no-op.
class ScreenAwake {
  const ScreenAwake([this._channel = const MethodChannel('tahfeez/screen')]);

  final MethodChannel _channel;

  Future<void> keepOn(bool on) async {
    try {
      await _channel.invokeMethod<void>('keepOn', on);
    } on MissingPluginException {
      // Not on Android.
    } on PlatformException {
      // No activity right now; the next session tries again.
    }
  }
}
