import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/storage/storage_providers.dart';
import '../../prayer/application/saved_place.dart';
import '../data/qibla_sensors.dart';
import '../domain/qibla_place.dart';

/// Where the place comes from: the phone's location, or a city chosen by
/// hand (for those who would rather not share their location, or have no
/// signal).
enum QiblaMode { automatic, manual }

enum QiblaStatus {
  /// Restoring the saved choice, or asking the phone where it is.
  locating,
  ready,
  denied,
  deniedForever,
  locationOff,
  failed,

  /// Manual, no city chosen yet.
  needsCity,
}

class QiblaState {
  const QiblaState({required this.mode, required this.status, this.place});

  final QiblaMode mode;
  final QiblaStatus status;

  /// Set when [status] is [QiblaStatus.ready].
  final QiblaPlace? place;

  QiblaState copyWith({
    QiblaMode? mode,
    QiblaStatus? status,
    QiblaPlace? place,
  }) => QiblaState(
    mode: mode ?? this.mode,
    status: status ?? this.status,
    place: place ?? this.place,
  );
}

/// The Qibla finder's place (also prayer times': see [savedPlaceProvider]
/// — the phone's own position kept only rounded to about a kilometre;
/// never sent anywhere).
class QiblaController extends Notifier<QiblaState> {
  static const modeKey = 'qibla.mode';
  static const cityKey = 'qibla.city';

  @override
  QiblaState build() {
    // Its place kept for prayer times (owner, 2026-11-21).
    listenSelf((_, next) {
      if (next.status == QiblaStatus.ready && next.place != null) {
        unawaited(ref.read(savedPlaceProvider.notifier).set(next.place!));
      }
    });
    unawaited(_restore());
    return const QiblaState(
      mode: QiblaMode.automatic,
      status: QiblaStatus.locating,
    );
  }

  Future<void> _restore() async {
    final storage = ref.read(browserStorageProvider);
    final mode = await storage.getString(modeKey) == QiblaMode.manual.name
        ? QiblaMode.manual
        : QiblaMode.automatic;
    final city = QiblaPlace.decode(await storage.getString(cityKey));
    if (!ref.mounted) return;
    if (mode == QiblaMode.manual) {
      state = city == null
          ? const QiblaState(
              mode: QiblaMode.manual,
              status: QiblaStatus.needsCity,
            )
          : QiblaState(
              mode: QiblaMode.manual,
              status: QiblaStatus.ready,
              place: city,
            );
    } else {
      await locate();
    }
  }

  /// Asks the phone where it is (its permission prompt the first time).
  Future<void> locate() async {
    state = const QiblaState(
      mode: QiblaMode.automatic,
      status: QiblaStatus.locating,
    );
    final result = await ref.read(qiblaSensorsProvider).locate();
    if (!ref.mounted || state.mode != QiblaMode.automatic) return;
    state = switch (result) {
      Located(:final latitude, :final longitude) => QiblaState(
        mode: QiblaMode.automatic,
        status: QiblaStatus.ready,
        place: QiblaPlace(latitude: latitude, longitude: longitude),
      ),
      LocationDenied(forever: true) => const QiblaState(
        mode: QiblaMode.automatic,
        status: QiblaStatus.deniedForever,
      ),
      LocationDenied() => const QiblaState(
        mode: QiblaMode.automatic,
        status: QiblaStatus.denied,
      ),
      LocationOff() => const QiblaState(
        mode: QiblaMode.automatic,
        status: QiblaStatus.locationOff,
      ),
      LocationFailed() => const QiblaState(
        mode: QiblaMode.automatic,
        status: QiblaStatus.failed,
      ),
    };
  }

  /// Back to the phone's own location.
  Future<void> useAutomatic() async {
    await ref
        .read(browserStorageProvider)
        .setString(modeKey, QiblaMode.automatic.name);
    if (!ref.mounted) return;
    await locate();
  }

  /// Manual: [city] from now on (kept for next time).
  Future<void> chooseCity(QiblaPlace city) async {
    state = QiblaState(
      mode: QiblaMode.manual,
      status: QiblaStatus.ready,
      place: city,
    );
    final storage = ref.read(browserStorageProvider);
    await storage.setString(modeKey, QiblaMode.manual.name);
    await storage.setString(cityKey, city.encode());
  }

  /// Manual without a city yet (the chooser opened from a refusal).
  void useManual() {
    if (state.mode == QiblaMode.manual && state.place != null) return;
    state = const QiblaState(
      mode: QiblaMode.manual,
      status: QiblaStatus.needsCity,
    );
  }
}

final qiblaControllerProvider =
    NotifierProvider.autoDispose<QiblaController, QiblaState>(
      QiblaController.new,
    );
