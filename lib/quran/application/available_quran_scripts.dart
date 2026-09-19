import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../domain/models/script_models.dart';
import '../quran_providers.dart';

part 'available_quran_scripts.g.dart';

/// Every [QuranScript] the currently installed dataset provides — empty in
/// the shipped app today, the same "no real dataset import path exists yet"
/// gap every Quran-data-dependent screen already confronts honestly
/// (`docs/ARCHITECTURE.md` §11b). A script picker (Milestone 8) watches
/// this to list real choices instead of a hardcoded roster.
@riverpod
Future<List<QuranScript>> availableQuranScripts(Ref ref) {
  return ref.watch(quranRepositoryProvider).getAllScripts();
}
