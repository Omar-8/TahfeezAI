import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import '../../../core/notifications/daily_reminder_scheduler.dart';
import '../domain/prayer_times.dart';

/// The prayers' sounds on this phone (owner, 2026-11-21): the platform
/// adapter behind them.
abstract class PrayerSounds {
  /// Whether a sound on the phone can be chosen (Android's sound picker).
  bool get canPickFromPhone;

  /// Whether a notification can vibrate without a sound (Android).
  bool get canVibrateOnly;

  /// [sound] ready to notify with: an iPhone's adhan copied where it looks
  /// for notification sounds (Library/Sounds), once.
  Future<ReminderSound> prepare(PrayerSound sound);

  /// Android's sound picker (alarms, ringtones, notifications), [current]
  /// ticked: the sound chosen, `null` when closed without one.
  Future<DeviceSound?> pickFromPhone(DeviceSound? current);
}

/// The asset an adhan is heard from in the app: its first 30 s.
String adhanPreviewAsset(String id) => 'assets/adhan/$id.mp3';

/// An adhan's notification sound's name (res/raw on Android, a .caf in
/// Library/Sounds on an iPhone).
String adhanSoundName(String id) => 'adhan_$id';

class PlatformPrayerSounds implements PrayerSounds {
  static const _channel = MethodChannel('tahfeez/sound');

  bool get _android =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
  bool get _ios => !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;

  @override
  bool get canPickFromPhone => _android;

  @override
  bool get canVibrateOnly => _android;

  @override
  Future<ReminderSound> prepare(PrayerSound sound) async {
    switch (sound) {
      case StandardSound():
        return ReminderSound.standard;
      case SilentSound():
        return ReminderSound.none;
      case DeviceSound(:final uri):
        return ReminderSound.device(uri);
      case AdhanSound(:final id):
        if (_ios) await _installIos(id);
        return ReminderSound.bundled(adhanSoundName(id));
    }
  }

  Future<void> _installIos(String id) async {
    final library = await getLibraryDirectory();
    final file = File('${library.path}/Sounds/${adhanSoundName(id)}.caf');
    if (file.existsSync()) return;
    final data = await rootBundle.load('assets/adhan/$id.caf');
    await file.parent.create(recursive: true);
    await file.writeAsBytes(
      data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
      flush: true,
    );
  }

  @override
  Future<DeviceSound?> pickFromPhone(DeviceSound? current) async {
    if (!_android) return null;
    final picked = await _channel.invokeMapMethod<String, String>('pick', {
      'current': current?.uri,
    });
    final uri = picked?['uri'];
    if (uri == null) return null;
    return DeviceSound(uri, picked?['title'] ?? '');
  }
}

final prayerSoundsProvider = Provider<PrayerSounds>(
  (ref) => PlatformPrayerSounds(),
);
