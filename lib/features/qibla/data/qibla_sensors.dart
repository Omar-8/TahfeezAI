import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_compass/flutter_compass.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geomag/geomag.dart';

/// What finding the phone's position came to.
sealed class LocateResult {
  const LocateResult();
}

class Located extends LocateResult {
  const Located(this.latitude, this.longitude);
  final double latitude, longitude;
}

/// Location permission refused ([forever]: only the phone's settings can
/// give it now).
class LocationDenied extends LocateResult {
  const LocationDenied({this.forever = false});
  final bool forever;
}

/// The phone's location is turned off.
class LocationOff extends LocateResult {
  const LocationOff();
}

/// No position came (no signal in time, an error).
class LocationFailed extends LocateResult {
  const LocationFailed();
}

/// The phone's location and compass, for the Qibla finder — the platform
/// behind one adapter (tests give a fake). The position is asked for at
/// city accuracy only and never kept or sent anywhere.
abstract class QiblaSensors {
  /// Whether this device can give a heading at all (none in a browser, on
  /// most tablets without a magnetometer).
  bool get hasCompass;

  /// The direction the top of the phone points, degrees clockwise from
  /// TRUE north (0–360), at the place [latitude], [longitude] — `null` while
  /// the compass gives nothing usable.
  Stream<double?> heading({
    required double latitude,
    required double longitude,
  });

  Future<LocateResult> locate();

  Future<void> openAppSettings();
  Future<void> openLocationSettings();
}

class PluginQiblaSensors implements QiblaSensors {
  const PluginQiblaSensors();

  @override
  bool get hasCompass => !kIsWeb && FlutterCompass.events != null;

  @override
  Stream<double?> heading({
    required double latitude,
    required double longitude,
  }) {
    final events = kIsWeb ? null : FlutterCompass.events;
    if (events == null) return Stream.value(null);
    // Android's rotation-vector sensor gives magnetic north: corrected here
    // by the World Magnetic Model (2025) for the place and day. iOS gives
    // true north already (-1 when it cannot).
    final declination = defaultTargetPlatform == TargetPlatform.iOS
        ? 0.0
        : GeoMag().calculate(latitude, longitude).dec;
    return events.map((e) {
      final h = e.heading;
      if (h == null || h.isNaN) return null;
      if (defaultTargetPlatform == TargetPlatform.iOS && h < 0) return null;
      final t = (h + declination) % 360;
      return t < 0 ? t + 360 : t;
    });
  }

  @override
  Future<LocateResult> locate() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        return const LocationOff();
      }
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.deniedForever) {
        return const LocationDenied(forever: true);
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.unableToDetermine) {
        return const LocationDenied();
      }
      try {
        final p = await Geolocator.getCurrentPosition(
          // A city's accuracy is plenty: the qibla barely changes across it.
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.low,
            timeLimit: Duration(seconds: 20),
          ),
        );
        return Located(p.latitude, p.longitude);
      } on TimeoutException {
        final last = kIsWeb ? null : await Geolocator.getLastKnownPosition();
        return last == null
            ? const LocationFailed()
            : Located(last.latitude, last.longitude);
      }
    } on Object {
      return const LocationFailed();
    }
  }

  @override
  Future<void> openAppSettings() async {
    if (!kIsWeb) await Geolocator.openAppSettings();
  }

  @override
  Future<void> openLocationSettings() async {
    if (!kIsWeb) await Geolocator.openLocationSettings();
  }
}

final qiblaSensorsProvider = Provider<QiblaSensors>(
  (ref) => const PluginQiblaSensors(),
);
