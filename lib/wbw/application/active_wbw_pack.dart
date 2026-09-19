import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../domain/models/wbw_models.dart';
import '../wbw_providers.dart';
import 'wbw_preferences_controller.dart';

part 'active_wbw_pack.g.dart';

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
  if (selectedId == null) return null;
  return ref.watch(wbwRepositoryProvider).getInstalledPack(selectedId);
}
