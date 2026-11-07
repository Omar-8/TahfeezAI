import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../storage/storage_providers.dart';
import '../../quran/domain/quran_location_path.dart';
import 'app_routes.dart';
import 'quran_location_routing.dart';

/// The screen the app was last on: saved as it changes, opened again when
/// the app starts — the phone may have closed the app in the background
/// (its memory wanted elsewhere), and the reader comes back to where they
/// were, not to Home. Settings → Reset all data clears it with the rest.
const lastScreenKey = 'app.lastScreen';

/// The screen to open at start (read before the app shows), if any.
class RestoredScreen extends Notifier<String?> {
  @override
  String? build() => null;

  void set(String? location) => state = location;
}

final restoredScreenProvider = NotifierProvider<RestoredScreen, String?>(
  RestoredScreen.new,
);

/// Reads the last screen saved into [restoredScreenProvider]; never fails
/// (none: Home).
Future<void> loadLastScreen(ProviderContainer container) async {
  try {
    final saved = await container
        .read(browserStorageProvider)
        .getString(lastScreenKey);
    container
        .read(restoredScreenProvider.notifier)
        .set(restorableScreen(saved) ? saved : null);
  } catch (_) {
    // Home.
  }
}

/// Whether [location] is one of the app's own screens to open again: a
/// tab, one of its screens, or a Quran place (not a debug screen).
bool restorableScreen(String? location) {
  if (location == null || !location.startsWith('/')) return false;
  // A Quran place: whole (a page with its number, an ayah with both).
  if (isQuranLocationPath(location)) {
    final segments = Uri.parse(location).pathSegments;
    return quranLocationFromPath(segments.skip(1).join('/')) != null;
  }
  final path = Uri.tryParse(location)?.path;
  return const {
    AppRoutes.home,
    AppRoutes.quran,
    AppRoutes.search,
    AppRoutes.bookmarks,
    AppRoutes.memorize,
    AppRoutes.settings,
    AppRoutes.about,
  }.contains(path);
}
