import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../listen/application/listen_options.dart' show SavedJsonController;
import 'hifz_controller.dart';

/// Loop recitation's settings as last started (its menu, or the bar's
/// quick start): how it repeats and how many times. Saved, as Listen's and
/// Follow along's are. (Strict is the Hifz settings' own.)
class LoopOptionsController extends SavedJsonController<HifzLoop> {
  @override
  String get storageKey => 'loop.options';

  @override
  Object toJson(HifzLoop value) => {
    'mode': value.mode.name,
    'count': value.count,
    'perAyah': value.perAyah,
  };

  @override
  HifzLoop fromJson(Object? json) {
    if (json is! Map) return const HifzLoop();
    int count(String key, int fallback) => json[key] is int
        ? (json[key] as int).clamp(1, HifzLoop.maxCount)
        : fallback;
    return HifzLoop(
      mode:
          HifzLoopMode.values.asNameMap()[json['mode']] ??
          HifzLoopMode.eachAyah,
      count: count('count', 3),
      perAyah: count('perAyah', 1),
    );
  }

  @override
  HifzLoop build() {
    restore();
    return const HifzLoop();
  }

  void set(HifzLoop loop) => save(loop);
}

final loopOptionsProvider = NotifierProvider<LoopOptionsController, HifzLoop>(
  LoopOptionsController.new,
);
