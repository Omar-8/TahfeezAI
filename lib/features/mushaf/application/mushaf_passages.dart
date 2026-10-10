import 'dart:async';
import 'dart:ui' show Color;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/storage/storage_providers.dart';
import '../../../quran/quran_providers.dart';

/// Mushaf appearance → "Colour thematic passages": each rukūʿ (Tanzil's
/// thematic sections, `docs/QURAN_DATA_PROVENANCE.md` §2) tinted on the
/// page, next to a different tint. Off by default; persisted.
class MushafPassagesController extends Notifier<bool> {
  static const storageKey = 'mushaf.passages';

  @override
  bool build() {
    unawaited(_restore());
    return false;
  }

  Future<void> _restore() async {
    final stored = await ref.read(browserStorageProvider).getBool(storageKey);
    if (stored != null && ref.mounted) state = stored;
  }

  Future<void> set(bool on) async {
    state = on;
    await ref.read(browserStorageProvider).setBool(storageKey, on);
  }
}

final mushafPassagesProvider = NotifierProvider<MushafPassagesController, bool>(
  MushafPassagesController.new,
);

/// The passage tints: bright and easy to tell apart, still see-through,
/// and clear of the blue of the recited ayah (drawn instead of them).
const passagePalette = [
  Color(0x5543A047), // green
  Color(0x55FDD835), // yellow
  Color(0x558D6E63), // brown
  Color(0x55FB8C00), // orange
  Color(0x55EC407A), // pink
];

/// Each passage's tint from its rukūʿ number: scattered over the palette,
/// never the same as the passage before it.
List<int> passageTints(int passages) {
  final tints = <int>[];
  for (var n = 1; n <= passages; n++) {
    // A fixed scramble (the same colours every time), not Random.
    var tint = (n * 7 + n ~/ 3) % passagePalette.length;
    if (tints.isNotEmpty && tint == tints.last) {
      tint = (tint + 1) % passagePalette.length;
    }
    tints.add(tint);
  }
  return tints;
}

/// Every ayah's passage tint (ayah id → [passagePalette] colour), from the
/// installed Quran's rukūʿ numbers. Loaded once, on first use.
final passageColorsProvider = FutureProvider<Map<int, Color>>((ref) async {
  final repository = ref.watch(quranRepositoryProvider);
  final ruku = <int, int>{};
  for (final surah in await repository.getAllSurahs()) {
    final ayahs = await repository.getVerseRange((
      chapterNo: surah.surahNo,
      fromVerseNo: 1,
      toVerseNo: surah.ayahCount,
    ));
    for (final a in ayahs) {
      ruku[a.id] = a.rukuNo;
    }
  }
  if (ruku.isEmpty) return const {};
  final tints = passageTints(ruku.values.reduce((a, b) => a > b ? a : b));
  return {
    for (final MapEntry(key: ayah, value: n) in ruku.entries)
      ayah: passagePalette[tints[n - 1]],
  };
});
