import 'dart:async';

import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';
import 'package:tahfeez_ai/core/theme/components/quran_mark.dart';
import 'package:tahfeez_ai/features/qibla/presentation/calibration_hint.dart';

/// Global test setup, automatically picked up by the Flutter test runner for
/// every test file under `test/`.
///
/// [SharedPreferencesBrowserStorage] (`lib/core/storage/browser_storage.dart`)
/// needs a platform implementation registered before use; in tests there is
/// no real platform channel, so we install the package's own in-memory fake
/// once for the whole suite instead of duplicating this in every test file.
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  SharedPreferencesAsyncPlatform.instance =
      InMemorySharedPreferencesAsync.empty();
  // The Qibla screen's figure 8 goes round without end in the app: in
  // rounds here, so screens showing it settle (its own test checks both).
  CalibrationHint.endless = false;
  // …and the Quran tab's arc going round (its own test checks it).
  QuranMark.spinning = false;
  await testMain();
}
