import 'package:tahfeez_ai/core/platform/platform_capabilities.dart';

/// The app as in a browser (platformCapabilitiesProvider).
class WebPlatform implements PlatformCapabilities {
  const WebPlatform();
  @override
  bool get isWeb => true;
  @override
  bool get isAndroid => false;
  @override
  bool get isIOS => false;
  @override
  bool get supportsBackgroundAudioSession => false;
  @override
  bool get supportsHomeScreenWidgets => false;
  @override
  bool get supportsScheduledNotifications => false;
  @override
  bool get supportsNativeFileStorage => false;
}
