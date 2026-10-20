import 'package:flutter/foundation.dart' show kReleaseMode;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/core_providers.dart';
import '../../../core/storage/storage_providers.dart';
import '../data/browser_storage_recitation_session_repository.dart';
import '../data/platform_recitation_recording_store.dart';
import '../data/record_audio_source.dart';
import '../domain/recitation_audio_source.dart';
import '../domain/recitation_recording_store.dart';
import '../domain/recitation_session.dart';
import 'hifz_controller.dart' show hifzSettingsProvider;

/// Live recitation: Android, iOS (its microphone usage string in
/// Info.plist) and the web.
final recitationSupportedProvider = Provider<bool>((ref) {
  final capabilities = ref.watch(platformCapabilitiesProvider);
  return capabilities.isAndroid || capabilities.isIOS || capabilities.isWeb;
});

/// Creates a fresh microphone source per session controller. A factory,
/// not an instance, so the controller owns — and disposes — its source only
/// after it has finished writing the recording.
final recitationAudioSourceFactoryProvider =
    Provider<RecitationAudioSource Function()>(
      (ref) =>
          () => RecordPackageAudioSource(
            processing: ref.read(hifzSettingsProvider).micProcessing,
          ),
    );

final recitationRecordingStoreProvider = Provider<RecitationRecordingStore>(
  (ref) => createPlatformRecordingStore(
    ref.watch(fileStorageProvider),
    developerExport: ref.watch(recitationKeepRecordingsProvider),
  ),
);

final recitationSessionRepositoryProvider =
    Provider<RecitationSessionRepository>(
      (ref) => BrowserStorageRecitationSessionRepository(
        ref.watch(browserStorageProvider),
      ),
    );

/// Wall-clock source for session timestamps; overridden in tests.
final recitationClockProvider = Provider<DateTime Function()>(
  (ref) => DateTime.now,
);

/// Whether sessions are recorded to a file and saved to the session
/// history. Off: recitation is only listened to live (recognition, Hifz)
/// and nothing is stored once the session ends.
///
/// Development only: `--dart-define=TAHFEEZ_KEEP_RECORDINGS=true` keeps each
/// session's audio on the device, in the app's external files directory
/// (`Android/data/<package>/files/recitations`, readable with adb), to
/// diagnose on-device accuracy. Nothing is uploaded. A release build never
/// keeps them, whatever it is passed (docs/PRIVACY_POLICY.md).
final recitationKeepRecordingsProvider = Provider<bool>(
  (ref) =>
      !kReleaseMode && const bool.fromEnvironment('TAHFEEZ_KEEP_RECORDINGS'),
);
