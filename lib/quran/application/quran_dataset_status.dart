import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../quran_providers.dart';

part 'quran_dataset_status.g.dart';

/// Whether a Quran dataset is actually installed in the running app.
///
/// The Quran database has real plumbing (Milestone 2) but no app-boot
/// import step wires an actual dataset into it yet — see
/// `docs/ARCHITECTURE.md` §11b and `docs/DATA_RESOURCE_REQUIREMENTS.md`.
/// Every screen that reads Quran content (Home's sections, the Quran
/// index) checks this first and renders an "unavailable resource" state
/// when it's `false`, rather than showing broken or fabricated content —
/// this is a shared `quran`-level concern precisely because more than one
/// feature needs the same check; per `docs/ARCHITECTURE.md` §1, feature
/// areas must not depend on each other directly, so this lives alongside
/// `quranRepositoryProvider` instead of under any one feature.
@riverpod
Future<bool> hasInstalledQuranDataset(Ref ref) async {
  final repository = ref.watch(quranRepositoryProvider);
  final surah = await repository.getSurah(1);
  return surah != null;
}
