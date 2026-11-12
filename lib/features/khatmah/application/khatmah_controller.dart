import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/storage/storage_providers.dart';
import '../../../core/ui/full_bleed_content.dart';
import '../../../memorization/application/memorization_progress.dart'
    show milestoneProvider;
import '../../../memorization/domain/milestones.dart' show KhatmahMilestone;
import '../../../memorization/application/memorization_today.dart'
    show memorizationClockProvider;
import '../../../quran/domain/models/quran_location.dart';
import '../../mushaf/application/mushaf_hide_mode.dart' show firstVisiblePage;
import '../../recitation/application/mushaf_recitation_target.dart';
import '../domain/khatmah.dart';

const _key = 'khatmah.v1';

/// The khatmah in progress (`null`: none), kept in the app's storage (so a
/// backup carries it). A page on screen for [dwell] counts as read — both
/// pages of a two-page spread — so turning past pages doesn't.
class KhatmahController extends AsyncNotifier<Khatmah?> {
  /// How long a page stays on screen to count as read.
  static const dwell = Duration(seconds: 20);

  Timer? _timer;

  String get _today => khatmahDay(ref.read(memorizationClockProvider)());

  @override
  Future<Khatmah?> build() async {
    ref.onDispose(() => _timer?.cancel());
    ref.listen(
      mushafRecitationTargetProvider.select((t) => t?.location),
      (_, location) => _onScreen(location),
      fireImmediately: true,
    );
    final stored = await ref.read(browserStorageProvider).getString(_key);
    if (stored == null) return null;
    try {
      return Khatmah.fromJson(jsonDecode(stored));
    } on FormatException {
      return null;
    }
  }

  /// [location] on screen: its page(s) read once there for [dwell].
  void _onScreen(QuranLocation? location) {
    _timer?.cancel();
    _timer = null;
    if (location is! QuranLocationPage) return;
    final spread = ref.read(fullBleedContentProvider);
    final first = firstVisiblePage(location.pageNumber, spread: spread);
    final pages = spread ? [first, first + 1] : [location.pageNumber];
    _timer = Timer(dwell, () => read(pages));
  }

  Future<void> _save(Khatmah? khatmah) async {
    final before = state.value;
    state = AsyncData(khatmah);
    // Its last page read: celebrated, over whatever is on screen.
    if (khatmah != null &&
        before?.start == khatmah.start &&
        before!.readOn.length < khatmah.total &&
        khatmah.readOn.length >= khatmah.total) {
      ref
          .read(milestoneProvider.notifier)
          .celebrate(KhatmahMilestone(khatmah.start));
    }
    final storage = ref.read(browserStorageProvider);
    if (khatmah == null) {
      await storage.remove(_key);
    } else {
      await storage.setString(_key, jsonEncode(khatmah.toJson()));
    }
  }

  /// A new khatmah from today, to finish in [days] days (any before it
  /// replaced).
  Future<void> start(int days) =>
      _save(Khatmah(start: _today, days: days.clamp(1, 3650)));

  /// The khatmah to finish in [days] days from its start.
  Future<void> setDays(int days) async {
    final k = await future;
    if (k != null) await _save(k.copyWith(days: days.clamp(1, 3650)));
  }

  /// [pages] read today (no khatmah: nothing).
  Future<void> read(Iterable<int> pages) async {
    final k = await future;
    if (k == null) return;
    final next = k.reading(pages, _today);
    if (!identical(next, k)) await _save(next);
  }

  /// Every page up to [page] read (on paper, elsewhere).
  Future<void> readThrough(int page) async {
    final k = await future;
    if (k != null) await _save(k.readThrough(page, _today));
  }

  Future<void> end() => _save(null);
}

final khatmahProvider = AsyncNotifierProvider<KhatmahController, Khatmah?>(
  KhatmahController.new,
);

/// Today's share of the khatmah; `null` without one.
final khatmahTodayProvider = Provider<KhatmahToday?>((ref) {
  final k = ref.watch(khatmahProvider).value;
  if (k == null) return null;
  return k.today(khatmahDay(ref.read(memorizationClockProvider)()));
});
