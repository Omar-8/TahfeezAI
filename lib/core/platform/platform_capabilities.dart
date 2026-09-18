import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;

/// Centralizes "can this platform do X" checks.
///
/// `CLAUDE.md` asks for "platform adapters rather than platform checks
/// scattered throughout widgets" — this is that boundary. Feature code
/// should ask `platformCapabilities.supportsX`, never `Platform.isAndroid`
/// or `kIsWeb` directly, so every platform assumption in the app lives in
/// one auditable place.
abstract class PlatformCapabilities {
  bool get isWeb;
  bool get isAndroid;
  bool get isIOS;

  /// True where a persistent background audio session with lock-screen/
  /// notification transport controls is realistically achievable (native
  /// mobile). The web player is foreground-tab-only.
  bool get supportsBackgroundAudioSession;

  /// True where OS home-screen widgets (Verse of the Day, mini player) are
  /// a platform concept at all.
  bool get supportsHomeScreenWidgets;

  /// True where exact-time scheduled local notifications (the Daily
  /// Reminder / Verse of the Day reminder) are supported without an
  /// additional runtime permission prompt flow of their own.
  bool get supportsScheduledNotifications;

  /// True where a full native filesystem is available for large downloaded
  /// resources (Quran datasets, audio, atlases). False on the web, where
  /// [BrowserStorage]/a future OPFS-backed strategy is used instead.
  bool get supportsNativeFileStorage;
}

class DefaultPlatformCapabilities implements PlatformCapabilities {
  const DefaultPlatformCapabilities();

  @override
  bool get isWeb => kIsWeb;

  @override
  bool get isAndroid => !kIsWeb && Platform.isAndroid;

  @override
  bool get isIOS => !kIsWeb && Platform.isIOS;

  @override
  bool get supportsBackgroundAudioSession => isAndroid || isIOS;

  @override
  bool get supportsHomeScreenWidgets => isAndroid || isIOS;

  @override
  bool get supportsScheduledNotifications => isAndroid || isIOS;

  @override
  bool get supportsNativeFileStorage => !isWeb;
}
