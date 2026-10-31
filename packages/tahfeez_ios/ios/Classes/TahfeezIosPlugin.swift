import AudioToolbox
import Flutter
import UIKit

/// TahfeezAI's own channels on iOS (Android: MainActivity.kt and
/// QuranAcousticModelChannel.kt, BundledDatabaseChannel.kt): the acoustic
/// model, the ready-made Quran databases, the mistake alert and keeping the
/// screen on while the on-device recitation AI listens.
public class TahfeezIosPlugin: NSObject, FlutterPlugin {
  public static func register(with registrar: FlutterPluginRegistrar) {
    let messenger = registrar.messenger()
    QuranAcousticModelChannel.attach(messenger)
    BundledDatabaseChannel.attach(messenger)

    FlutterMethodChannel(name: "tahfeez/screen", binaryMessenger: messenger)
      .setMethodCallHandler { call, result in
        guard call.method == "keepOn" else {
          result(FlutterMethodNotImplemented)
          return
        }
        UIApplication.shared.isIdleTimerDisabled = (call.arguments as? Bool) == true
        result(nil)
      }

    // A recitation mistake noticed: a short haptic, or a soft beep.
    let haptic = UINotificationFeedbackGenerator()
    FlutterMethodChannel(name: "tahfeez/alert", binaryMessenger: messenger)
      .setMethodCallHandler { call, result in
        switch call.method {
        case "vibrate":
          // The length (ms) is Android's; iOS plays its own error pattern.
          haptic.notificationOccurred(.error)
          result(nil)
        case "beep":
          // A short system tock (follows the ringer switch).
          AudioServicesPlaySystemSound(1104)
          result(nil)
        default:
          result(FlutterMethodNotImplemented)
        }
      }
  }
}
