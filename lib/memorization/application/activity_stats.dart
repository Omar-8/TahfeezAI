import 'dart:async';
import 'dart:convert';

import 'package:flutter/widgets.dart' show AppLifecycleListener;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/storage/storage_providers.dart';

/// Lifetime activity, for the Progress screen: ayahs and words recited
/// (heard recited, not revealed by hand), ayahs listened to, and the time
/// a Mushaf was open.
class ActivityStats {
  const ActivityStats({
    this.recitedAyahs = 0,
    this.recitedWords = 0,
    this.heardAyahs = 0,
    this.mushafSeconds = 0,
  });

  final int recitedAyahs, recitedWords, heardAyahs, mushafSeconds;

  ActivityStats add({
    int recitedAyahs = 0,
    int recitedWords = 0,
    int heardAyahs = 0,
    int mushafSeconds = 0,
  }) => ActivityStats(
    recitedAyahs: this.recitedAyahs + recitedAyahs,
    recitedWords: this.recitedWords + recitedWords,
    heardAyahs: this.heardAyahs + heardAyahs,
    mushafSeconds: this.mushafSeconds + mushafSeconds,
  );

  Map<String, int> toJson() => {
    'recitedAyahs': recitedAyahs,
    'recitedWords': recitedWords,
    'heardAyahs': heardAyahs,
    'mushafSeconds': mushafSeconds,
  };

  static ActivityStats fromJson(Object? json) {
    if (json is! Map) return const ActivityStats();
    int n(String key) => json[key] is int ? json[key] as int : 0;
    return ActivityStats(
      recitedAyahs: n('recitedAyahs'),
      recitedWords: n('recitedWords'),
      heardAyahs: n('heardAyahs'),
      mushafSeconds: n('mushafSeconds'),
    );
  }
}

/// Counts [ActivityStats] — a few additions, saved with the settings (so a
/// backup carries them). The Mushaf's open time is measured from when one
/// is shown ([mushafShown]) to when it is left or the app goes to the
/// background; nothing runs meanwhile.
class ActivityStatsController extends Notifier<ActivityStats> {
  static const storageKey = 'activity.stats.v1';

  /// Counted before the saved totals arrived: added to them.
  var _pending = const ActivityStats();
  var _restored = false;
  Timer? _save;

  DateTime? _mushafSince;
  var _mushafOpen = false;
  AppLifecycleListener? _lifecycle;

  @override
  ActivityStats build() {
    _lifecycle = AppLifecycleListener(
      onHide: _pauseMushaf,
      onShow: () {
        if (_mushafOpen) _mushafSince ??= DateTime.now();
      },
    );
    ref.onDispose(() {
      _pauseMushaf();
      _save?.cancel();
      _lifecycle?.dispose();
    });
    unawaited(_restore());
    return const ActivityStats();
  }

  Future<void> _restore() async {
    try {
      final raw = await ref.read(browserStorageProvider).getString(storageKey);
      if (!ref.mounted) return;
      final saved = raw == null
          ? const ActivityStats()
          : ActivityStats.fromJson(jsonDecode(raw));
      _restored = true;
      final p = _pending;
      state = saved.add(
        recitedAyahs: p.recitedAyahs,
        recitedWords: p.recitedWords,
        heardAyahs: p.heardAyahs,
        mushafSeconds: p.mushafSeconds,
      );
      _pending = const ActivityStats();
    } catch (_) {
      _restored = true;
    }
  }

  void add({
    int recitedAyahs = 0,
    int recitedWords = 0,
    int heardAyahs = 0,
    int mushafSeconds = 0,
  }) {
    if (!_restored) {
      _pending = _pending.add(
        recitedAyahs: recitedAyahs,
        recitedWords: recitedWords,
        heardAyahs: heardAyahs,
        mushafSeconds: mushafSeconds,
      );
      return;
    }
    state = state.add(
      recitedAyahs: recitedAyahs,
      recitedWords: recitedWords,
      heardAyahs: heardAyahs,
      mushafSeconds: mushafSeconds,
    );
    // Saved a moment later, so a run of additions is one write.
    _save?.cancel();
    _save = Timer(const Duration(seconds: 2), () {
      if (!ref.mounted) return;
      unawaited(
        ref
            .read(browserStorageProvider)
            .setString(storageKey, jsonEncode(state.toJson())),
      );
    });
  }

  /// A Mushaf is on screen ([shown]) or no longer.
  void mushafShown(bool shown) {
    if (shown == _mushafOpen) return;
    _mushafOpen = shown;
    if (shown) {
      _mushafSince = DateTime.now();
    } else {
      _pauseMushaf();
    }
  }

  void _pauseMushaf() {
    final since = _mushafSince;
    _mushafSince = null;
    if (since == null) return;
    final seconds = DateTime.now().difference(since).inSeconds;
    if (seconds > 0) add(mushafSeconds: seconds);
  }
}

final activityStatsProvider =
    NotifierProvider<ActivityStatsController, ActivityStats>(
      ActivityStatsController.new,
    );
