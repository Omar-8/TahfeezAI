# iOS: what is prepared, and the steps on a Mac

Written 2026-10-11 on Linux. **Built and run in CI** (GitHub's Mac
runner, `.github/workflows/ios.yml`, Xcode 26.3): the unsigned iPhone
release build compiles and links (engine, Swift channels, ONNX Runtime),
and on an iPhone simulator the app starts, Home shows, and the Mushaf is
drawn by the native engine; the model channel answers (no model there).
Not yet on a real iPhone (needs signing). Android is untouched (its APK
differs only in the compiled Dart code).

## Prepared

| Part | Where | State |
|---|---|---|
| Mushaf engine (Rust, dart:ffi) | `third_party/qvp_flutter/ios/`, `scripts/build-engine-ios.sh` (patch 0004, `PATCHES.md`) | Needs `qvp_ffi.xcframework` built on a Mac |
| Engine backend chosen on iOS | `mushaf_quran_engine_providers.dart` | The ffi backend (as Android) |
| Acoustic model (ONNX Runtime) | `packages/tahfeez_ios/ios/Classes/QuranAcousticModelChannel.swift` | Port of `QuranAcousticModelChannel.kt`, same channel and methods; CPU, Core ML (`nnapi`/`coreml`) or XNNPACK |
| Mistake alert, screen on | `packages/tahfeez_ios/ios/Classes/TahfeezIosPlugin.swift` | Haptic (`.error`) and a system tock; idle timer off |
| Recitation, on-device AI, mistake alert row | recitation providers, `recitation_ai_config.dart`, Hifz settings | Enabled on iOS as on Android |
| Daily reminder | `daily_reminder_scheduler.dart`, `AppDelegate.swift` | Darwin settings; permission asked when turned on |
| Microphone text, background audio, languages | `ios/Runner/Info.plist` | `NSMicrophoneUsageDescription` (English only so far), `UIBackgroundModes: audio`, six `CFBundleLocalizations` |
| Store | `app_store_service.dart` | No in-app updates on iOS; rating via the in-app prompt; `kAppStoreUrl` empty until the listing exists |

## Steps on the Mac

1. Flutter, Xcode, CocoaPods and rustup installed; this repository cloned.
2. The engine: `bash third_party/qvp_flutter/scripts/build-engine-ios.sh`
   (clones upstream tag `v0.2.2`, the published package's commit).
3. `flutter pub get && cd ios && pod install` (brings `onnxruntime-objc`
   1.30.0, which needs iOS 15.1 — the app's minimum).
4. Signing: open `ios/Runner.xcworkspace`, set the team and bundle id.
5. `flutter run --profile --dart-define=TAHFEEZ_KEEP_RECORDINGS=true` on
   an iPhone.
6. The acoustic model is bundled (`assets/models/`, from the release
   `model-v3.5`: `gh release download model-v3.5 --dir assets/models`). A
   different one can still be sideloaded into `Documents/models/` with
   `xcrun devicectl device copy to --domain-type appDataContainer ...`;
   it then comes first.
7. Check, in this order:
   - the Mushaf renders, word taps work, passage tints;
   - the reciter plays, also with the screen locked (media controls);
   - reciting: the mic prompt, the model loads (`status` / `load` in the
     log), words follow, mistakes marked, the haptic;
   - the daily reminder;
   - CPU and memory while reciting (Instruments), as measured on the
     POCO F3 (~0.55 core, RTF 0.11).

## Still open

- The microphone text in the other five languages (`InfoPlist.strings`).
- App Store listing URL (`kAppStoreUrl`), privacy details ("nutrition
  label"), a privacy policy that names the App Store as well as Google
  Play.
- Whether `record` and `just_audio` agree on the audio session (reciting
  right after listening) — check on the device.
