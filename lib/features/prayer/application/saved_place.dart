import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/storage/storage_providers.dart';
import '../../qibla/data/city_index.dart';
import '../../qibla/domain/qibla_place.dart';

/// The place prayer times are worked out for (owner, 2026-11-21): the
/// Qibla finder's — a city chosen, or where the phone last found itself,
/// kept rounded to about a kilometre (two decimals) and named after the
/// nearest city, so Home shows today's times without asking again.
class SavedPlaceController extends Notifier<QiblaPlace?> {
  static const storageKey = 'place.saved';

  @override
  QiblaPlace? build() {
    unawaited(_restore());
    return null;
  }

  Future<void> _restore() async {
    final saved = QiblaPlace.decode(
      await ref.read(browserStorageProvider).getString(storageKey),
    );
    if (ref.mounted && saved != null && state == null) state = saved;
  }

  /// [place] from now on: a city as it is; the phone's own position
  /// rounded, named after the nearest city.
  Future<void> set(QiblaPlace place) async {
    var next = place;
    if (!place.isCity) {
      double round(double v) => (v * 100).round() / 100;
      final lat = round(place.latitude), lon = round(place.longitude);
      QiblaPlace? near;
      try {
        near = (await ref.read(cityIndexProvider.future)).nearest(lat, lon);
      } on Object {
        near = null;
      }
      next = QiblaPlace(
        latitude: lat,
        longitude: lon,
        name: near?.name,
        country: near?.country,
      );
    }
    if (!ref.mounted) return;
    state = next;
    await ref.read(browserStorageProvider).setString(storageKey, next.encode());
  }
}

final savedPlaceProvider = NotifierProvider<SavedPlaceController, QiblaPlace?>(
  SavedPlaceController.new,
);
