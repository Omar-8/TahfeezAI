import 'package:flutter/foundation.dart';

/// How far the acoustic model's first download has come (0–1); `null` when
/// nothing is downloading. Only the web downloads it (once, then it is
/// kept: web_channels.dart); the phones have it in the app.
final ValueNotifier<double?> acousticModelDownload = ValueNotifier(null);

/// Whether the web's model has finished loading (or failed to): the
/// reader's first-run guide waits for it — its steps recite, and the
/// download competed with them (owner, 2026-11-16). The phones have it in
/// the app: always settled.
final ValueNotifier<bool> acousticModelSettled = ValueNotifier(!kIsWeb);
