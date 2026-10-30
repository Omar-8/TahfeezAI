import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/platform/device_summary.dart';
import '../quran_providers.dart';

/// Setting up the bundled Quran on this phone (BundledDatasetSeeder, at the
/// first start): whether it failed, and why — so the screens that need the
/// Quran say so, offer to try again and to share the error, instead of
/// waiting for a dataset that never comes.
class QuranSetupState {
  const QuranSetupState({this.failure, this.retrying = false});

  /// What went wrong (the error as logged); `null`: set up, or not yet run.
  final String? failure;
  final bool retrying;

  /// The phone's storage full: the one cause the user can fix themselves.
  bool get storageFull =>
      failure != null &&
      RegExp(
        r'SQLITE_FULL|disk is full|No space left|ENOSPC|errno = 28',
        caseSensitive: false,
      ).hasMatch(failure!);
}

class QuranSetupController extends Notifier<QuranSetupState> {
  Future<String?> Function()? _seed;

  @override
  QuranSetupState build() => const QuranSetupState();

  /// Runs [seed] (it returns the failure, `null` when all is well) and
  /// keeps it for [retry].
  Future<void> run(Future<String?> Function() seed) async {
    _seed = seed;
    final failure = await _guarded(seed);
    if (ref.mounted) state = QuranSetupState(failure: failure);
  }

  /// Runs the setup again; when it works, the screens read the Quran anew.
  Future<void> retry() async {
    final seed = _seed;
    if (seed == null || state.retrying) return;
    state = QuranSetupState(failure: state.failure, retrying: true);
    final failure = await _guarded(seed);
    if (!ref.mounted) return;
    state = QuranSetupState(failure: failure);
    if (failure == null) ref.invalidate(quranRepositoryProvider);
  }

  static Future<String?> _guarded(Future<String?> Function() seed) async {
    try {
      return await seed();
    } catch (e) {
      return '$e';
    }
  }
}

final quranSetupProvider =
    NotifierProvider<QuranSetupController, QuranSetupState>(
      QuranSetupController.new,
    );

/// The failure as a tester would send it: the app's version, the device,
/// the error.
String quranSetupReport(String failure, {required String version}) =>
    'Tahfeez AI $version — the Qur\'an could not be set up\n'
    '${deviceSummary()}\n'
    '$failure';
