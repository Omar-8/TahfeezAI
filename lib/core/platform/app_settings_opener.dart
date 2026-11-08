import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform, kIsWeb;
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

/// Opens this app's page in the system settings — where a permission
/// refused for good (the microphone) can be allowed again. Android: the
/// app's details page (`MainActivity`); iOS: its Settings page. Elsewhere
/// (a browser: the site's own settings) nothing: false.
class AppSettingsOpener {
  const AppSettingsOpener([
    this._channel = const MethodChannel('tahfeez/screen'),
  ]);

  final MethodChannel _channel;

  /// Whether this platform has such a page.
  static bool get supported =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  Future<bool> open() async {
    if (!supported) return false;
    try {
      if (defaultTargetPlatform == TargetPlatform.iOS) {
        return await launchUrl(Uri.parse('app-settings:'));
      }
      return await _channel.invokeMethod<bool>('appSettings') ?? false;
    } on MissingPluginException {
      return false;
    } on PlatformException {
      return false;
    }
  }
}
