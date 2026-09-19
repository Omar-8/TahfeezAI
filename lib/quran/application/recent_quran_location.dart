import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../core/storage/storage_providers.dart';
import '../domain/models/quran_location.dart';
import '../domain/quran_location_path.dart';

part 'recent_quran_location.g.dart';

const _recentQuranLocationPrefKey = 'quran.recent_location';

/// The last [QuranLocation] the user navigated to — from the Quran index
/// (Milestone 5) or by reading in the Reader (Milestone 6) — persisted via
/// `BrowserStorage` so it survives app restarts. `null` means none has been
/// recorded yet.
///
/// Lives under `quran/application` (not one feature's `application/`
/// folder) because more than one feature area writes to and reads from it:
/// the Quran index's "Jump back in" chip and the Reader's "last read"
/// restoration are the same underlying concept, and per
/// `docs/ARCHITECTURE.md` §1 feature areas must not depend on each other
/// directly.
@Riverpod(keepAlive: true)
class RecentQuranLocationController extends _$RecentQuranLocationController {
  @override
  QuranLocation? build() {
    _restore();
    return null;
  }

  Future<void> _restore() async {
    final stored = await ref
        .read(browserStorageProvider)
        .getString(_recentQuranLocationPrefKey);
    if (stored == null) return;
    final location = quranLocationFromPath(stored);
    if (location != null) {
      state = location;
    }
  }

  Future<void> record(QuranLocation location) async {
    state = location;
    await ref
        .read(browserStorageProvider)
        .setString(_recentQuranLocationPrefKey, quranLocationPath(location));
  }
}
