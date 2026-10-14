import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../core/localization/locale_controller.dart';
import '../../quran/application/meaning_defaults.dart';
import '../domain/models/wbw_models.dart';
import '../wbw_providers.dart';
import 'wbw_preferences_controller.dart';

part 'active_wbw_pack.g.dart';

/// The bundled English pack: the transliteration, and any word another
/// language's pack has no meaning for.
const englishWbwPackId = 'en-qurancom';

/// The WBW pack the word detail sheet should resolve translations from, or
/// `null` if word-by-word content is unavailable — either because the user
/// has never selected a pack, or because the previously selected pack id no
/// longer matches anything installed (e.g. it was deleted). Re-validated
/// against [wbwRepositoryProvider] on every read rather than trusting
/// [WbwSelectedPackController]'s stored id blindly, the same defensive shape
/// `RecentQuranLocationController` already uses for a stored value that may
/// reference since-changed data.
@riverpod
Future<WbwLanguagePack?> activeWbwPack(Ref ref) async {
  final selectedId = ref.watch(wbwSelectedPackControllerProvider);
  final repository = ref.watch(wbwRepositoryProvider);
  // (Before any await; and again when the app's language changes.)
  ref.watch(localeControllerProvider);
  final language = meaningLanguage(ref);
  // None chosen: the one in the app's language (else the phone's), else
  // English, else any installed.
  if (selectedId == null) {
    final installed = await repository.getInstalledPacks();
    return installed.where((p) => p.languageCode == language).firstOrNull ??
        installed.where((p) => p.languageCode == 'en').firstOrNull ??
        installed.firstOrNull;
  }
  return repository.getInstalledPack(selectedId);
}
