import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'hifz_controller.dart';

/// The ayahs of prostration (Sujood al-Tilawah) marked in the Madani
/// Mushaf — Tanzil's Quran metadata (`quran-data.xml`, `<sajdas>`), as
/// stable ayah ids (surah × 1000 + ayah).
const sajdahAyahs = {
  7206, 13015, 16050, 17109, 19058, 22018, 22077, 25060, //
  27026, 32015, 38024, 41038, 53062, 84021, 96019,
};

/// Whether the reminder has been shown this app session (outliving the
/// provider, which goes with the Mushaf).
var _shown = false;

/// Shows the reminder again (tests).
void resetSajdahReminderForTest() => _shown = false;

/// An ayah of prostration has just been recited (every word of it judged,
/// the reciter past it): its id, for a reminder of Sujood al-Tilawah —
/// once per app session, and only with Hifz settings' reminder on.
class SajdahReminder extends Notifier<int?> {
  @override
  int? build() {
    ref.listen(hifzControllerProvider, (_, next) {
      if (_shown || !next.active) return;
      if (!ref.read(hifzSettingsProvider).sajdahReminder) return;
      final hifz = ref.read(hifzControllerProvider.notifier);
      for (final ayah in sajdahAyahs) {
        // Recited, and the reciter past it (or the test done).
        if (!hifz.recitedIn(ayah)) continue;
        if (!next.completed && next.expected?.ayahId == ayah) continue;
        _shown = true;
        state = ayah;
        return;
      }
    });
    return null;
  }
}

final sajdahReminderProvider =
    NotifierProvider.autoDispose<SajdahReminder, int?>(SajdahReminder.new);
