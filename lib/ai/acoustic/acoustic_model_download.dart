import 'package:flutter/foundation.dart';

/// How far the acoustic model's first download has come (0–1); `null` when
/// nothing is downloading. Only the web downloads it (once, then it is
/// kept: web_channels.dart); the phones have it in the app.
final ValueNotifier<double?> acousticModelDownload = ValueNotifier(null);
