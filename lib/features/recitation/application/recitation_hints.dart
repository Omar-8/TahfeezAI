import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/storage/browser_storage.dart';
import 'hifz_controller.dart';

/// A tip after one of the first recitations, when the check marked much
/// of it: most likely the reciter is still learning tajweed, or the check
/// is stricter than their recitation needs.
enum RecitationHint {
  /// Many tajweed rules not kept: tajweed checking can be turned off.
  tajweedOff,

  /// Many vowels marked: pronunciation strictness can be made lenient.
  lenient,
}

/// The tip [tally] calls for under [settings], if any: a share of the
/// checked words marked — [minShare], and at least [minWords] — with
/// tajweed mistakes (tajweed checked), else with vowel mistakes (not
/// lenient already).
RecitationHint? recitationHintFor(
  ({int checked, int tajweed, int vowels}) tally,
  HifzSettings settings, {
  Set<RecitationHint> shown = const {},
}) {
  bool many(int n) => n >= minWords && n >= tally.checked * minShare;
  if (settings.tajweed &&
      !shown.contains(RecitationHint.tajweedOff) &&
      many(tally.tajweed)) {
    return RecitationHint.tajweedOff;
  }
  if (settings.strictness != RecitationStrictness.lenient &&
      !shown.contains(RecitationHint.lenient) &&
      many(tally.vowels)) {
    return RecitationHint.lenient;
  }
  return null;
}

const minWords = 4;
const minShare = 0.2;

/// A recitation counts towards the first ones with this many words
/// checked (a recitation stopped at once does not).
const countedWords = 8;

/// The first recitations given a tip.
const hintedRecitations = 2;

/// After a recitation: its tip, if it is one of the first
/// [hintedRecitations] and calls for one not given before. Each tip is
/// given once; the count and the tips given are kept on the device.
Future<RecitationHint?> recitationHintAfter(
  BrowserStorage storage,
  HifzSettings settings,
  ({int checked, int tajweed, int vowels}) tally,
) async {
  if (tally.checked < countedWords) return null;
  final done = int.tryParse(await storage.getString(_countKey) ?? '') ?? 0;
  if (done >= hintedRecitations) return null;
  await storage.setString(_countKey, '${done + 1}');
  final shown = {
    for (final h in RecitationHint.values)
      if (await storage.getBool('$_shownKey.${h.name}') ?? false) h,
  };
  final hint = recitationHintFor(tally, settings, shown: shown);
  if (hint != null) await storage.setBool('$_shownKey.${hint.name}', true);
  return hint;
}

const _countKey = 'recitationHints.recitations';
const _shownKey = 'recitationHints.shown';

/// What the tip's button does: tajweed checking off, or lenient.
void applyRecitationHint(WidgetRef ref, RecitationHint hint) {
  final settings = ref.read(hifzSettingsProvider);
  ref.read(hifzSettingsProvider.notifier).update(switch (hint) {
    RecitationHint.tajweedOff => settings.copyWith(tajweed: false),
    RecitationHint.lenient => settings.copyWith(
      strictness: RecitationStrictness.lenient,
    ),
  });
}
