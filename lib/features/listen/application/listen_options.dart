import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/storage/storage_providers.dart';

/// How a listening run plays (the Mushaf's Listen menu): each ayah's and
/// the whole range's repetitions, following the pages, highlighting the
/// ayah being recited. Saved: the menu opens as last used.
class ListenOptions {
  const ListenOptions({
    this.ayahRepeats = 1,
    this.rangeRepeats = 1,
    this.followPages = true,
    this.highlight = true,
    this.continueToNextSurahs = false,
  });

  final int ayahRepeats, rangeRepeats;
  final bool followPages, highlight;

  /// Once the range is done (at a surah's end), go on to the next surahs.
  final bool continueToNextSurahs;

  ListenOptions copyWith({
    int? ayahRepeats,
    int? rangeRepeats,
    bool? followPages,
    bool? highlight,
    bool? continueToNextSurahs,
  }) => ListenOptions(
    ayahRepeats: ayahRepeats ?? this.ayahRepeats,
    rangeRepeats: rangeRepeats ?? this.rangeRepeats,
    followPages: followPages ?? this.followPages,
    highlight: highlight ?? this.highlight,
    continueToNextSurahs: continueToNextSurahs ?? this.continueToNextSurahs,
  );

  Map<String, Object> toJson() => {
    'ayahRepeats': ayahRepeats,
    'rangeRepeats': rangeRepeats,
    'followPages': followPages,
    'highlight': highlight,
    'continueToNextSurahs': continueToNextSurahs,
  };

  static ListenOptions fromJson(Object? json) {
    if (json is! Map) return const ListenOptions();
    int count(String key) => json[key] is int ? json[key] as int : 1;
    bool flag(String key, bool fallback) =>
        json[key] is bool ? json[key] as bool : fallback;
    return ListenOptions(
      ayahRepeats: count('ayahRepeats'),
      rangeRepeats: count('rangeRepeats'),
      followPages: flag('followPages', true),
      highlight: flag('highlight', true),
      continueToNextSurahs: flag('continueToNextSurahs', false),
    );
  }
}

/// A saved setting restored on first use — unless it was set before the
/// stored value arrived.
mixin _Restored<T> on Notifier<T> {
  var _set = false;

  String get storageKey;
  T decode(String raw);
  String encode(T value);

  void restore() => unawaited(() async {
    try {
      final raw = await ref.read(browserStorageProvider).getString(storageKey);
      if (raw != null && !_set && ref.mounted) state = decode(raw);
    } catch (_) {
      // Defaults.
    }
  }());

  void save(T value) {
    _set = true;
    state = value;
    unawaited(
      ref.read(browserStorageProvider).setString(storageKey, encode(value)),
    );
  }
}

class ListenOptionsController extends Notifier<ListenOptions>
    with _Restored<ListenOptions> {
  @override
  String get storageKey => 'listen.options';
  @override
  ListenOptions decode(String raw) => ListenOptions.fromJson(jsonDecode(raw));
  @override
  String encode(ListenOptions value) => jsonEncode(value.toJson());

  @override
  ListenOptions build() {
    restore();
    return const ListenOptions();
  }

  void set(ListenOptions options) => save(options);
}

final listenOptionsProvider =
    NotifierProvider<ListenOptionsController, ListenOptions>(
      ListenOptionsController.new,
    );

/// Playback speeds offered in the bar, cycled in order.
const listenSpeeds = [0.5, 0.75, 1.0, 1.25, 1.5, 2.0];

/// The reciter's speed everywhere audio plays (the bar's speed button,
/// Follow along's menu, the ayah sheet). Saved.
class ListenSpeedController extends Notifier<double> with _Restored<double> {
  @override
  String get storageKey => 'listen.speed';
  @override
  double decode(String raw) {
    final speed = double.tryParse(raw);
    return speed != null && listenSpeeds.any((s) => (s - speed).abs() < 0.01)
        ? speed
        : 1.0;
  }

  @override
  String encode(double value) => '$value';

  @override
  double build() {
    restore();
    return 1.0;
  }

  void set(double speed) => save(speed);
}

final listenSpeedProvider = NotifierProvider<ListenSpeedController, double>(
  ListenSpeedController.new,
);

/// A setting kept in [browserStorageProvider] under [key], as JSON.
abstract class SavedJsonController<T> extends Notifier<T> with _Restored<T> {
  @override
  String encode(T value) => jsonEncode(toJson(value));
  @override
  T decode(String raw) => fromJson(jsonDecode(raw));

  Object toJson(T value);
  T fromJson(Object? json);
}
