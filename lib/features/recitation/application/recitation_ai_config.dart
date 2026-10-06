import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../ai/domain/offline_recitation.dart';
import '../../../core/core_providers.dart';

export '../../../ai/domain/offline_recitation.dart';

/// Where the Quran acoustic model runs.
enum QuranAcousticBackend {
  /// On this device (Android: ONNX Runtime). The product direction.
  local,

  /// `tool/acoustic_verification/server.py` — development and reference
  /// only; never with [recitationOfflineProvider].
  remoteDevelopment,

  /// No pronunciation checking.
  disabled,
}

/// What follows the reciter through the Quran.
enum RecitationPositionSource {
  /// The acoustic model's frames (`LocalQuranPositionTracker`): offline.
  acoustic,

  /// A speech recognizer's text (Google on Android, Web Speech in the
  /// browser) through `QuranStreamMatcher`.
  speechRecognizer,
}

/// [offlineRecitation] (`TAHFEEZ_OFFLINE_RECITATION=true`): anything that
/// would use the network for recitation is refused loudly
/// ([OfflineRecitationViolation]), never silently allowed.
final recitationOfflineProvider = Provider<bool>((ref) => offlineRecitation);

/// How recitation AI is set up for this run, and what (if anything) is
/// wrong with that.
class RecitationAiConfig {
  const RecitationAiConfig({
    required this.acoustic,
    required this.position,
    required this.speechComparator,
    required this.offline,
    this.violation,
  });

  final QuranAcousticBackend acoustic;
  final RecitationPositionSource position;

  /// Run the speech recognizer beside the acoustic tracker, for comparing
  /// positions in the developer panel (not used for anything else).
  final bool speechComparator;
  final bool offline;

  /// What the configuration asked for that offline mode forbids; such a
  /// part is not run.
  final String? violation;

  /// Whether the speech recognizer (Google / Web Speech) runs at all.
  bool get speechRecognizerRuns =>
      !offline &&
      (position == RecitationPositionSource.speechRecognizer ||
          speechComparator);

  String get label =>
      '${acoustic.name} model · position ${position.name}'
      '${speechComparator ? ' (+speech comparator)' : ''}'
      '${offline ? ' · OFFLINE' : ''}';
}

/// From `--dart-define`s, with defaults per platform:
/// - `TAHFEEZ_ACOUSTIC_BACKEND` = `local` | `remote` | `disabled`.
///   Default: `local` on Android; on the web (no local model yet)
///   `remote` in development builds, else `disabled`.
/// - `TAHFEEZ_POSITION_SOURCE` = `acoustic` | `speech`. Default: `acoustic`
///   with the local backend, else `speech`.
/// - `TAHFEEZ_SPEECH_COMPARATOR` = `true` runs the speech recognizer
///   beside the acoustic tracker (developer comparison).
final recitationAiConfigProvider = Provider<RecitationAiConfig>((ref) {
  const backendName = String.fromEnvironment('TAHFEEZ_ACOUSTIC_BACKEND');
  const positionName = String.fromEnvironment('TAHFEEZ_POSITION_SOURCE');
  const comparator = bool.fromEnvironment('TAHFEEZ_SPEECH_COMPARATOR');
  final offline = ref.watch(recitationOfflineProvider);
  final android = ref.watch(platformCapabilitiesProvider).isAndroid;
  return resolveRecitationAiConfig(
    backendName: backendName,
    positionName: positionName,
    comparator: comparator,
    offline: offline,
    android: android,
    release: kReleaseMode,
  );
});

/// [recitationAiConfigProvider]'s rules (separate for tests).
RecitationAiConfig resolveRecitationAiConfig({
  required String backendName,
  required String positionName,
  required bool comparator,
  required bool offline,
  required bool android,
  required bool release,
}) {
  final violations = <String>[];
  var acoustic = switch (backendName) {
    'local' => QuranAcousticBackend.local,
    'remote' => QuranAcousticBackend.remoteDevelopment,
    'disabled' => QuranAcousticBackend.disabled,
    '' =>
      android
          ? QuranAcousticBackend.local
          : release || offline
          ? QuranAcousticBackend.disabled
          : QuranAcousticBackend.remoteDevelopment,
    _ => throw ArgumentError('TAHFEEZ_ACOUSTIC_BACKEND=$backendName'),
  };
  if (offline && acoustic == QuranAcousticBackend.remoteDevelopment) {
    violations.add('the remote acoustic model');
    acoustic = QuranAcousticBackend.disabled;
  }
  final position = switch (positionName) {
    'acoustic' => RecitationPositionSource.acoustic,
    'speech' => RecitationPositionSource.speechRecognizer,
    '' =>
      acoustic == QuranAcousticBackend.local || offline
          ? RecitationPositionSource.acoustic
          : RecitationPositionSource.speechRecognizer,
    _ => throw ArgumentError('TAHFEEZ_POSITION_SOURCE=$positionName'),
  };
  if (offline && position == RecitationPositionSource.speechRecognizer) {
    violations.add('the speech recognizer (Google / Web Speech)');
  }
  if (offline && comparator) {
    violations.add('the speech comparator (Google / Web Speech)');
  }
  return RecitationAiConfig(
    acoustic: acoustic,
    position: position,
    speechComparator: comparator && !offline,
    offline: offline,
    violation: violations.isEmpty
        ? null
        : 'Offline mode refused ${violations.join(' and ')}',
  );
}
